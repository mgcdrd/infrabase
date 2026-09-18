acme_sh
=======

Installs [acme.sh](https://github.com/acmesh-official/acme.sh) and manages ACME certificates
(Let's Encrypt, ZeroSSL, etc.) via DNS or HTTP challenges.

Supported challenge types:

| Challenge | Description |
|-----------|-------------|
| `dns_cf`  | Cloudflare DNS API (wildcard-capable) |
| `dns_pdns` | PowerDNS API (wildcard-capable) |
| `standalone` | acme.sh built-in HTTP server (port 80 must be free) |
| `webroot` | Drop challenge files into an existing web root |
| `nginx`   | acme.sh configures nginx directly |
| `apache`  | acme.sh configures Apache directly |

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

- `become: true` — installation and cert storage require root.
- `gather_facts: true` — needed for the package manager.
- Port 80 must be available during issuance for `standalone` challenge.
- Cloudflare API token (or Global API key) with `DNS:Edit` permission for `dns_cf`.
- PowerDNS API enabled on the authoritative server (`webserver`/`api-key` in
  `pdns.conf`) for `dns_pdns`.


Role Variables
--------------

### Installation

```yaml
acme_sh_cert_base_dir: /etc/ssl/acme   # where issued certs are deployed
```

acme.sh itself always installs to `/root/.acme.sh` (set by the upstream installer).

### Account

```yaml
acme_sh_email:   ""             # ACME account email — required
acme_sh_ca:      letsencrypt    # letsencrypt | zerossl | buypass | sslcom
acme_sh_staging: false          # true = use staging CA (for testing)
```

### CA

```yaml
acme_sh_ca: letsencrypt    # letsencrypt | zerossl | buypass | sslcom | google
                           # Full ACME directory URLs are also valid:
                           #   https://acme.sectigo.com/v2/DV
                           #   https://acme.sectigo.com/v2/OV
                           #   https://dv.acme-v02.api.pki.goog/directory
```

### EAB (External Account Binding)

Required by commercial CAs such as Sectigo and DigiCert. Obtain the KID and
HMAC key from the CA's portal after creating an ACME account there.

For Google Public CA, use
[`mgcdrd.infrasvc.google_publicca_eab`](../../../../infrasvc/roles/google_publicca_eab)
to mint a key and store it in Vault instead of a manual portal step. Google
EAB keys are single-use (one key registers exactly one ACME account and is
then invalid) and expire after 7 days unused — mint one only when actually
registering or recovering an account, not routinely.

EAB binds at **account registration** — it applies to all certs issued under
this account. You do not need to re-supply EAB keys on subsequent runs once
the account is registered. If `acme_sh_ca` is Google Public CA and no local
account is registered yet, this role fails fast during preflight when EAB
credentials aren't supplied, rather than letting `--issue` fail later with
an opaque ACME error.

```yaml
acme_sh_eab_enabled:  true
acme_sh_eab_kid:      "{{ vault_acme_eab_kid }}"
acme_sh_eab_hmac_key: "{{ vault_acme_eab_hmac_key }}"
```

### Cloudflare DNS credentials (dns_cf challenge)

Use an API Token scoped to `DNS:Edit` (recommended):

```yaml
acme_sh_cf_token: ""    # Cloudflare API Token
```

Or a Global API Key (legacy):

```yaml
acme_sh_cf_key:   ""   # Cloudflare Global API Key
acme_sh_cf_email: ""   # Cloudflare account email
```

### PowerDNS API credentials (dns_pdns challenge)

```yaml
acme_sh_pdns_url:       ""            # PowerDNS API base URL, e.g. http://dns.lab.acme.com:8081
acme_sh_pdns_server_id: "localhost"   # PowerDNS server-id
acme_sh_pdns_token:     ""            # PowerDNS API key
acme_sh_pdns_ttl:       ""            # optional, acme.sh defaults to 60s
```

### Certificates

```yaml
acme_sh_certs:
  - domains:
      - "example.com"        # primary domain (CN)
      - "*.example.com"      # additional SANs (optional, dns_cf/dns_pdns required for wildcards)
    challenge: dns_cf        # dns_cf | dns_pdns | standalone | webroot | nginx | apache
    webroot_path: ""         # required for webroot challenge only
    reload_cmd: ""           # shell command run after cert install/renew
                             # e.g. "systemctl reload nginx"
    keylength: "2048"        # per-cert override of acme_sh_keylength
    complete_chain: false    # see "Complete chain" below
    root_cn: ""               # per-cert override of acme_sh_root_cn
    root_fingerprint: ""      # per-cert override of acme_sh_root_fingerprint
    root_urls: []             # per-cert override of acme_sh_root_urls
    state: present           # present (default) | absent
```

### Key type

`acme_sh_keylength` (default `"2048"`) is passed to `acme.sh --issue
--keylength`. RSA keeps the cert on the Let's Encrypt RSA chain, which
`complete-le-chain.sh` can root with ISRG Root X1. Set `""` for acme.sh's
default (ec-256) or `ec-384` etc. for ECC — note ECC certs live in a
separate acme.sh config dir (`<domain>_ecc`).

Issued certs are deployed to `{{ acme_sh_cert_base_dir }}/{{ primary_domain }}/`:

| File | Contents |
|------|----------|
| `cert.pem`      | Domain certificate |
| `key.pem`       | Private key |
| `fullchain.pem` | Cert + intermediates (not deployed with `complete_chain`) |
| `ca.pem`        | Intermediate CA chain, or the complete rooted chain with `complete_chain` |

For a multi-domain cert, `{{ primary_domain }}` is always the *first* entry
in `domains:` — every other domain/SAN on that cert gets a directory symlink
under `acme_sh_cert_base_dir` pointing back at the primary domain's
directory. This is for consumers that build a cert path from their own
FQDN rather than `acme_sh_certs[].domains[0]` — e.g.
`{{ acme_sh_cert_base_dir }}/{{ inventory_hostname }}/...` on a host whose
inventory name is a SAN, not the cert's primary domain. With
`domains: [proxy.example.com, admin.example.com]`, both
`{{ acme_sh_cert_base_dir }}/proxy.example.com/fullchain.pem` and
`{{ acme_sh_cert_base_dir }}/admin.example.com/fullchain.pem` resolve to the
same files. Removed along with the primary directory when `state: absent`.

### Flat per-FQDN symlinks (`acme_sh_flat_ssl_dir`)

Some consumers select a cert per-connection off a variable instead of a
fixed path — e.g. nginx's `ssl_certificate`/`ssl_certificate_key` set to a
path built from `$ssl_server_name` so one shared config resolves a
different cert per SNI hostname:

```nginx
ssl_certificate     /etc/nginx/ssl/$ssl_server_name.crt;
ssl_certificate_key /etc/nginx/ssl/$ssl_server_name.key;
```

That needs a flat, FQDN-named file — not the
`<acme_sh_cert_base_dir>/<domain>/<generic-name>` layout above. Set
`acme_sh_flat_ssl_dir` (default `""`, disabled) to also symlink
`<dir>/<domain>.crt` and `<dir>/<domain>.key` for **every** domain on
**every** cert — primary included, not just SANs — to that cert's
fullchain.pem (or ca.pem with `complete_chain`) and key.pem. Directory is
created (`0750`, root:root) if it doesn't exist. Removed along with the
rest of that cert's files when `state: absent`.

Using variables in `ssl_certificate`/`ssl_certificate_key` means nginx
reads the files per-connection rather than preloading them at config
parse, and disables OCSP stapling on that listener.

### Complete chain

With `complete_chain: true`, `ca.pem` receives the full chain instead of
just the intermediates, and `/usr/local/sbin/complete-le-chain.sh` (deployed
by this role) appends the fingerprint-pinned root CA and validates the
result. No `fullchain.pem` is deployed. Use this for consumers that must
validate the chain to a self-contained root (e.g. `katello-certs-check`).

`--issue` also passes `--preferred-chain "<root_cn>"`, so acme.sh requests
the chain whose top-level issuer matches `root_cn` rather than whatever the
CA offers by default. This matters for CAs that serve multiple valid chains
for the same leaf — e.g. Google Public CA defaults to a chain cross-signed
by GlobalSign Root CA (for legacy client compatibility) instead of the
shorter chain terminating at the self-signed GTS Root R1 that
`complete-le-chain.sh`'s fingerprint pin expects.

The root pinned is Let's Encrypt's ISRG Root X1 by default
(`acme_sh_root_cn`/`acme_sh_root_fingerprint`/`acme_sh_root_urls`),
overridable globally or per-cert (`root_cn`/`root_fingerprint`/`root_urls`
on the `acme_sh_certs` entry) for other CAs. Renewal hooks should re-run
`complete-le-chain.sh` with the matching `-c`/`-p`/`-r` flags as their first
step since acme.sh re-copies the un-rooted chain on every renewal:

```
complete-le-chain.sh -f <dir>/ca.pem -l <dir>/cert.pem \
  -c "<root_cn>" -p "<root_fingerprint>" -r "<root_urls, comma-separated>"
```

acme.sh installs its own cron job for auto-renewal during the initial install.
The `reload_cmd` is registered with `--install-cert` after a new issue, or on
any run where the cert exists but was never registered (e.g. issued manually)
— so renewals always propagate files and fire the hook.


### Issuer + Vault fan-out (`acme_sh_vault_kv_enabled`)

By default every host this role runs on issues/renews its own copy of every
cert independently. Fine for one host — but with N hosts hitting the same
`acme_sh_certs` domain set (e.g. a reverse-proxy cluster), each renewal
cycle burns against Let's Encrypt's 5-duplicate-certs/week limit N times as
fast, and repeated test/troubleshooting runs make it worse.

Set `acme_sh_vault_kv_enabled: true` to centralize issuance on one host
(`acme_sh_issuer_host`) and fan the result out to every other host via
HashiCorp Vault, so serving stays fully decoupled from the issuer's
uptime — this works for any challenge type, but is most useful with a DNS
challenge (`dns_cf`/`dns_pdns`), since issuance then has no dependency on
which host holds a shared VIP or is reachable on 80/443.

```yaml
acme_sh_flat_ssl_dir: /etc/nginx/ssl   # required — see below
acme_sh_issuer_host: proxy1.example.com   # literal hostname — never a
                                           # group lookup like
                                           # groups.webproxy | first,
                                           # since inventory reordering
                                           # must never silently move
                                           # who issues
acme_sh_vault_kv_enabled: true
acme_sh_vault_kv_mount: "{{ vault_kv_infra_mount }}"
acme_sh_vault_kv_path_prefix: "{{ vault_kv_env }}/webproxy/certs"
acme_sh_vault_deploy_reload_cmd: "systemctl reload nginx"
# acme_sh_vault_addr defaults to vault_addr (inventory-common) — override
# only if this cluster talks to a different Vault.
```

**Required:** `acme_sh_flat_ssl_dir` must be set whenever
`acme_sh_vault_kv_enabled` is true — `vault_deploy.yml` deploys every
non-issuer host's cert/key there, unconditionally (unlike the normal
local flow, where it's optional). `vault_deploy.yml` asserts this and the
Vault vars itself, since it's invoked independently of `main.yml`'s own
`preflight.yml` import (see "What happens on each host" below).

What happens on each host:

- **Issuer** (`inventory_hostname == acme_sh_issuer_host`): runs
  `install.yml`/`account.yml`/`manage_cert.yml` exactly as today, plus (when
  a cert was actually issued/renewed) writes `cert`/`key`/`fullchain`-or-`ca`/
  `domains`/`complete_chain`/`issued_at` to
  `<acme_sh_vault_kv_path_prefix>/<primary-domain>` in Vault.
- **Every other host**: skips issuance entirely and instead pulls each
  cert's fields from that same Vault path (`tasks_from: vault_deploy.yml`,
  called independently of this role's own `main.yml` — see the consuming
  deployment, e.g. `mgcdrd.infrasvc.nginx`), writing them out under
  `acme_sh_flat_ssl_dir` the same way a local `acme_sh_flat_ssl_dir`
  deployment would. `acme_sh_vault_deploy_reload_cmd` fires only when a
  file's content actually changed — that idempotency is what makes a
  periodic re-run self-healing rather than reloading every time.

Two Vault-push paths exist and are both kept deliberately: the
Ansible-triggered write above fails the *play* loudly if Vault write is
broken; a wrapper script (`/usr/local/sbin/acme-sh-vault-push.sh`, deployed
on the issuer only, gated on `acme_sh_vault_kv_enabled`) is also registered
as part of each cert's `reload_cmd`, so acme.sh's own cron-triggered
renewals — invisible to Ansible entirely — still update Vault. The
wrapper does its own AppRole login at runtime (role_id/secret_id read fresh
from `acme_sh_vault_role_id_file`/`acme_sh_vault_secret_id_file`, token
never cached to disk — same pattern as `mgcdrd.infrasvc.ups_shed`'s
vault-get script), for example:

```yaml
reload_cmd: "/usr/local/sbin/acme-sh-vault-push.sh app1.example.com && systemctl reload nginx"
```

**Prerequisite, not automated by this role:** the AppRole `role_id`/
`secret_id` files the wrapper script reads
(`/etc/vault/acme-sh-role-id`/`-secret-id` by default) must be
pre-positioned on the issuer host by the identity build — same accepted
convention as `ups_shed`'s AppRole creds. A periodic re-run of the
consuming deployment (e.g. via an AWX schedule) is what turns the
Vault-pull side into actual self-healing convergence; that scheduling is
outside this role's scope.

The issuer host is excluded from `vault_deploy.yml` — it already gets an
authoritative local `acme_sh_flat_ssl_dir` deployment for free from
`manage_cert.yml`'s existing symlink task, so also running `vault_deploy.yml`
there would overwrite that symlink with a plain file (or vice versa) every
run for no reason.


Example Playbook
----------------

**Multiple certificates (e.g. a reverse proxy host):**

```yaml
acme_sh_email: "admin@lab.acme.com"
acme_sh_cf_token: "{{ vault_cf_token }}"
acme_sh_certs:
  - domains:
      - "proxy.lab.acme.com"
    challenge: dns_cf
    reload_cmd: "systemctl reload nginx"
    state: present
  - domains:
      - "lab.acme.com"
      - "*.lab.acme.com"
    challenge: dns_cf
    reload_cmd: "systemctl reload nginx"
    state: present
  - domains:
      - "internal.acme.com"
    challenge: standalone
    state: present
```

**Sectigo with EAB:**

```yaml
acme_sh_email: "admin@acme.com"
acme_sh_ca: "https://acme.sectigo.com/v2/DV"
acme_sh_eab_enabled:  true
acme_sh_eab_kid:      "{{ vault_sectigo_eab_kid }}"
acme_sh_eab_hmac_key: "{{ vault_sectigo_eab_hmac }}"
acme_sh_certs:
  - domains:
      - "example.com"
    challenge: dns_cf
    state: present
```

**Google Public CA with EAB, rooted for katello-certs-check:**

```yaml
acme_sh_email: "admin@acme.com"
acme_sh_ca: google
acme_sh_eab_enabled:  true
acme_sh_eab_kid:      "{{ vault_google_eab_kid }}"
acme_sh_eab_hmac_key: "{{ vault_google_eab_hmac_key }}"
acme_sh_certs:
  - domains:
      - "foreman.acme.com"
    challenge: dns_cf
    complete_chain: true
    root_cn: "GTS Root R1"
    root_fingerprint: "D9:47:43:2A:BD:E7:B7:FA:90:FC:2E:6B:59:10:1B:12:80:E0:E1:C7:E4:E4:0F:A3:C6:88:7F:FF:57:A7:F4:CF"
    root_urls:
      - "https://pki.goog/repo/certs/gtsr1.pem"
    state: present
```

**DNS challenge with Cloudflare, restart phpIPAM on renewal:**

```yaml
- name: Issue TLS certificate
  hosts: dns_servers
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.acme_sh
  vars:
    acme_sh_email: "admin@lab.acme.com"
    acme_sh_cf_token: "{{ vault_cf_token }}"
    acme_sh_certs:
      - domains:
          - "dns.lab.acme.com"
        challenge: dns_cf
        reload_cmd: "docker compose -f /srv/phpipam/docker-compose.yaml restart phpipam-web"
        state: present
```

**Wildcard cert:**

```yaml
acme_sh_certs:
  - domains:
      - "lab.acme.com"
      - "*.lab.acme.com"
    challenge: dns_cf
    state: present
```

**Standalone (no web server running):**

```yaml
acme_sh_certs:
  - domains:
      - "myhost.acme.com"
    challenge: standalone
    reload_cmd: "systemctl reload nginx"
    state: present
```


Notes
-----

- Wildcard certificates (`*.domain`) require a DNS challenge — HTTP challenges
  cannot validate wildcards.
- `acme_sh_staging: true` issues from the CA's staging endpoint. Certs will be
  untrusted by browsers but subject to no rate limits — use for testing.
- The `--install-cert` step (deploy to `acme_sh_cert_base_dir`) only runs when a
  new or renewed cert is issued. The `reload_cmd` is registered regardless so
  acme.sh will call it on future automatic renewals.
- Cloudflare and PowerDNS credentials are passed via environment variables to
  the acme.sh command, not on the command line, so they do not appear in
  process listings or Ansible output.
