postgresql
==========

Installs a native PostgreSQL server from the PGDG repository and manages its
listener, TLS, and host-based auth through a `conf.d` drop-in and a fully
templated `pg_hba.conf`. Optionally bootstraps roles and databases.

Built for dedicated database hosts — including Proxmox LXC containers, where
running the official Postgres container under an unprivileged LXC is awkward.
For the containerised alternative see the inline Docker Compose path in
`deployments/keycloak`.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

- `become: true` and `gather_facts: true`.
- Internet or a local mirror for the PGDG repository (or set
  `postgresql_manage_repo: false` and provide the packages yourself).
- Role/database bootstrap (`postgresql_roles`, `postgresql_databases`,
  `postgresql_privileges`) needs the **`community.postgresql`** collection and
  local `peer` access for the `postgres` OS user — keep the default
  `local all all peer` row in `postgresql_hba_entries`.


Role Variables
--------------

### Version / packages

| Variable | Default | Description |
|---|---|---|
| `postgresql_version` | `"18"` | Major version. Selects the PGDG package set and all on-disk paths. |
| `postgresql_manage_repo` | `true` | Add the PGDG repo (yum repo RPM on RHEL, apt source + key on Debian). |
| `postgresql_packages_extra` | `[]` | Extra packages installed with the server. |

### Listener

| Variable | Default | Description |
|---|---|---|
| `postgresql_listen_addresses` | `"localhost"` | `listen_addresses` value. Add the host's own address(es) for remote access. |
| `postgresql_port` | `5432` | Listen port. |
| `postgresql_settings` | `{}` | Arbitrary extra GUCs, written to the drop-in as `key = 'value'`. |

### TLS

| Variable | Default | Description |
|---|---|---|
| `postgresql_ssl` | `false` | Enable server-side TLS. |
| `postgresql_ssl_cert_file` | `""` | Path to the certificate PEM. Required when `postgresql_ssl`. |
| `postgresql_ssl_key_file` | `""` | Path to the private key PEM. Required when `postgresql_ssl`. |
| `postgresql_ssl_ca_file` | `""` | Optional `ssl_ca_file` for client-cert verification. |
| `postgresql_ssl_dir` | `""` | Private dir the cert/key are copied into (`root:postgres`, `0640`). Empty **and** `postgresql_manage_cert: false` means the cert/key are used in place — they must already be readable by `postgres`. When set, or when `postgresql_manage_cert` is true, the files are copied to `<dir>/server.{crt,key}` (default dir: `<data_dir>/certs`). |
| `postgresql_ssl_min_protocol_version` | `"TLSv1.2"` | `ssl_min_protocol_version`. |
| `postgresql_manage_cert` | `false` | Issue the cert with `mgcdrd.infrabase.acme_sh` from inside this role. Off by default — normally the caller issues the cert (any CA / challenge) and points `postgresql_ssl_cert_file` / `_key_file` at the result. |
| `postgresql_acme_certs` | `[]` | Passed straight to `acme_sh_certs` when `postgresql_manage_cert`. |

### Host-based auth

| Variable | Default | Description |
|---|---|---|
| `postgresql_hba_entries` | local `peer` + loopback `scram-sha-256` | `pg_hba.conf` is rendered **entirely** from this list, in order — nothing else is kept. Each entry: `type`, `database`, `user`, `address` (omit for `type: local`), `method`. |

### Roles / databases / privileges

Applied only when non-empty.

| Variable | Default | Description |
|---|---|---|
| `postgresql_roles` | `[]` | `community.postgresql.postgresql_user` items: `name`, `password` (use a `vault_` var), `role_attr_flags`, `state`. |
| `postgresql_databases` | `[]` | `community.postgresql.postgresql_db` items: `name`, `owner`, `encoding`, `lc_collate`, `lc_ctype`, `template`, `state`. |
| `postgresql_privileges` | `[]` | `community.postgresql.postgresql_privs` items: `roles`, `database`, `privs`, `type`, `objs`, `schema`, `state`. |


OS-family differences
---------------------

| | RHEL (PGDG) | Debian (PGDG) |
|---|---|---|
| Service unit | `postgresql-{{ version }}` | `postgresql@{{ version }}-main` |
| Data dir | `/var/lib/pgsql/{{ version }}/data` | `/var/lib/postgresql/{{ version }}/main` |
| Config dir | the data dir | `/etc/postgresql/{{ version }}/main` |
| Cluster init | explicit `postgresql-{{ version }}-setup initdb` | automatic (`pg_createcluster` on package install) |
| Appstream conflict | `dnf module disable postgresql` on EL9 only | n/a |


Notes
-----

- `pg_hba.conf` is regenerated from `postgresql_hba_entries` on every run.
  Anything added by hand is removed.
- Changing `listen_addresses`, `port` or the `ssl*` settings triggers a
  **restart**; `pg_hba.conf` and cert-file changes trigger a **reload**.
  Handlers are flushed at the end of `configure.yml` so a following bootstrap
  connects against the new config.
- Hardening: the drop-in and `pg_hba` template do not open anything wider than
  loopback by default. Scope remote rows to specific client CIDRs. Avoid the
  common `host all postgres 0.0.0.0/0 scram-sha-256` shortcut — grant only the
  application role from the application hosts, e.g.
  `{ type: host, database: keycloak, user: keycloak, address: "10.0.0.11/32", method: scram-sha-256 }`.
- `postgresql_manage_repo: false` skips the repo but still expects the
  versioned package names to resolve.


Example
-------

```yaml
- name: Native PostgreSQL for Keycloak
  hosts: kc_pgsql
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.postgresql
      vars:
        postgresql_version: "18"
        postgresql_listen_addresses: "localhost,{{ ansible_default_ipv4.address }}"
        postgresql_ssl: true
        postgresql_ssl_cert_file: /etc/ssl/acme/db1.example.com/fullchain.pem
        postgresql_ssl_key_file: /etc/ssl/acme/db1.example.com/key.pem
        postgresql_hba_entries:
          - { type: local, database: all, user: all, method: peer }
          - { type: host, database: all, user: all, address: "127.0.0.1/32", method: scram-sha-256 }
          - { type: host, database: keycloak, user: keycloak, address: "10.0.0.11/32", method: scram-sha-256 }
          - { type: host, database: keycloak, user: keycloak, address: "10.0.0.12/32", method: scram-sha-256 }
        postgresql_roles:
          - name: keycloak
            password: "{{ vault_keycloak_db_password }}"
            role_attr_flags: LOGIN
        postgresql_databases:
          - name: keycloak
            owner: keycloak
```


License
-------

GPL-3.0-or-later
