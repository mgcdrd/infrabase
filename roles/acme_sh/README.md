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

EAB binds at **account registration** — it applies to all certs issued under
this account. You do not need to re-supply EAB keys on subsequent runs once
the account is registered.

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

### Complete chain

With `complete_chain: true`, `ca.pem` receives the full chain instead of
just the intermediates, and `/usr/local/sbin/complete-le-chain.sh` (deployed
by this role) appends the fingerprint-pinned root CA and validates the
result. No `fullchain.pem` is deployed. Use this for consumers that must
validate the chain to a self-contained root (e.g. `katello-certs-check`).

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
