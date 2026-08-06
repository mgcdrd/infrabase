#!/usr/bin/env bash
#
# complete-le-chain.sh
#
# Ensures the CA chain in fullchain.cer is rooted by appending the CA's
# self-signed root if it is not already present. Root defaults to Let's
# Encrypt's "ISRG Root X1"; pass -c/-p/-r to pin a different CA (e.g.
# Google Public CA's "GTS Root R1").
#
# Source order:
#   1. System CA trust bundle (RHEL/CentOS/Fedora and Debian/Ubuntu paths)
#   2. Known root download URLs (curl, then wget)
#
# The acquired root is verified against the pinned SHA-256 fingerprint
# before anything is appended.
#
# Finally validates:  openssl verify -CAfile fullchain.cer <leaf>.cer
#
# Usage:
#   ./complete-le-chain.sh [-d CERT_DIR] [-f FULLCHAIN] [-l LEAF_CERT]
#                           [-c ROOT_CN] [-p ROOT_FINGERPRINT] [-r ROOT_URLS] [-n]
#
#   -d CERT_DIR   Directory containing the certs
#                 (default: ~/.acme.sh/$(hostname -f))
#   -f FULLCHAIN  Path to fullchain file (default: CERT_DIR/fullchain.cer)
#   -l LEAF_CERT  Path to leaf cert     (default: CERT_DIR/$(hostname -f).cer)
#   -c ROOT_CN    Label for the root CA, used only in log messages
#                 (default: "ISRG Root X1")
#   -p ROOT_FPR   SHA-256 fingerprint (colon-separated, uppercase) of the
#                 root CA to pin (default: ISRG Root X1's fingerprint)
#   -r ROOT_URLS  Comma-separated list of URLs to download the root from if
#                 it isn't found in the system trust store (default: the
#                 Let's Encrypt ISRG Root X1 URLs)
#   -n            No network. Only use the system trust store, never download.
#
# Exit codes: 0 = chain complete and verified, non-zero = failure.

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults (Let's Encrypt's ISRG Root X1 — override with -c/-p/-r for other CAs)
# ---------------------------------------------------------------------------
ROOT_CN="ISRG Root X1"

# Published SHA-256 fingerprint of the self-signed ISRG Root X1
# (https://letsencrypt.org/certificates/)
ROOT_FPR="96:BC:EC:06:26:49:76:F3:74:60:77:9A:CF:28:C5:A7:CF:E8:A3:C0:AA:E1:1A:8F:FC:EE:05:C0:BD:DF:08:C6"

ROOT_URLS=(
  "https://letsencrypt.org/certs/isrgrootx1.pem"
  "https://letsencrypt.org/certs/isrgrootx1.pem.txt"
)

TRUST_BUNDLES=(
  "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"  # RHEL / CentOS / Fedora
  "/etc/pki/tls/certs/ca-bundle.crt"                   # RHEL symlink
  "/etc/ssl/certs/ca-certificates.crt"                 # Debian / Ubuntu
  "/etc/ssl/cert.pem"                                  # misc
)

# ---------------------------------------------------------------------------
# Defaults & argument parsing
# ---------------------------------------------------------------------------
FQDN="$(hostname -f 2>/dev/null || hostname)"
CERT_DIR="${HOME}/.acme.sh/${FQDN}"
FULLCHAIN=""
LEAF=""
NO_NET=0

while getopts ":c:d:f:l:np:r:h" opt; do
  case "$opt" in
    c) ROOT_CN="$OPTARG" ;;
    d) CERT_DIR="$OPTARG" ;;
    f) FULLCHAIN="$OPTARG" ;;
    l) LEAF="$OPTARG" ;;
    n) NO_NET=1 ;;
    p) ROOT_FPR="$OPTARG" ;;
    r) IFS=',' read -r -a ROOT_URLS <<< "$OPTARG" ;;
    h) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: -$OPTARG" >&2; exit 2 ;;
  esac
done

FULLCHAIN="${FULLCHAIN:-${CERT_DIR}/fullchain.cer}"
LEAF="${LEAF:-${CERT_DIR}/${FQDN}.cer}"

log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
die()  { log "ERROR: $*" >&2; exit 1; }

[ -r "$FULLCHAIN" ] || die "Cannot read fullchain: $FULLCHAIN"
[ -r "$LEAF" ]      || die "Cannot read leaf cert: $LEAF"
command -v openssl >/dev/null || die "openssl not found in PATH"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Split a PEM bundle into individual certs in a target directory
split_bundle() {
  local bundle="$1" outdir="$2"
  awk -v dir="$outdir" '
    /-----BEGIN CERTIFICATE-----/ { n++; f = dir "/cert-" n ".pem" }
    n { print > f }
    /-----END CERTIFICATE-----/   { close(f) }
  ' "$bundle"
}

# SHA-256 fingerprint of a single PEM cert, uppercase colon-separated
cert_fpr() {
  openssl x509 -in "$1" -noout -fingerprint -sha256 2>/dev/null \
    | sed 's/^.*=//'
}

