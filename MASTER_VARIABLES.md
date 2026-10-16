Master Variables List for infrabase
===================================


acme_sh Role Variables
--------------

Installs [acme.sh](https://github.com/acmesh-official/acme.sh) and manages ACME certificates
(Let's Encrypt, ZeroSSL, etc.) via DNS or HTTP challenges.

[`:mgcdrd.infrabase.acme_sh`](roles/acme_sh/README.md)

**General role variables**

| Name                     | Default                      | Required | Purpose |
|--------------------------|------------------------------|----------|---------|
| acme_sh_register_email   | `""`                         | Yes      | Used to register the acme.sh instance |
| acme_sh_ca               | `letsencrypt`                | No       | CA to use: `letsencrypt`, `zerossl`, `buypass`, `sslcom`, `google`, or a full ACME directory URL |
| acme_sh_staging          | `false`                      | No       | Use the CA's staging endpoint (no rate limits, untrusted certs) |
| acme_sh_keylength        | `"2048"`                     | No       | Key length for `acme.sh --issue`; `""` falls back to acme.sh's default (ec-256) |
| acme_sh_certs            | `[]`                         | Yes      | Certificates to manage; each entry takes `domains`, `challenge`, `webroot_path`, `reload_cmd`, `keylength`, `complete_chain`, `root_*`, `state` (see below) |


**acme_sh_ca options**

| Challenge  | Description |
|------------|-------------|
| dns_cf     | Cloudflare DNS API (wildcard-capable) |
| dns_pdns   | PowerDNS API (wildcard-capable) |
| standalone | acme.sh built-in HTTP server (port 80 must be free) |
| webroot    | Drop challenge files into an existing web root |
| nginx      | acme.sh configures nginx directly |
| apache     | acme.sh configures Apache directly |


**acme_sh_certs options***

| Name              | Default               | Required  | Purpose |
|-------------------|-----------------------|-----------|---------|
| domains           | `[]`                  | No        | list of domains on the cert; first becomes primary |
| challenge         | `""`                  | Yes       | dns_cf \| dns_pdns \| standalone \| webroot \| nginx \| apache | 
| webroot_path      | `""`                  | No        | required for webroot challenge only |
| reload_cmd        | `""`                  | No        | shell command run after cert install/renew |
| keylength         | `acme_sh_keylength`   | No        | per-cert override of acme_sh_keylength |
| complete_chain    | `false`               | No        | see "Complete chain" below |
| root_cn           | `""`                  | No        | per-cert override of acme_sh_root_cn |
| root_fingerprint  | `""`                  | No        | per-cert override of acme_sh_root_fingerprint |
| root_urls         | `""`                  | No        | per-cert override of acme_sh_root_urls |
| state             | `present`             | Yes       | present (default) \| absent | 


**Cert location variables**

| Name                     | Default         | Required                                      | Purpose |
|--------------------------|-----------------|-----------------------------------------------|---------|
| acme_sh_cert_base_dir    | `/etc/ssl/acme` | No                                            | Directory certs are deployed to; one subdirectory per primary domain |
| acme_sh_cert_deploy_dir  | `/etc/ssl/acme` | No                                            | Sets where issued certs/key are placed (one subdirectory per primary domain) |
| acme_sh_flat_ssl_dir     | `""`            | Only if `acme_sh_vault_kv_enabled` is `true`  | Sets where symlinks to the certs and keys in `<acme_sh_cert_deploy_dir>/<FQDN>` to provide a "flat" directory with all certs and keys (See Notes below for more info)      | 
| acme_sh_flat_ssl_owner   | `root`          | No                                            | Sets the owner of the `acme_sh_flat_ssl_dir` |
| acme_sh_flat_ssl_group   | `root`          | No                                            | Sets the group of the `acme_sh_flat_ssl_dir` |
Notes:
- the `acme_sh_flat_ssl_dir` allows for things like `ssl_certificate /etc/nginx/ssl/$ssl_server_name.crt;  ssl_certificate_key /etc/nginx/ssl/$ssl_server_name.key;` to work. Once set, when a new cert is created and placed in `<acme_sh_cert_deploy_dir>/<FQDN>` ansible runs of this role will have the .crt and .key symlinks created pointing to the correct FQDN directory.  


**EAB specific variables**

| Name                   | Default  | Required                                | Purpose                              |
|------------------------|----------|-----------------------------------------|--------------------------------------|
| acme_sh_eab_enabled    |  `false` | No                                      | Enables use of EABs for specific CAs |
| acme_sh_eab_kid        |  `""`    | Only if `acme_sh_eab_enabled` is `true' | Sets the EAB id                      |
| acme_sh_eab_hmac_key   |  `""`    | Only if `acme_sh_eab_enabled` is `true' | Sets the EAB KMAC                    |

**Vault cert fan-out variables**

| Name                            | Default                        | Required                                     | Purpose                      |
|---------------------------------|--------------------------------|----------------------------------------------|------------------------------|
| acme_sh_vault_kv_enabled        | 'false'                        | No                                           | When enabled, issued/renewed certs are pushed to a vault instance for fanout in cluster |
| acme_sh_vault_addr              | `""`                           | Only if `acme_sh_vault_kv_enabled` is `true' | Sets the VAULT_ADDR variable |
| acme_sh_vault_kv_mount          | `""`                           | Only if `acme_sh_vault_kv_enabled` is `true' | Sets the Secrets engine (or mount) |
| acme_sh_vault_kv_path_prefix    | `""`                           | Only if `acme_sh_vault_kv_enabled` is `true' | Sets the path in vault where certs will be placed, in the form of `<acme_sh_vault_kv_mount>`/`<acme_sh_vault_kv_path_prefix>`/`<primary fqdn>` |
| acme_sh_issuer_host             | `""`                           | Only if `acme_sh_vault_kv_enabled` is `true' | Sets which host in a cluster will be the system that requests new/reissuing certs and pushs to vault |
| acme_sh_vault_role_id_file      | `/etc/vault/acme-sh-role-id`   | No                                           | AppRole role_id file the push wrapper reads at runtime; pre-positioned on the issuer, not created by this role |
| acme_sh_vault_secret_id_file    | `/etc/vault/acme-sh-secret-id` | No                                           | AppRole secret_id file the push wrapper reads at runtime; pre-positioned on the issuer |
| acme_sh_vault_deploy_reload_cmd | `""`                           | No                                           | Command run on non-issuer hosts when a Vault-deployed cert or key file changes (e.g. `systemctl reload nginx`) |

**DNS-01 Verification variables**

| Name                   | Default       | Required                 | Purpose                      |
|------------------------|---------------|--------------------------|------------------------------|
| acme_sh_cf_token       | `""`          | If `challenge: dns_cf`   | Cloudflare API token scoped to DNS:Edit (preferred); use `{{ vault_* }}` |
| acme_sh_cf_key         | `""`          | No                       | Cloudflare Global API Key (legacy alternative to the token, needs `acme_sh_cf_email`) |
| acme_sh_cf_email       | `""`          | No                       | Cloudflare account email, used only with `acme_sh_cf_key` |
| acme_sh_pdns_url       | `""`          | If `challenge: dns_pdns` | PowerDNS API base URL (e.g. `https://dns.example.com:8081`) |
| acme_sh_pdns_server_id | `"localhost"` | No                       | PowerDNS server ID for API calls |
| acme_sh_pdns_token     | `""`          | If `challenge: dns_pdns` | PowerDNS API key; use `{{ vault_* }}` |
| acme_sh_pdns_ttl       | `""`          | No                       | TTL for the challenge TXT records; empty uses acme.sh's default |
Notes:
- the `acme_sh_cf_*` and the `acme_sh_pdns_*` are mutually exclusive per each `acme_sh_certs` element.  Both can be used on different elements of the `acme_sh_certs`, but only 1 per cert, if you will.


**Let's Encrypt CA fullchain fix** - A script that will complete the fullchain file for certs issued by Let's Encrypt CA so they contain the full path to and including, the root CA.

| Name                     | Default           | Required | Purpose                      |
|--------------------------|-------------------|--------- |------------------------------|
| acme_sh_root_cn          | `"ISRG Root X1"`  | No       | Common name of the root used by `complete-le-chain.sh` for `complete_chain: true` certs |
| acme_sh_root_fingerprint | *(see defaults)*  | No       | SHA-256 fingerprint the fetched root must match (default is ISRG Root X1) |
| acme_sh_root_urls        | *(list, 2 items)* | No       | URLs the root CA PEM is fetched from (default is ISRG Root X1) |
Notes:
- these variables are only used when a cert in `acme_sh_certs` has `complete_chain: true` and work with the Let's Encrypt CA.  Most others don't seem to have similar issues.


aide Role Variables
--------------

Installs AIDE (Advanced Intrusion Detection Environment), deploys a
configuration covering OS-critical paths, initialises the database on first
run, and schedules a daily integrity check via cron.

The rule set covers `/boot`, `/usr`, `/root`, `/etc`, logs, audit config, PKI,
and cron. Both RedHat-family and Debian-family package paths are included.
Callers can extend coverage with `aide_extra_paths` or suppress specific paths
with `aide_exclude_paths`.

If `aide.conf` changes on a subsequent run, the database is automatically
rebuilt so the baseline stays consistent with the active configuration.

[`:mgcdrd.infrabase.aide`](roles/aide/README.md)

**General role variables**

| Name               | Default         | Required | Purpose |
|--------------------|-----------------|----------|---------|
| aide_db_dir        | `/var/lib/aide` | No       | Directory for the AIDE database files |
| aide_log_dir       | `/var/log/aide` | No       | Directory for AIDE check reports |
| aide_cron_hour     | `"4"`           | No       | Hour to run the daily check |
| aide_cron_minute   | `"5"`           | No       | Minute to run the daily check |
| aide_extra_paths   | `[]`            | No       | Additional paths to monitor |
| aide_exclude_paths | `[]`            | No       | Paths to exclude from monitoring (prepended with !) |

**aide_extra_paths options**

| Name  | Default   | Required  | Purpose |
|-------|-----------|-----------|---------|
| path  | `""`      | Yes       | path to be included |
| rule  | `""`      | Yes       | rule string for `path` can be custom or defined rule |

**aide_exclude_paths options**

| Name  | Default   | Required  | Purpose |
|-------|-----------|-----------|---------|
| path  | `""`      | Yes       | path to be excluded |


auditd Role Variables
--------------

Installs and configures auditd with CIS-aligned audit rules. Manages
`auditd.conf`, the base ruleset, and the loginuid immutability rule. All
syscall groups, watchpoints, and conf settings are variable-driven so callers
can extend or narrow coverage without forking the role.

On RedHat family hosts, also enables the audit kernel parameter at boot via
`grubby` (idempotent — skipped if the args are already present).

[`:mgcdrd.infrabase.auditd`](roles/auditd/README.md)

**General role variables**

| Variable                          | Default            | Required | Description |
|-----------------------------------|--------------------|----------|-------------|
| auditd_local_events               | `"yes"`            | No       | `local_events` in auditd.conf: record events from the local system |
| auditd_log_format                 | `"ENRICHED"`       | No       | `log_format`: `ENRICHED` or `RAW` |
| auditd_name_format                | `"hostname"`       | No       | `name_format`: how this host is identified in logs |
| auditd_max_log_file_action        | `"keep_logs"`      | No       | Action when a log reaches its maximum size |
| auditd_space_left                 | `"25"`             | No       | MB free before `auditd_space_left_action` fires |
| auditd_space_left_action          | `"email"`          | No       | Action when the `space_left` threshold is hit |
| auditd_action_mail_acct           | `"root"`           | No       | Mail recipient for space alerts |
| auditd_admin_space_left           | `"12"`             | No       | MB free before `auditd_admin_space_left_action` fires |
| auditd_admin_space_left_action    | `"halt"`           | No       | Action when the `admin_space_left` threshold is hit |
| auditd_disk_full_action           | `"single"`         | No       | Action when the audit volume is full |
| auditd_disk_error_action          | `"syslog"`         | No       | Action on an audit disk error |
| auditd_overflow_action            | `"syslog"`         | No       | Action on audit queue overflow |
| auditd_time_syscalls              | *(list, 3 items)*  | No       | Syscalls audited for time changes (CIS 4.1.3.3) |
| auditd_network_syscalls           | *(list, 2 items)*  | No       | Syscalls audited for network config changes (CIS 4.1.3.4) |
| auditd_perm_mod                   | *(list, 10 items)* | No       | Syscalls audited for permission changes, present on all architectures (CIS 4.1.3.5) |
| auditd_perm_mod_x86_only          | *(list, 3 items)*  | No       | Permission-change syscalls that exist only on x86_64 (chmod/chown/lchown) |
| auditd_perm_mod_root              | *(list, 6 items)*  | No       | Permission-change syscalls audited for root-owned actions |
| auditd_file_access_x86_only       | *(list, 2 items)*  | No       | Unsuccessful file-access syscalls that exist only on x86_64 (CIS 4.1.3.6) |
| auditd_file_access                | *(list, 4 items)*  | No       | Unsuccessful file-access syscalls for all architectures |
| auditd_file_delete_x86_only       | *(list, 3 items)*  | No       | File-deletion syscalls that exist only on x86_64 (CIS 4.1.3.9) |
| auditd_file_delete                | *(list, 2 items)*  | No       | File-deletion syscalls for all architectures |
| auditd_kernel_module_x86_only     | *(list, 2 items)*  | No       | Kernel-module syscalls that exist only on x86_64 (CIS 4.1.3.15) |
| auditd_kernel_module_syscalls     | *(list, 3 items)*  | No       | Kernel-module syscalls for all architectures |
| auditd_mount_syscalls             | *(list, 1 items)*  | No       | Mount/export syscalls (CIS 4.1.3.12/14) |
| auditd_privileged_commands_extra  | *(list, 5 items)*  | No       | Extra privileged command paths audited on top of the setuid/setgid binaries found at play time (CIS 4.1.3.13) |
| auditd_watches                    | *(ma, 28 lines)*   | No       | Watchpoints (path, permissions, key) for CIS 4.1.3.2/4/7/10/11/16 |
| auditd_watches_redhat             | *(list, 6 items)*  | No       | Additional watchpoints applied on RedHat-family hosts only |
| auditd_watches_debian             | *(list, 2 items)*  | No       | Additional watchpoints applied on Debian-family hosts only |
Notes:
- See module's README for details on default values. When overriding, new list is not additive, so include originals as well


coredump Role Variables
--------------

Disables core dumps system-wide via two mechanisms:

1. **`/etc/security/limits.conf`** — sets `* hard core 0` so PAM-launched
   processes cannot produce core files regardless of ulimit.
2. **`/etc/systemd/coredump.conf`** — sets `Storage=none` and
   `ProcessSizeMax=0` so systemd-coredump drops any core files it receives.

Both are required: `limits.conf` covers PAM sessions; `coredump.conf` covers
the systemd handler for processes that crash outside a PAM session.

[`:mgcdrd.infrabase.coredump`](roles/coredump/README.md)

**General role variables**

None


crio Role Variables
--------------

Installs CRI-O from the official repository and ensures the service is enabled
and running. Intended for use with Kubernetes — `crio_version` should match
the Kubernetes minor version.

[`:mgcdrd.infrabase.crio`](roles/crio/README.md)

**General role variables**

| Variable     | Default | Required | Description |
|--------------|---------|----------|-------------|
| crio_version | `""`    | Yes      | CRI-O minor version used to build the repo URLs (e.g. `"1.32"`); match the Kubernetes minor version |


cron Role Variables
--------------

Applies CIS cron and at access hardening:

- Removes `/etc/cron.deny` and `/etc/at.deny`
- Ensures `/etc/cron.allow` and `/etc/at.allow` exist with `root:root 0600` permissions
- Restricts cron directories (`cron.d`, `cron.daily`, etc.) to `0700`
- Restricts `/etc/crontab` to `0600`

When `cron.allow` / `at.allow` are present, only users listed in them can use
crontab or at. Empty allow files (what this role creates if they don't exist)
means no non-root users can schedule jobs.

[`:mgcdrd.infrabase.cron`](roles/cron/README.md)

**General role variables**

None

cron_jobs Role Variables
--------------

Manages per-user crontab entries from a variable list. Generic — it ships no
jobs of its own and isn't tied to any specific deployment. This is distinct
from the `cron` role, which only hardens cron/at access control (`cron.allow`,
directory permissions) and does not create or manage individual jobs.

[`:mgcdrd.infrabase.cron_jobs`](roles/cron_jobs/README.md)

**General role variables**

| Variable             | Default | Required | Description |
|----------------------|---------|----------|-------------|
| cron_jobs_defaults   | `[]`    | No       | Per-user cron entries to manage (fields below); an empty list is a no-op |
| cron_jobs_additional | `[]`    | No       | Per-user cron entries to manage (fields below); an empty list is a no-op |

**cron_jobs_defaults and cron_jobs_additional variables**

| Field        | Default     | Required | Description |
|--------------|-------------|----------|-------------|
| name         | `""`        | Yes      | Descriptive job name — used as the idempotency key.       |
| user         | `root`      | No       | User the job will run as.                                 |
| cron_file    | `""`        | No       | Uses this file instead of an individual user’s crontab.   |
| env          | `false`     | No       | Entry is an env var with `<name>=<job>`                   |
| insertbefore | `""`        | No       | Used with `env`, value is `name` of other line            | 
| insertafter  | `""`        | No       | Used with `env`, value is `name` of other line            |
| minute       | `*`         | No       | Cron time fields                                          |
| hour         | `*`         | No       | Cron time fields                                          |
| day          | `*`         | No       | Cron time fields                                          |
| month        | `*`         | No       | Cron time fields                                          |
| weekday      | `*`         | No       | Cron time fields                                          |
| special_time | `""`        | No       | Named schedule - `reboot`, `daily`, `hourly`, `weekly`, `monthly`, `yearly` |
| job          | `""`        | Yes      | Command to run, or value `name` is set to when `env=true` |
| state        | `present`   | No       | `present` if adding, or `absent` is removing              |
| disabled     | `false`     | No       | If set, comment out line but leave it                     |
| backup       | `false`     | No       | Create a backup before it is modified                     |


crypto_policies Role Variables
--------------

Installs `crypto-policies` and deploys CIS-aligned system crypto-policy modules
on RedHat-family hosts (`/etc/crypto-policies/policies/modules/`):

- `NO-SSHCBC`, `NO-SSHWEAKCIPHERS`, `NO-SSHWEAKMACS`: drop weak SSH ciphers and MACs
- `NO-WEAKMAC`, `NO-RPMSHA1`: drop weak MACs and SHA-1 for RPM verification
- Optional extra policy modules from `crypto_policies_additional` (`src` template, `dst` file name)

On Debian-family hosts the role does nothing.

[`:mgcdrd.infrabase.crypto_policies`](roles/crypto_policies/README.md)

**General role variables**

| Variable                   | Default | Required | Description |
|----------------------------|---------|----------|-------------|
| crypto_policies_cis        | `true`  | No       | Apply the CIS-aligned crypto policy |
| crypto_policies_additional | `[]`    | No       | Extra policy modules; each entry takes `src` (template) and `dst` (module file name only, always written under `/etc/crypto-policies/policies/modules/`) |


**aide_exclude_paths options**

| Name  | Default   | Required                                            | Purpose |
|-------|-----------|-----------------------------------------------------|---------|
| src   | `""`      | Yes, only if `crypto_policies_additional` specified | path to template |
| dst   | `""`      | Yes, only if `crypto_policies_additional` specified | basename used for file under `/etc/crypto-policies/policies/modules/` |


docker Role Variables
--------------

Installs Docker CE from Docker's official repository, ensures the service is
enabled and running, and sets the default container logging driver.

[`:mgcdrd.infrabase.docker`](roles/docker/README.md)

**General role variables**

| Variable          | Default                                 | Required | Description |
|-------------------|-----------------------------------------|----------|-------------|
| docker_apt_arch   | *(derived from `ansible_architecture`)* | No       | Architecture name for Docker's apt repo; derived from `ansible_architecture` (x86_64 → amd64, aarch64 → arm64) |
| docker_log_driver | `syslog`                                | No       | Default logging driver for all containers. `syslog`, `json-file`, or `journald`  |
| docker_log_opts   | `[]`                                    | No       | Dictionary. Fields below |

**docker_log_opts variables**

| Field                     | Default                          | Required | Description |
|---------------------------|----------------------------------|----------|-------------|
| docker_syslog_addr        | `unixgram:///dev/log`            | No       | Syslog host to use; default is localhost                  |
| docker_syslog_facility    | `""`                             | No       | Syslog facility used when `docker_log_driver` is `syslog` |
| docker_syslog_format      | `rfc5424`                        | No       | Syslog formatting to use                                  |
| docker_syslog_tag         | `{% raw %}{{.Name}}{% endraw %}` | No       | Tags to be used on log messages                           |
| docker_json_logs_max_size | `10m`                            | No       | JSON file max size, specify units (k, m, g, etc)          |
| docker_json_logs_max_file | `5`                              | No       | JSON file number count                                    |


etc_hosts Role Variables
--------------

A role to populate `/etc/hosts` with cluster peer entries and optional static entries.
Designed for deployments (Kubernetes, HAProxy, Galera, etc.) where each node needs
reliable peer name resolution without depending on DNS.

Cluster entries are auto-populated from inventory facts. Static entries can be defined
manually for infrastructure hostnames outside the managed inventory (shared storage,
registries, external services, etc.).

All entries are written as distinct Ansible-managed blocks, so re-running the role is
fully idempotent and multiple clusters in the same inventory coexist without conflict.

[`:mgcdrd.infrabase.etc_hosts`](roles/etc_hosts/README.md)

**General role variables**

| Variable            | Default | Required | Description |
|---------------------|------|---|---|
| etc_hosts_group     | `""` | One of group or entries | Inventory group whose members are written to `/etc/hosts` on every host in the play; empty skips cluster entries |
| etc_hosts_interface | `ansible_default_ipv4` | No | Facts key used to resolve each host's IP (e.g. `ansible_eth1`, `ansible_bond0`) |
| etc_hosts_entries   | `[]` | One of group or entries | Static entries, each with `ip`, `hostname`, optional `aliases`; not merged across inventory levels |



fail2ban Role Variables
--------------

Installs fail2ban and manages its configuration from variables: jail defaults
(ignored networks, ban times with escalation, firewall action by OS family),
custom jails and filters, and ready-made presets. The `nginx` preset bans
rate-limit offenders, scanner probes and bursts of 4xx responses from the
per-server-block logs written by `mgcdrd.infrasvc.nginx`.

[`:mgcdrd.infrabase.fail2ban`](roles/fail2ban/README.md)

**Jail defaults**

| Variable                       | Default | Required | Description |
|--------------------------------|---------|----------|-------------|
| fail2ban_ignoreip              | *(list, 5 items)*: loopback and RFC 1918 ranges | No | Networks fail2ban never bans; add the environment's trusted ranges |
| fail2ban_bantime               | `1h`    | No       | Ban duration |
| fail2ban_findtime              | `10m`   | No       | Window in which `fail2ban_maxretry` failures trigger a ban |
| fail2ban_maxretry              | `5`     | No       | Failures within `findtime` before a ban |
| fail2ban_bantime_increment     | `true`  | No       | Each repeat offence by the same address increases the ban, up to `fail2ban_bantime_maxtime` |
| fail2ban_bantime_factor        | `2`     | No       | Multiplier applied to the ban on each repeat offence |
| fail2ban_bantime_maxtime       | `4w`    | No       | Upper limit for an escalated ban |
| fail2ban_backend               | `auto`  | No       | Log backend; `auto` lets fail2ban pick per jail, `systemd` reads the journal |
| fail2ban_banaction             | `firewallcmd-ipset` (RedHat), `nftables` (Debian) | No | Firewall action used to ban |
| fail2ban_banaction_allports    | `firewallcmd-ipset` (RedHat), `nftables[type=allports]` (Debian) | No | Firewall action for jails that ban all ports |

**Presets and recidive**

| Variable                           | Default                           | Required | Description |
|------------------------------------|-----------------------------------|----------|-------------|
| fail2ban_presets                   | `[]`                              | No       | Ready-made jails and filters, enabled by name. Available: `nginx` |
| fail2ban_nginx_access_logpath      | `/var/log/nginx/*.access.log`     | No       | nginx preset: access logs to watch |
| fail2ban_nginx_error_logpath       | `/var/log/nginx/*error.log`       | No       | nginx preset: error logs to watch; `limit_req`/`limit_conn` errors land here |
| fail2ban_nginx_limit_req_maxretry  | `100`                             | No       | nginx preset, rate-limit jail: failures before a ban |
| fail2ban_nginx_limit_req_findtime  | `1m`                              | No       | nginx preset, rate-limit jail: window |
| fail2ban_nginx_probe_maxretry      | `2`                               | No       | nginx preset, scanner-probe jail: failures before a ban |
| fail2ban_nginx_probe_findtime      | `10m`                             | No       | nginx preset, scanner-probe jail: window |
| fail2ban_nginx_probe_bantime       | `1d`                              | No       | nginx preset, scanner-probe jail: ban duration |
| fail2ban_nginx_4xx_maxretry        | `30`                              | No       | nginx preset, 4xx jail: failures before a ban |
| fail2ban_nginx_4xx_findtime        | `1m`                              | No       | nginx preset, 4xx jail: window |
| fail2ban_recidive_enabled          | `false`                           | No       | Enable a repeat-offender jail across all jails (presets and custom) |
| fail2ban_recidive_bantime          | `4w`                              | No       | Recidive jail: ban duration |
| fail2ban_recidive_findtime         | `1d`                              | No       | Recidive jail: window |
| fail2ban_recidive_maxretry         | `3`                               | No       | Recidive jail: bans before a longer ban |

**Custom jails and filters**

| Variable          | Default | Required | Description |
|-------------------|---------|----------|-------------|
| fail2ban_jails    | `[]`    | No       | Custom jails; each takes `name` (required), `filter` (default: name), `logpath`, `port`, `maxretry`, `findtime`, `bantime`, `backend`, `banaction`, `enabled` (default `true`) and `options` (extra `key: value` lines) |
| fail2ban_filters  | `[]`    | No       | Custom filters; each takes `name` (required), `failregex` (list) and optional `ignoreregex` |
Notes:
- fail2ban strips the log timestamp before matching, so a `failregex` written against `[15/Oct/2026:10:00:00 +0000]` must use `\[\]`
- RedHat: fail2ban comes from EPEL; firewalld must be running


file_deploy Role Variables
--------------

Deploys arbitrary files, templates, and directories to hosts, with owner/group/mode
set explicitly on every item. Generic — it ships no content of its own and isn't
tied to any specific deployment. Consuming playbooks/deployments supply the file
list and their own `files/`/`templates/` directories.

Each entry in `file_deploy_items` is one file or directory. Files can come from a
source file (copied verbatim or rendered as a Jinja2 template) or from inline
literal content. Ownership and permissions are required on every item — this role
has no distro default to fall back on.

[`:mgcdrd.infrabase.file_deploy`](roles/file_deploy/README.md)

**General role variables**

| Variable          | Default | Required | Description |
|-------------------|---------|----------|-------------|
| file_deploy_items | `[]`    | Yes      | Files, templates, and directories to deploy (fields below); an empty list is a no-op |

**file_deploy_items variables**

| Field       | Required | Description |
|-------------|----------|-------------|
| dest        | Yes      | Destination path. |
| state       | No       | `file` (default) or `directory`. Directories ignore `src`/`content`/`is_template`. |
| src         | No       | Source file, resolved via the calling playbook's `files/`/`templates/`. Mutually exclusive with `content`. |
| content     | No       | Inline literal content, written verbatim (not templated). Mutually exclusive with `src`. |
| is_template | No       | `true` renders `src` with `ansible.builtin.template` (Jinja2); `false` (default) copies it verbatim with `ansible.builtin.copy`. Ignored when `content` is set. |
| owner       | Yes      | Always explicit — no fallback default. |
| group       | Yes      | Always explicit — no fallback default. |
| mode        | Yes      | Always explicit — no fallback default. |
| backup      | No       | Back up the existing file before overwriting. Default: `false`. |


firewall Role Variables
--------------

Installs and configures a host-based firewall with a default-deny inbound
policy. Addresses CIS Benchmark 3.4 (RHEL) and 3.5 (Debian).

| OS family | Tool        | Management |
|-----------|-------------|------------|
| RedHat    | `firewalld` | `ansible.posix.firewalld` module — additive; adds rules, never removes |
| Debian    | `nftables`  | Template-managed `/etc/nftables.conf` — full ruleset replaced on every run |

Default policy: drop inbound, accept outbound, accept established/related,
accept loopback, accept ICMP.

Multiple interfaces are supported: each zone in `firewall_zones` can specify
which interfaces it applies to. On RHEL, this maps directly to firewalld zone
assignment. On Debian, nftables rules are scoped with `iifname { ... }`.

[`:mgcdrd.infrabase.firewall`](roles/firewall/README.md)

**General role variables**

| Variable                      | Default           | Required | Description |
|-------------------------------|-------------------|----------|-------------|
| firewall_default_zone         | `public`          | No       | RedHat only — firewalld default zone for interfaces not explicitly assigned |
| firewall_zones                | *(list, 1 items)* | No       | Zone definitions; keys (name, interfaces, sources, allowed_tcp_ports, …) listed below. Default opens only SSH |
| firewall_zones_extra_<suffix> | not set           | No       | Additional zones layered on top of `firewall_zones`, merged by zone name; define one per group or host layer (see **Layering**) |


**firewall_zones variables**

| Field             | Default | Required | Description |
|-------------------|---------|------------------------|
| name              | `""`    | yes      | firewalld zone name (RedHat) or logical label (Debian) |
| interfaces        | `""`    | no       | Interface names to assign to this zone. Empty = no explicit assignment (default zone).  |
| sources           | `""`    | no       | Source CIDRs/addresses bound to this zone (firewalld `--add-source`). Traffic from them gets the zone's whole ruleset, same as arriving on one of its interfaces (OR'd with `interfaces`). **RedHat only.** |
| allowed_tcp_ports | `""`    | no       | TCP ports to allow inbound on this zone's interfaces |
| allowed_udp_ports | `""`    | no       | UDP ports to allow inbound on this zone's interfaces |
| allowed_services  | `""`    | no       | firewalld named services to allow (e.g. `http`, `https`). **RedHat only.** |
| source_rules      | `""`    | no       | Source-scoped accepts — AND a source with a specific port/service instead of granting the whole zone. Emitted as rich rules. **RedHat only** (Debian logs a warning and ignores them) |
| masquerade        | `""`    | no       | Enable source NAT for traffic forwarded out this zone's interfaces. Requires `interfaces` to be set |
| forward_ports     | `""`    | no       | Port forwards (DNAT) into this zone. Requires `interfaces` to be set |

**source_rules variables**

| Field     | Default | Required | Description |
|-----------|---------|------------------------|
| sources   | Yes     | Source CIDRs/addresses (v4 or v6) the rule matches on |
| tcp_ports | No      | TCP ports to accept from those sources |
| udp_ports | No      | UDP ports to accept from those sources |
| services  | No      | firewalld named services to accept from those sources |

**forward_ports variables**

| Field   | Default | Required | Description |
|---------|---------|------------------------|
| port    | Yes     | External port to forward from |
| proto   | Yes     | `tcp` or `udp` |
| to_port | Yes     | Destination port |
| to_addr | No      | Destination address. Omit to redirect to the same host on `to_port` instead of DNAT'ing to another host |


hardened_services Role Variables
--------------

Hardens system service configuration and misc CIS filesystem/permission
controls that don't warrant their own role, each independently toggleable.

[`:mgcdrd.infrabase.hardened_services`](roles/hardened_services/README.md)

**General role variables**

| Variable                            | Default           | Required | Description |
|-------------------------------------|-------------------|----------|-------------|
| hardened_services_disable_nfs       | `true`            | No       | Disable and mask the NFS server service |
| hardened_services_emergency_auth    | `true`            | No       | Require sulogin authentication for emergency and rescue systemd targets via drop-in overrides in /etc/systemd/system/{emergency,rescue}.service.d/ |
| hardened_services_chronyd_user      | `true`            | No       | Ensure chronyd runs as an unprivileged user (chrony on RedHat, _chrony on Debian) |
| hardened_services_disable_bluetooth | `true`            | No       | Disable and mask unused services |
| hardened_services_disable_autofs    | `true`            | No       | Disable and mask `autofs.service` if present. |
| hardened_services_disable_rpcbind   | `true`            | No       | Disable and mask `rpcbind.service` **and** `rpcbind.socket`. Set to `false` on NFSv3 client/server hosts — rpcbind is required for portmapper lookups. |
| hardened_services_fix_grub_user_cfg | `true`            | No       | chmod 0600 /boot/grub2/user.cfg (GRUB password file) |
| hardened_services_fix_unowned_files | `false`           | No       | Scan real (non-pseudo) local filesystems for files with no owning user or group and chown them to root:root |
| hardened_services_local_fstypes     | *(list, 4 items)* | No       | Local filesystem types to include in the unowned-file scan above |



journald Role Variables
--------------

Configures `systemd-journald` for CIS-aligned persistent logging and syslog
forwarding. Manages `/etc/systemd/journald.conf` via template and restarts
the service on any change.

[`:mgcdrd.infrabase.journald`](roles/journald/README.md)

**General role variables**

| Variable                | Default      | Required | Description |
|-------------------------|--------------|----------|-------------|
| journald_storage        | `persistent` | No       | Where journal data is stored; `persistent` survives reboots under `/var/log/journal/` |
| journald_compress       | `"yes"`      | No       | Compress journal data on disk |
| journald_forward_syslog | `"yes"`      | No       | Forward journal entries to syslog; needed when rsyslog reads from the journal socket |



kernel_modules Role Variables
--------------

Loads kernel modules immediately and persists them across reboots by writing
individual `.conf` files to `/etc/modules-load.d/` via `community.general.modprobe`.

Also supports blacklisting modules — writes `blacklist` and `install /bin/false`
entries to `/etc/modprobe.d/ansible-blacklist.conf` to prevent both autoloading
and manual loading.

Designed to be called by other roles rather than directly. Multiple roles can
call this on the same host safely — each module gets its own file so load runs
are purely additive. Previously loaded modules are never removed by a subsequent
call with a different list.

[`:mgcdrd.infrabase.kernel_modules`](roles/kernel_modules/README.md)

**General role variables**

| Variable                 | Default | Required                 | Description |
|--------------------------|---------|--------------------------|-------------|
| kernel_modules_list      | `[]`    | One of list or blacklist | Kernel modules to load now and persist across reboots |
| kernel_modules_blacklist | `[]`    | One of list or blacklist | Kernel modules to blacklist and block from loading |




login_banner Role Variables
--------------

Deploys a pre-login warning banner to `/etc/issue` (local console) and
`/etc/issue.net` (SSH pre-auth banner, when `Banner /etc/issue.net` is set in
`sshd_config`). Both files receive the same content from a single template.

[`:mgcdrd.infrabase.login_banner`](roles/login_banner/README.md)

**General role variables**

| Variable          | Default                            | Required | Description |
|-------------------|------------------------------------|----------|-------------|
| login_banner_text | *(standard authorized-use notice)* | No       | Banner text written to `/etc/issue` and `/etc/issue.net` |
Notes:
- See module's README for details on default values. When overriding, new list is not additive, so include originals as well


network_interfaces Role Variables
--------------

Configures Linux host network interfaces — physical NICs, LACP bonds, and
802.1q VLAN subinterfaces — through NetworkManager (`nmcli`), driven by a
single `network_interfaces` list.

Debian defaults to `ifupdown`, not NetworkManager, so on Debian this role
installs `network-manager`, sets `[ifupdown] managed=true` in
`/etc/NetworkManager/NetworkManager.conf` so NM will take over interfaces
even if something is still referencing them from `/etc/network/interfaces`,
and enables the service. Rocky already runs NetworkManager by default — the
role just ensures the package is present and the service is running. From
there, interface configuration itself is one shared `nmcli`-based task path
for all four OS targets — no OS-family branching in `configure.yml`.

[`:mgcdrd.infrabase.network_interfaces`](roles/network_interfaces/README.md)

**General role variables**

| Variable           | Default | Required | Description |
|--------------------|---------|----------|-------------|
| network_interfaces | `[]`    | Yes      | Physical, bond, and VLAN definitions (keys below); empty is a no-op. Opt-in per host because a wrong device name can cut the SSH session |


**network_interfaces variables**

| Field (all types) | Required | Description |
|-------------------|----------|-------------|
| name              | Yes      | nmcli connection name |
| type              | Yes      | `physical`, `bond`, or `vlan` |
| state             | No       | `present` or `absent`. Default: `present` |
| autoconnect       | No       | Start on boot. Default: `true` |
| method4           | No       | `manual`, `auto`, or `disabled`. Default: `manual` |
| ip4               | No       | List of IPv4 CIDRs |
| gw4               | No       | IPv4 gateway |
| dns4              | No       | List of IPv4 DNS servers |
| mtu               | No       | Interface MTU |

| Field (`type: physical`) | Required | Description                               |
|--------------------------|----------|-------------------------------------------|
| device                   | no       | Kernel interface name. Defaults to `name` |

| Field (`type: bond`) | Required | Description |
|----------------------|----------|-------------|
| device               | No       | Bond interface name. Defaults to `name` |
| bond_mode            | No       | Default: `802.3ad` (LACP) |
| bond_miimon          | No       | MII link monitor interval, ms. Default: `100` |
| bond_members         | Yes      | List of physical device names to enslave |

| Field (`type: vlan`) | Required | Description |
|----------------------|----------|-------------|
| vlan_id              | Yes      | 802.1q VLAN ID (0-4095) |
| vlan_parent          | Yes      | Parent's device name — a `physical` or `bond` entry's `device` |

`bond_members` entries each become their own nmcli slave connection
(`<bond name>-slave-<device>`) — don't also declare them as separate
`type: physical` entries; a bonded NIC carries no L3 config of its own.


pam Role Variables
--------------

Configures the PAM stack on RedHat-family hosts:

- Selects an `authselect` profile and enables its features (mkhomedir, sudo, faillock, pwhistory)
- Restricts `su` to members of a dedicated group via `pam_wheel`

On Debian-family hosts the role does nothing.

[`:mgcdrd.infrabase.pam`](roles/pam/README.md)

**General role variables**

| Variable                | Default           | Required | Description |
|-------------------------|-------------------|----------|-------------|
| pam_authselect_profile  | `sssd`            | No       | `authselect` profile to select (RedHat); moving off `sssd` on IPA-enrolled hosts breaks LDAP auth |
| pam_authselect_features | *(list, 4 items)* | No       | Features enabled on the profile; `with-faillock` and `with-pwhistory` wire in the `password_policy` conf files |
| pam_su_group            | `sugroup`         | No       | Group allowed to `su` via `pam_wheel`; created empty, so add members explicitly |
Note:
- `with-mkhomedir`, `with-sudo`, `with-faillock`, `with-pwhistory`


password_policy Role Variables
--------------

Enforces CIS-aligned password quality, aging, lockout, and session timeout
policy across Debian and RedHat family systems. Manages:

- `/etc/security/pwquality.conf` — character class requirements and minimum length
- `/etc/login.defs` — password aging and umask
- `/etc/default/useradd` — inactive account lockout
- `/etc/profile` and `/etc/bash.bashrc` (Debian) / `/etc/bashrc` (RedHat) — TMOUT and umask
- `/etc/security/faillock.conf` + `/etc/security/pwhistory.conf` — **RedHat only**


[`:mgcdrd.infrabase.password_policy`](roles/password_policy/README.md)

**General role variables**

| Variable                                | Default            | Required | Description |
|-----------------------------------------|--------------------|----------|-------------|
| password_policy_pwquality               | *(list, 12 items)* | Yes      | `pwquality.conf` settings as `{key, value}` pairs; negative credit values are minimums |
| password_policy_pass_max_days           | `60`               | No       | Maximum password age in days (`PASS_MAX_DAYS`) |
| password_policy_pass_min_days           | `7`                | No       | Minimum days between password changes (`PASS_MIN_DAYS`) |
| password_policy_shadow_reconcile        | `[]`               | No       | Usernames allowed to have a missing `/etc/shadow` entry created with `pwconv`; any other passwd-only account fails the run |
| password_policy_login_defs              | *(list, 5 items)*  | No       | `/etc/login.defs` settings as `{key, value}` pairs |
| password_policy_inactive_days           | `30`               | No       | Days before an account is locked after its password expires |
| password_policy_tmout                   | `900`              | No       | Shell session idle timeout in seconds |
| password_policy_umask                   | `"027"`            | No       | Default umask for interactive shells |
| password_policy_faillock_deny           | `3`                | No       | Maximum consecutive failed logins before lockout (RedHat only — faillock.conf) |
| password_policy_faillock_unlock_time    | `900`              | No       | Seconds before a locked account is automatically unlocked (RedHat only) |
| password_policy_faillock_even_deny_root | `true`             | No       | Also lock root after failed attempts (RedHat only) |
| password_policy_remember                | `24`               | No       | Number of previous passwords to remember (RedHat only — pwhistory.conf) |
| password_policy_pwhistory_enforce_root  | `true`             | No       | Enforce pwhistory for root as well (RedHat only) |


**password_policy_pwquality variables**

List of key/value pairs written to `/etc/security/pwquality.conf`:

| Field          | Default | Description |
|----------------|---------|-------------|
| lcredit        | `-1`    | Minimum lowercase characters required |
| ucredit        | `-1`    | Minimum uppercase characters required |
| dcredit        | `-1`    | Minimum digit characters required |
| ocredit        | `-1`    | Minimum special characters required |
| difok          | `8`     | Characters that must differ from previous password |
| minclass       | `4`     | Minimum character classes required |
| maxrepeat      | `3`     | Maximum consecutive identical characters |
| maxclassrepeat | `4`     | Maximum consecutive same-class characters |
| minlen         | `15`    | Minimum password length |

**password_policy_login_defs variables**

List of key/value pairs written to `/etc/login.defs`:

| Field         | Default | Description |
|---------------|---------|-------------|
| PASS_MAX_DAYS | `60`    | Maximum password age in days |
| PASS_MIN_DAYS | `7`     | Minimum days between password changes |
| PASS_MIN_LEN  | `15`    | Minimum password length (backup enforcement) |
| UMASK         | `027`   | Default umask for new accounts |
| FAIL_DELAY    | `4`     | Seconds to delay on failed login |


podman Role Variables
--------------

Installs Podman from the base OS repositories and enables the Podman socket.
No external repository configuration is required — Podman is available in the
default repos on all supported platforms.

Primarily intended for standalone container hosts. Not recommended for
Kubernetes nodes without additional CRI shim configuration.

[`:mgcdrd.infrabase.podman`](roles/podman/README.md)

**General role variables**

None. Podman requires no version pinning or external repository.


postfix Role Variables
--------------

A role to install and configure Postfix MTA on Debian and RedHat family systems.

Supports two operating modes:
- **client** — sends all outbound mail through a configured relay host (typical for application or infrastructure hosts)
- **relay** — accepts mail from trusted networks and forwards it onward (the relay host itself)

[`:mgcdrd.infrabase.postfix`](roles/postfix/README.md)

**General role variables**

| Variable                   | Default                   | Required | Description |
|----------------------------|---------------------------|----------|-------------|
| postfix_mode               | `client`                  | No       | `client` sends all mail to a relay; `relay` accepts mail from `postfix_mynetworks` and forwards it |
| postfix_myhostname         | `"{{ ansible_fqdn }}"`    | No       | Fully qualified hostname of this mail system |
| postfix_mydomain           | `"{{ ansible_domain }}"`  | No       | Local internet domain name |
| postfix_myorigin           | `$mydomain`               | No       | Domain appended to locally posted mail |
| postfix_inet_interfaces    | `loopback-only`           | Yes      | Interfaces Postfix listens on: `loopback-only` (client mode) or `all` (needed for relay mode) |
| postfix_inet_protocols     | `all`                     | No       | IP protocols to use: `all`, `ipv4`, `ipv6` |
| postfix_relayhost          | `""`                      | If `postfix_mode` is `client` | Host to forward outbound mail to, e.g. `[mail.example.com]:587`; optional in relay mode |
| postfix_sasl_enabled       | `false`                   | No       | Authenticate to the upstream relay with SASL (credentials variables are documented below) |
| postfix_mynetworks         | `"127.0.0.0/8 [::1]/128"` | No       | Networks trusted to relay mail through this host |
| postfix_relay_domains      | `""`                      | No       | Domains this relay accepts and forwards mail for; empty relays only for hosts in `postfix_mynetworks` |
| postfix_tls_enabled        | `true`                    | No       | Enable TLS support; disabling is not recommended |
| postfix_tls_security_level | `may`                     | No       | `may` (opportunistic) or `encrypt` (require TLS) |
| postfix_aliases            | `{}`                      | No       | Key/value pairs added to /etc/aliases |


rsyslog Role Variables
--------------

Installs rsyslog, sets CIS-required log file permissions, and configures
forwarding and/or receiving — from a single upstream client all the way up
to a multi-port category-routed aggregator with a queue-spooled relay.

Addresses CIS Benchmark 4.2.1.1–4.2.1.6. Designed to complement the
`mgcdrd.infrabase.journald` role — when `journald_forward_syslog: yes` (the
default), journald pipes all entries into rsyslog's socket so a single
forwarding rule ships everything.

[`:mgcdrd.infrabase.rsyslog`](roles/rsyslog/README.md)

**General role variables**

| Variable                                | Default     | Required | Description |
|-----------------------------------------|-------------|----------|-------------|
| rsyslog_file_create_mode                | `"0640"`    | No       | Permissions on log files rsyslog creates (CIS 4.2.1.3) |
| rsyslog_preserve_fqdn                   | `true`      | No       | Keep the full FQDN in hostnames instead of the short name, for local and received messages |
| rsyslog_remote_host                     | `""`        | No       | Central syslog host to forward everything to (the common client case); empty disables forwarding |
| rsyslog_remote_port                     | `514`       | No       | Remote syslog port |
| rsyslog_remote_protocol                 | `tcp`       | No       | `tcp` or `udp`; TCP is preferred for reliable delivery |
| rsyslog_remote_zip_level                | `0`         | No       | omfwd compression: 0 is off, 1 to 9 sets ZipLevel |
| rsyslog_receiver_enable                 | `false`     | No       | Make this host a syslog receiver on a single TCP/UDP port pair |
| rsyslog_receiver_tcp_port               | `514`       | No       | TCP listen port when the receiver is enabled |
| rsyslog_receiver_udp_port               | `514`       | No       | UDP listen port when the receiver is enabled |
| rsyslog_listeners                       | `[]`        | No       | Advanced multi-port inputs, one entry per listener (fields below) |
| rsyslog_file_inputs                     | `[]`        | No       | Flat files or globs tailed into the local rsyslog pipeline (fields below) |
| rsyslog_rulesets                        | `[]`        | No       | Rulesets routing messages to a local dynamic file, a forward action, or both (fields below) |
| rsyslog_log_archive_enable              | `false`     | No       | Compress, archive, and purge the dynamic `*.log` files written by `rsyslog_rulesets` |
| rsyslog_log_archive_source_dir          | `/syslog`   | No       | Tree scanned for `*.log` files; should contain the ruleset `path` values |
| rsyslog_log_archive_dest_dir            | `/archive`  | No       | Destination for compressed files once past `rsyslog_log_archive_move_after_days` |
| rsyslog_log_archive_compress_after_days | `1`         | No       | `find -mtime` threshold for gzip compression |
| rsyslog_log_archive_move_after_days     | `4`         | No       | `find -mtime` threshold for moving to the destination dir |
| rsyslog_log_archive_delete_after_days   | `180`       | No       | `find -mtime` threshold for deletion from the destination dir |
| rsyslog_log_archive_script_path         | `/usr/local/sbin/logrotation.sh` | No       | Install path of the rotation script |
| rsyslog_log_archive_cron_hour           | `"0"`       | No       | Cron hour for the rotation job |
| rsyslog_log_archive_cron_minute         | `"1"`       | No       | Cron minute for the rotation job |


**rsyslog_listeners variables**
Role Variables — advanced (multi-port / multi-target)

One entry per input. Binds to a named ruleset (see below) or, if `ruleset`
is omitted, falls through to rsyslog's default ruleset.

| Field    | Default             | Description |
|----------|---------------------|-------------|
| address  | *(all interfaces)*  | Bind address. Omit to listen on all interfaces. |
| port     | — required          | Listen port. |
| protocol | — required          | `udp` or `tcp`. |
| ruleset  | *(defaut rulleset)* | Named ruleset from `rsyslog_rulesets` to route into. |


**rsyslog_rulesets variables**

Each ruleset routes messages to one or more destinations — a local dynamic
file, a forward action, or both.

| Field        | Default    | Description |
|--------------|------------|-------------|
| name         | — required | Ruleset name, no spaces. |
| exclusive    | `false`    | `false`: every destination fires independently, each optionally gated by its own `when`. `true`: destinations form an if/elif/…/else chain — first match wins. A destination with no `when` is the else/default branch and **must be listed last**. |
| queue        | *(unset)*  | Optional dict enabling a disk-spooled queue on this ruleset — see below. Omit for no queue. |
| destinations | — required | List of destination dicts — see below. |

**rsyslog_rulesets[].queue variables**

`queue` fields (all optional):

| Field            | Default              | Description |
|------------------|----------------------|-------------|
| spool_directory  | `/var/spool/rsyslog` | Must exist and be writable by the rsyslog user; the role does not create it. |
| filename         | ruleset name         | Queue file base name. |
| max_disk_space   | `1g`                 | Disk cap for spooled messages. |
| type             | `LinkedList`         | rsyslog queue type. |
| save_on_shutdown | `true`               | Persist in-flight queue across restarts. |


**rsyslog_rulesets[].destinations variables**

`destinations` fields:

| Field            | Applies to | Default             | Description |
|------------------|------------|---------------------|-------------|
| when             | any        | *(unconditional)*   | Rainerscript condition string, e.g. `'$hostname contains "web"'` or `'prifilt("authpriv.*")'`. Omit for unconditional (or the else branch when `exclusive: true`). |
| type             | any        | — required          | `file` or `forward`. |
| name             | `file`     | `<ruleset>_dest<N>` | Name for the generated `template()` (shows up in the rendered config, e.g. `dynaFile="secure"`). Give two destinations the same `name` to have them share one `template()` declaration and write to the same dynamic file — e.g. routing both `uucp.crit` and `news.crit` to the same spooler log. |
| path             | `file`     | — required          | Dynamic file path using rsyslog property-replacer syntax, e.g. `"/syslog/%HOSTNAME:::lowercase%-%$YEAR%%$MONTH%%$DAY%.log"`. |
| dir_create_mode  | `file`     | `0750`              | |
| file_create_mode | `file`     | `0640`              | |
| owner            | `file`     | `root`              | Applied to both the created directory and file. |
| group            | `file`     | `root`              | Applied to both the created directory and file. |
| target           | `forward`  | — required          | Destination host/IP. |
| port             | `forward`  | `514`               | |
| protocol         | `forward`  | `tcp`               | `tcp` or `udp`. |
| zip_level        | `forward`  | `0`                 | `omfwd` `ZipLevel` (0 = off, 1–9 = compress). |


secure_mounts Role Variables
--------------

Applies security-hardened mount options (`nodev`, `noexec`, `nosuid`) to a
configurable list of mount points. Defaults to hardening `/dev/shm`.

Uses `ansible.posix.mount` with `state: mounted` — options are applied
immediately and persisted to `/etc/fstab`.

[`:mgcdrd.infrabase.secure_mounts`](roles/secure_mounts/README.md)

**General role variables**

| Variable           | Default           | Required | Description |
|--------------------|-------------------|----------|-------------|
| secure_mounts_list | *(list, 1 items)* | No       | Mounts to harden; each takes `path`, `opts`, and optionally `src`/`fstype` (used when the mount is not already in fstab). Default covers `/dev/shm` |


**secure_mounts_list variables**

List of mount points to configure. Each entry requires:

| Key    | Required | Description |
|--------|----------|-------------|
| path   | Yes      | Mount point path |
| opts   | Yes      | Mount options string |
| src    | Yes      | Device or source (e.g. `none` for tmpfs) |
| fstype | Yes      | Filesystem type (e.g. `tmpfs`, `xfs`) |


sshd Role Variables
--------------

Installs openssh-server, deploys a hardened `sshd_config`, and manages a
crypto drop-in under `sshd_config.d/`. All security-relevant settings have
hardened defaults that can be overridden per host or group.

Handles OS differences between Debian and RedHat families:

| Detail | Debian | RedHat |
|---|---|---|
| Service name | `ssh` | `sshd` |
| Host key group | `ssh` | `ssh_keys` |
| sftp-server path | `/usr/lib/openssh/sftp-server` | `/usr/libexec/openssh/sftp-server` |
| /etc/sysconfig/sshd` | not present | `CRYPTO_POLICY` override removed |

The `sshd_config` is validated with `sshd -t` before being placed — a
syntax error will fail the task without touching the running config.

[`:mgcdrd.infrabase.sshd`](roles/sshd/README.md)

**General role variables**

| Variable                           | Default      | Required | Description |
|------------------------------------|--------------|----------|-------------|
| sshd_manage_package                | `true`       | No       | Install openssh-server; set false if it is already installed |
| sshd_port                          | `22`         | No       | Port sshd listens on |
| sshd_address_family                | `any`        | No       | `inet`, `inet6`, or `any` |
| sshd_listen_addresses              | `[]`         | No       | empty = listen on all interfaces |
| sshd_permit_root_login             | `"no"`       | No       | `PermitRootLogin` policy |
| sshd_max_auth_tries                | `4`          | No       | `MaxAuthTries`: authentication attempts per connection |
| sshd_max_sessions                  | `10`         | No       | `MaxSessions`: multiplexed sessions per connection |
| sshd_pubkey_authentication         | `"yes"`      | No       | `PubkeyAuthentication` |
| sshd_authorized_keys_file          | `".ssh/authorized_keys"` | No | `AuthorizedKeysFile` path |
| sshd_authorized_keys_command       | `""`         | No       | `AuthorizedKeysCommand` lookup program (e.g. for LDAP-backed keys); empty disables |
| sshd_authorized_keys_command_user  | `"nobody"`   | No       | User the lookup command runs as; only written when `sshd_authorized_keys_command` is set |
| sshd_password_authentication       | `"no"`       | No       | `PasswordAuthentication` |
| sshd_permit_empty_passwords        | `"no"`       | No       | `PermitEmptyPasswords` |
| sshd_use_pam                       | `"yes"`      | No       | `UsePAM` |
| sshd_allow_users                   | `[]`         | No       | `AllowUsers`; empty means no restriction |
| sshd_allow_groups                  | `[]`         | No       | `AllowGroups`; empty means no restriction |
| sshd_deny_users                    | `[]`         | No       | `DenyUsers` |
| sshd_deny_groups                   | `[]`         | No       | `DenyGroups` |
| sshd_allow_users_extra_<suffix>    | not set      | No       | Entries added to the matching base list without replacing it; one variable per group or host layer (see **Layering**) |
| sshd_allow_groups_extra_<suffix>   | not set      | No       | Entries added to the matching base list without replacing it; one variable per group or host layer (see **Layering**) |
| sshd_deny_users_extra_<suffix>     | not set      | No       | Entries added to the matching base list without replacing it; one variable per group or host layer (see **Layering**) |
| sshd_deny_groups_extra_<suffix>    | not set      | No       | Entries added to the matching base list without replacing it; one variable per group or host layer (see **Layering**) |
| sshd_login_grace_time              | `60`         | No       | `LoginGraceTime`: seconds to authenticate before disconnect |
| sshd_client_alive_interval         | `300`        | No       | `ClientAliveInterval` in seconds |
| sshd_client_alive_count_max        | `1`          | No       | `ClientAliveCountMax`; the CIS profile requires 1 |
| sshd_log_level                     | `"VERBOSE"`  | No       | `LogLevel` |
| sshd_allow_tcp_forwarding          | `"no"`       | No       | `AllowTcpForwarding` |
| sshd_allow_agent_forwarding        | `"no"`       | No       | `AllowAgentForwarding` |
| sshd_allow_stream_local_forwarding | `"no"`       | No       | `AllowStreamLocalForwarding` |
| sshd_x11_forwarding                | `"no"`       | No       | `X11Forwarding` |
| sshd_print_motd                    | `"no"`       | No       | `PrintMotd` |
| sshd_max_startups                  | `"10:30:60"` | No       | `MaxStartups` (start:rate:full) for unauthenticated connections |
| sshd_banner                        | `""`         | No       | Path to a pre-auth banner file; empty disables |
| sshd_match_blocks                  | `[]`         | No       | Conditional `Match` blocks appended to `sshd_config` (fields below) |
| sshd_match_blocks_extra_<suffix>   | not set      | No       | `Match` blocks appended after the base blocks, in variable-name order |
| sshd_scrub_directives              | *(list, 1 items)* | No  | Directives removed from other `sshd_config.d/*.conf` drop-ins so CIS text-search checks see only this role's values |
| sshd_ciphers                       | *(AES-GCM and AES-CTR; see defaults)*       | No       | `Ciphers` list |
| sshd_kex_algorithms                | *(curve25519, DH group14/16; see defaults)* | No       | `KexAlgorithms` list |
| sshd_macs                          | *(hmac-sha2 etm and non-etm; see defaults)* | No       | `MACs` list |


**Layering: base lists plus custom sets**

To add to a list without restating it, set `sshd_<allow|deny>_<users|groups>_extra_<suffix>` or
`sshd_match_blocks_extra_<suffix>`, with a different suffix per group or host (Ansible replaces a
list when two levels set the same name, but leaves differently named variables alone). The role
unions the base and every extra, in variable-name order.

```yaml
# group_vars/k8smasters.yml
sshd_allow_groups_extra_k8smasters: [kube-admins]

# host_vars/kube1.example.com.yml: adds to the group's list
sshd_allow_groups_extra_host: [backup-ops]
```

An allow list switches the restriction on, so the first extra entry makes `AllowUsers` or
`AllowGroups` take effect where the base list was empty. Setting a base variable itself still
replaces it, as before.


ssl_scripting Role Variables
--------------

Deploys a helper script for generating self-signed certificates and a
`dhparam.pem` file. Intended as a bootstrapping utility where a trusted CA
(e.g. `acme_sh`) is not yet available or not appropriate.

The role writes `make_new_ssl.sh` from a template, then generates a dummy
self-signed cert (`ssl-dummy.key` / `ssl-dummy.crt`) and a Diffie-Hellman
parameter file (`dhparam.pem`) on first run. Subsequent runs are idempotent —
existing files are not regenerated.

[`:mgcdrd.infrabase.ssl_scripting`](roles/ssl_scripting/README.md)

**General role variables**

| Variable                | Default          | Required | Description |
|------------------------|-------------------|----------|-------------|
| ssl_scripting.base_dir | `/root/ssl_gen`   | No       | Directory the script and generated files are placed in |
| ssl_scripting.def_bits | `2048`            | No       | Key size for generated certs and `dhparam.pem` |
| ssl_scripting.def_md   | `sha256`          | No       | Message digest written into the helper script |
| ssl_scripting.country  | `US`              | No       | Country code written into the helper script |
| ssl_scripting.state    | `XX`              | No       | State/province written into the helper script |
| ssl_scripting.locale   | `YY`              | No       | Locality written into the helper script |
| ssl_scripting.org      | `ZZ`              | No       | Organization written into the helper script |
| ssl_scripting.orgunit  | `AA`              | No       | Organizational unit written into the helper script |
| ssl_scripting.email    | `admins@acme.com` | No       | Email address written into the helper script |


storage Role Variables
--------------

Manages disks, LVM and mounts for a host from one variable structure:
partitions, PV/VG/LV create and extend, filesystems, fstab entries and mount
options, swap, and removal of mounts that are no longer defined. It replaces
`lvm2` and `lvm2_provision`, and takes over mount options from `secure_mounts`.

The role is built around the layouts used at build time (kickstart, preseed,
Foreman partition tables). Pick one with `storage_scheme`, then describe only
what differs on this host.

[`:mgcdrd.infrabase.storage`](roles/storage/README.md)

**General role variables**

| Variable                | Default                         | Description |
|-------------------------|---------------------------------|-------------|
| storage_scheme          | `""`                            | Build-time layout to start from: `std`, `base-lvm`, `ext-lvm`, `foreman-el-uefi`, or empty       |
| storage_vg              | `""`                            | VG for mounts that set `lv` without `vg`. Empty: the VG of the root mount, then the profile's VG |
| storage_disks           | `[]`                            | Disks to partition or add to a VG            |
| storage_vgs             | `[]`                            | Extra VG settings (`pesize`) or PVs not described by `storage_disks`       |
| storage_mounts          | `[]`                            | Mounts, merged over the profile by `path`    |
| storage_default_fstype  | `xfs` (RedHat), `ext4` (Debian) | Used when a new mount sets no `fstype`       |
| storage_default_opts    | `defaults`                      | Used when a mount has no `opts` and no existing fstab line                 |
| storage_default_modes   | `/tmp`, `/var/tmp`: `1777`      | Mode applied to a mount point after mounting |
| storage_prune           | `false`                         | Unmount and comment out every disk/network fstab entry that is not defined |
| storage_prune_exclude   | `[]`                            | Extra paths that pruning never touches       |
| storage_prune_fstypes   | `ext2 ext3 ext4 xfs btrfs vfat nfs nfs4 cifs swap` | Filesystem types that pruning considers |
| storage_protected_paths | `/ /boot /boot/efi /usr /var`   | Never pruned, never set to `absent`          |



### Mount entries

```yaml
storage_mounts:
  - path: /var/lib/pgsql        # absolute mount point, or "swap"
    lv: lv_pgsql                # LV-backed: created if missing
    vg: vg_data                 # optional, see storage_vg
    size: 30G                   # a minimum, never shrinks; 100%FREE allowed at creation
    fstype: xfs                 # xfs or ext4
    opts: noatime
    mode: "0750"                # also owner, group
    threshold: 85               # extend by extend_by when usage % >= threshold
    extend_by: 10G
    shadow: false               # true: allow mounting over a non-empty directory
  - path: /srv/share            # any other source: NFS, a device, tmpfs
    src: nfs.example.com:/export/share
    fstype: nfs4
    opts: _netdev,nofail
  - path: /boot                 # no lv/src: adopt the existing mount, set only what you give
    opts: nosuid
  - path: swap
    state: absent               # swapoff, comment out of fstab
```

**storage_mounts[] - Mount variables**

| Field     | Default  | Required             | Description |
|-----------|----------|----------------------|-------------|
| path      | `""`     | Yes                  | absolute mount point, or "swap", any other source: NFS, a device, tmpfs |
| lv        | `""`     | No                   | LV-backed: created if missing |
| vg        | `""`     | Only if `lv` is used | optional, see storage_vg |
| size      | `""`     | Only if `lv` is used | a minimum, never shrinks; 100%FREE allowed at creation |
| fstype    | `""`     | Only if `lv` is used and different than `storage_default_fstype` |
| opts      | `""`     | No                   | xfs or ext4 |
| mode      | `""`     | No                   | also owner, group |
| threshold | `""`     | No                   | extend by extend_by when usage % >= threshold |
| extend_by | `""`     | No                   | 
| shadow    | `""`     | No                   | true: allow mounting over a non-empty directory |
| src       | `""`     | No                   | Used for remote shares like NFS |
| state     | `""`     | No                   | swapoff, comment out of fstab |
Notes:
- the `storage_mounts[]` is very powerful, make sure to look at the roles' README
- A filesystem is only created on a blank device. If a device already holds one, it is kept and mounted as the type it has, with a warning when that differs from `fstype`. 
- Mounting over a directory that has files in it fails unless the entry sets `shadow: true`.


**storage_disks[] - Disk variables**

| Field      | Default  | Required | Description |
|------------|----------|----------|-------------|
| device     | `""`     | Yes      | path to physical disk by-id is preferred but standard /dev/<disk> can be used |
| partitions | `[]`     | Yes      | partitioning scheme |
Notes:
- A partition table is only written to a disk that has no signature at all. The label of an existing table is always kept.
- A disk with no partitions and `vg` set is used whole as a PV.
- PVs are added to VGs and existing PVs are never removed.
- A device that already belongs to a different VG stops the run.


**storage_disks[].partitions - Disk Partition variables**

| Field  | Default  | Required | Description |
|--------|----------|----------|-------------|
| number | `""`     | Yes      | partition number |
| flags  | `[]`     | No       | list of flags to be set on the partition |
| vg     | `""`     | No       | partition becomes a PV in vg_data |
| grow   | `""`     | No       | grow into free space, then pvresize |


**storage_scheme - Profiles**

| storage_scheme  | Layout |
|-----------------|--------|
| std             | `/boot`, swap, `/` as plain partitions; everything adopted |
| base-lvm        | `vGroup_01`: `/`, `/home`, `/tmp`, `/usr`, `/var`, swap (ext4) |
| ext-lvm         | `base-lvm` plus `/opt`, `/usr/local`, `/var/log`, `/var/log/audit` |
| foreman-el-uefi | `vg0`, xfs, `lv_*` names, CIS mount options |
Notes:
- Hosts built differently override per entry, for example the older `vg_00` naming or `vg0-tmp` style: set `storage_vg` and give each entry its own `lv`.


sudoers Role Variables
--------------

Hardens the system sudo configuration:

- Enforces a re-authentication `timestamp_timeout`
- Configures a dedicated sudo log file
- Restricts sudo to a TTY (`use_pty`)
- Disables password-sharing escalation flags (`targetpw`, `rootpw`, `runaspw`)
- Opt-in: declaratively manages per-user/group sudo grants as
  `/etc/sudoers.d/` drop-in files (`sudoers_rules`) — see below

All edits go through `visudo -c` validation — a bad value will fail the task
rather than silently corrupt `/etc/sudoers`.

[`:mgcdrd.infrabase.sudoers`](roles/sudoers/README.md)

**General role variables**
 
| Variable                  | Default             | Required                   | Description |
|---------------------------|---------------------|----------------------------|-------------|
| sudoers_timestamp_timeout | `5`                 | No                         | Minutes before sudo asks for the password again |
| sudoers_log_file          | `/var/log/sudo.log` | No                         | Path for sudo command logging |
| sudoers_use_pty           | `true`              | No                         | Run sudo commands in a pty; blocks background privilege escalation |
| sudoers_disable_pwflags   | *(list, 3 items)*   | No                         | Defaults flags forced off (`targetpw`, `rootpw`, `runaspw`) to stop password-sharing escalation |
| sudoers_rules_group       | `""`                | If `sudoers_rules` is used | Namespace prefix for `/etc/sudoers.d/<group>-<rule>` files; rules not declared under this prefix are pruned, so each caller manages its own slice |
| sudoers_rules             | `[]`                | No                         | Declarative sudoers drop-ins; each takes `name`, `principals` (users and/or `%groups`), plus the command and option fields shown in the README. Files under the group prefix not listed are removed |
Notes:
- `sudoers_rules_group` and `sudoers_rules` are used together with `sudoers_rules_group` being a namespace of sorts so other runs with a different `sudoers_rules_group` won't affect another

**sudoers_rules[] variables**

| Field      | Default   | Required | Description |
|------------|-----------|----------|-------------|
| name       | `""`      | Yes      | becomes part of the sudoers file name |
| principals | `[]`      | Yes      | list of users and groups (must contain the %) |
| commands   | `[]`      | Yes      | list of commands that are allowed |
| state      | `present` | No       | present (default) \| absent |


sysctl Role Variables
--------------

<Short description>

[`:mgcdrd.infrabase.sysctl`](roles/sysctl/README.md)

**General role variables**

| Variable         | Default                              | Required | Description |
|------------------|--------------------------------------|----------|-------------|
| sysctl_conf_file | `/etc/sysctl.d/ansible-managed.conf` | No       | File written under `/etc/sysctl.d/`; override per caller to keep configs namespaced |
| sysctl_params    | `[]`                                 | Yes      | Parameters to apply, each `{name, value}`; empty is a no-op |

**sysctl_params[] variables**
| Field | Default | Required | Description |
|-------|---------|----------|-------------|
| name  | `""`    | Yes      | name of the sysctl |
| value | `""`    | Yes      | value to be set |





































