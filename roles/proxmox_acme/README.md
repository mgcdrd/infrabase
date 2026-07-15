proxmox_acme
=============

Manages ACME (Let's Encrypt-style) certificates for ProxMox VE nodes' own
web UI (`pveproxy`) via the PVE REST API: ACME accounts, DNS-01 challenge
plugins, and per-node domain assignment + certificate ordering/renewal.
Distinct from the existing `mgcdrd.infrabase.acme_sh` role, which issues
certs for generic Linux hosts via acme.sh — this role uses PVE's own
built-in ACME client instead.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requires root@pam password authentication
----------------------------------------------

**Every write operation in this role (account/plugin/certificate) requires
`root@pam` password authentication** — this is a PVE API restriction stated
directly in the modules' own documentation, not a limitation this role
introduces. API tokens are not accepted for these operations, even tokens
issued to `root@pam`. Each of those three task files fails its precondition
check if `proxmox_acme_api_user` isn't `root@pam` or `proxmox_acme_api_password`
isn't set. `info` has no such restriction.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.0.0` — all ACME modules
  were added in that release).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

```yaml
proxmox_acme_api_user:     "root@pam"
proxmox_acme_api_password: "{{ vault_proxmox_api_password }}"
```

There is no token-auth alternative for `account`/`plugin`/`certificate` —
see above. Unset `vault_*` resolves to `omit`, which will simply fail the
precondition check with a clear message rather than an opaque API error.


Role Variables
---------------

### Connection (required)

```yaml
proxmox_acme_api_host: "pve2.example.com"
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_acme_do_info` | `false` | `info` | List ACME accounts and DNS plugins |
| `proxmox_acme_do_account` | `false` | `account` | Create/update/delete ACME accounts |
| `proxmox_acme_do_plugin` | `false` | `plugin` | Create/update/delete DNS challenge plugins |
| `proxmox_acme_do_certificate` | `false` | `certificate` | Set node domains + order/renew/remove certs |

### info

No variables required. Sets `proxmox_acme_accounts_facts` and
`proxmox_acme_plugins_facts`. Single-item read modules
(`proxmox_acme_account_info`, `proxmox_acme_plugin_info`,
`proxmox_acme_certificates_info`) exist upstream but aren't wired into this
section — their filter-parameter names weren't confirmed during this role's
research. Call them directly (check `ansible-doc
community.proxmox.proxmox_acme_account_info` first) if you need per-item
detail beyond the plural list views.

### account

```yaml
proxmox_acme_accounts:
  - name: default
    state: present
    contact: admin@example.com
    directory: "https://acme-v02.api.letsencrypt.org/directory"
    tos: "https://letsencrypt.org/documents/LE-SA-v1.3-September-21-2022.pdf"
```

Use `https://acme-staging-v02.api.letsencrypt.org/directory` for Let's
Encrypt's staging environment while testing (much higher rate limits, but
issues untrusted test certs). **Once an account exists, only `contact` can
be updated afterward** — a PVE API limitation, not something this role
works around; delete and recreate to change `directory`/`tos`.

### plugin

```yaml
proxmox_acme_plugins:
  - name: cloudflare
    state: present
    plugin: cf                    # DNS API implementation id
    data:
      CF_Account_ID: "{{ vault_cf_account_id }}"
      CF_Token: "{{ vault_cf_token }}"
    validation_delay: 30           # seconds, 0-172800
```

`plugin` selects the DNS API implementation (`cf` for Cloudflare, and
others PVE's ACME client supports — see PVE's own plugin list). `data` is a
flat dict of provider-specific key/value settings; keys are
provider-defined (e.g. `CF_Token` for Cloudflare's acme.sh-style plugin
convention).

### certificate

```yaml
proxmox_acme_certificates:
  - node_name: pve1
    state: present
    account: default
    force: false
    domains:
      - domain: pve1.lab.example.com
        plugin: cloudflare          # omit for standalone HTTP-01 instead of DNS-01
```

A single task handles both assigning the domain list to the node **and**
ordering/renewing the resulting certificate — there's no separate step.
Set `force: true` to renew even when not yet due. `state: absent` removes
the ACME domain config from the node (does not necessarily revoke an
already-issued cert with the CA).


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_acme` | Entire role |
| `info` | List accounts/plugins |
| `account` | Manage ACME accounts |
| `plugin` | Manage DNS challenge plugins |
| `certificate` | Manage node domains + certs |


Example Playbook — Cloudflare DNS-01 cert for a node
-----------------------------------------------------------

```yaml
- name: Issue a Let's Encrypt cert for the PVE web UI via Cloudflare DNS-01
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_acme
      vars:
        proxmox_acme_api_host:     "pve1.example.com"
        proxmox_acme_api_user:     "root@pam"
        proxmox_acme_api_password: "{{ vault_proxmox_api_password }}"
        proxmox_acme_do_account: true
        proxmox_acme_do_plugin: true
        proxmox_acme_do_certificate: true
        proxmox_acme_accounts:
          - name: default
            contact: admin@lab.example.com
            directory: "https://acme-v02.api.letsencrypt.org/directory"
        proxmox_acme_plugins:
          - name: cloudflare
            plugin: cf
            data:
              CF_Account_ID: "{{ vault_cf_account_id }}"
              CF_Token: "{{ vault_cf_token }}"
        proxmox_acme_certificates:
          - node_name: pve1
            account: default
            domains:
              - domain: pve1.lab.example.com
                plugin: cloudflare
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No `--diff` support**: all ACME modules declare `diff_mode: support:
  none` (though `check_mode` is fully supported).
- **No handlers**: every module call is idempotent against PVE's own state.