# Is this cert the self-signed ISRG Root X1? (pinned fingerprint)
is_isrg_root() {
  [ "$(cert_fpr "$1")" = "$ROOT_FPR" ]
}

# ---------------------------------------------------------------------------
# 1. Is the root already in the fullchain?
# ---------------------------------------------------------------------------
log "Checking whether '${ROOT_CN}' is already present in ${FULLCHAIN} ..."
mkdir -p "$WORKDIR/chain"
split_bundle "$FULLCHAIN" "$WORKDIR/chain"

ROOT_PRESENT=0
for c in "$WORKDIR/chain"/cert-*.pem; do
  [ -e "$c" ] || break
  if is_isrg_root "$c"; then
    ROOT_PRESENT=1
    break
  fi
done

ROOT_PEM=""

if [ "$ROOT_PRESENT" -eq 1 ]; then
  log "Root already present in fullchain. Skipping append."
else
  # -------------------------------------------------------------------------
  # 2. Try to extract the root from the system trust store
  # -------------------------------------------------------------------------
  log "Root not in fullchain. Searching system trust bundles ..."
  for bundle in "${TRUST_BUNDLES[@]}"; do
    [ -r "$bundle" ] || continue
    mkdir -p "$WORKDIR/sys"
    rm -f "$WORKDIR/sys"/cert-*.pem
    split_bundle "$bundle" "$WORKDIR/sys"
    for c in "$WORKDIR/sys"/cert-*.pem; do
      [ -e "$c" ] || break
      if is_isrg_root "$c"; then
        ROOT_PEM="$c"
        log "Found '${ROOT_CN}' in ${bundle}"
        break 2
      fi
    done
  done

  # -------------------------------------------------------------------------
  # 3. Fall back to downloading from Let's Encrypt
  # -------------------------------------------------------------------------
  if [ -z "$ROOT_PEM" ]; then
    if [ "$NO_NET" -eq 1 ]; then
      die "Root not found in trust store and -n (no network) was given."
    fi
    log "Not found locally. Downloading from Let's Encrypt ..."
    for url in "${ROOT_URLS[@]}"; do
      dst="$WORKDIR/downloaded-root.pem"
      if command -v curl >/dev/null; then
        curl -fsSL --max-time 30 -o "$dst" "$url" || continue
      elif command -v wget >/dev/null; then
        wget -q -T 30 -O "$dst" "$url" || continue
      else
        die "Neither curl nor wget available for download."
      fi
      if is_isrg_root "$dst"; then
        ROOT_PEM="$dst"
        log "Downloaded and fingerprint-verified root from ${url}"
        break
      else
        log "WARNING: ${url} did not yield a fingerprint-matching root; trying next."
      fi
    done
  fi

  [ -n "$ROOT_PEM" ] || die "Could not acquire '${ROOT_CN}' from any source."

  # -------------------------------------------------------------------------
  # 4. Back up and append
  # -------------------------------------------------------------------------
  BACKUP="${FULLCHAIN}.$(date +%Y%m%d%H%M%S).bak"
  cp -p "$FULLCHAIN" "$BACKUP"
  log "Backed up fullchain to ${BACKUP}"

  {
    # Ensure the file ends with a newline before appending
    tail -c1 "$FULLCHAIN" | od -An -c | grep -q '\\n' || echo ""
    openssl x509 -in "$ROOT_PEM"   # re-emit as clean PEM (strips text headers)
  } >> "$FULLCHAIN"
  log "Appended '${ROOT_CN}' to ${FULLCHAIN}"
fi

# ---------------------------------------------------------------------------
# 5. Validate
# ---------------------------------------------------------------------------
log "Validating: openssl verify -CAfile ${FULLCHAIN} ${LEAF}"
if openssl verify -CAfile "$FULLCHAIN" "$LEAF"; then
  log "SUCCESS: chain verifies."
else
  die "Verification FAILED. Inspect ${FULLCHAIN} manually."
fi

# Optional stricter check: root as the only trust anchor, rest untrusted
ROOT_ONLY="$WORKDIR/root-only.pem"
for c in "$WORKDIR/chain"/cert-*.pem; do
  [ -e "$c" ] || break
  is_isrg_root "$c" && cp "$c" "$ROOT_ONLY" && break
done
[ -e "$ROOT_ONLY" ] || { [ -n "${ROOT_PEM:-}" ] && openssl x509 -in "$ROOT_PEM" > "$ROOT_ONLY"; }

if [ -s "$ROOT_ONLY" ]; then
  log "Strict check: openssl verify -CAfile <root> -untrusted ${FULLCHAIN} ${LEAF}"
  openssl verify -CAfile "$ROOT_ONLY" -untrusted "$FULLCHAIN" "$LEAF" \
    && log "SUCCESS: strict verification passed." \
    || die "Strict verification failed."
fi

exit 0
