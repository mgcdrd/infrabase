acme_sh
=======

Installs [acme.sh](https://github.com/acmesh-official/acme.sh) and manages ACME certificates
(Let's Encrypt, ZeroSSL, etc.) via DNS or HTTP challenges.

Supported challenge types:

| Challenge | Description |
|-----------|-------------|
| `dns_cf`  | Cloudflare DNS API (wildcard-capable) |
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


Role Variables
--------------

### Installation

```yaml
acme_sh_install_dir:  /root/.acme.sh   # where acme.sh installs itself
acme_sh_cert_base_dir: /etc/ssl/acme   # where issued certs are deployed
```

### Account

```yaml
acme_sh_email:   ""             # ACME account email — required
acme_sh_ca:      letsencrypt    # letsencrypt | zerossl | buypass | sslcom
acme_sh_staging: false          # true = use staging CA (for testing)
```

### CA

```yaml
acme_sh_ca: letsencrypt    # letsencrypt | zerossl | buypass | sslcom
                           # Full ACME directory URLs are also valid:
                           #   https://acme.sectigo.com/v2/DV
                           #   https://acme.sectigo.com/v2/OV
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

### Certificates

```yaml
acme_sh_certs:
  - domains:
      - "example.com"        # primary domain (CN)
      - "*.example.com"      # additional SANs (optional, dns_cf required for wildcards)
    challenge: dns_cf        # dns_cf | standalone | webroot | nginx | apache
    webroot_path: ""         # required for webroot challenge only
    reload_cmd: ""           # shell command run after cert install/renew
                             # e.g. "systemctl reload nginx"
    state: present           # present (default) | absent
```

Issued certs are deployed to `{{ acme_sh_cert_base_dir }}/{{ primary_domain }}/`:

| File | Contents |
|------|----------|
| `cert.pem`      | Domain certificate |
| `key.pem`       | Private key |
| `fullchain.pem` | Cert + intermediates (use this in most configs) |
| `ca.pem`        | Intermediate CA chain |

acme.sh installs its own cron job for auto-renewal during the initial install.
The `reload_cmd` is re-registered with acme.sh on each run and will be called
automatically on every successful renewal.


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
- Cloudflare credentials appear in the shell command. `no_log: true` is set on
  that task to suppress them from Ansible output.

### DFARS / SELinux noexec environments

On hardened systems (DFARS, STIG) `/tmp`, `/var/tmp`, and home directories are
mounted `noexec`. The role works around this without touching mount options:

- The installer is downloaded as a **tarball** (`master.tar.gz`) and extracted
  with `unarchive` — no shell exec of the downloaded file.
- Installation runs as `bash acme.sh --install` (passing the script as an
  argument to the already-trusted `bash` binary) rather than `./acme.sh`.
- The temporary extraction directory (`acme_sh_tmp_dir`, default
  `/root/.acme_sh_tmp`) is a sibling of the install dir, not inside it, so
  pre-creating the install directory does not cause the installer to exit early.


License
-------

GPL-3.0-or-later
