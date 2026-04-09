aide
====

Installs AIDE (Advanced Intrusion Detection Environment), deploys a
configuration covering OS-critical paths, initialises the database on first
run, and schedules a daily integrity check via cron.

The rule set covers `/boot`, `/usr`, `/root`, `/etc`, logs, audit config, PKI,
and cron. Both RedHat-family and Debian-family package paths are included.
Callers can extend coverage with `aide_extra_paths` or suppress specific paths
with `aide_exclude_paths`.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts: true` is required (used to select
the correct AIDE binary path).

The initial database build (`aide --init`) can take several minutes on the
first run, depending on filesystem size. Subsequent runs are fast (no-op if
the database already exists).


Role Variables
--------------

| Variable | Default | Description |
|---|---|---|
| `aide_cron_hour` | `4` | Hour to run the daily check |
| `aide_cron_minute` | `5` | Minute to run the daily check |
| `aide_extra_paths` | `[]` | Additional paths to monitor. Each entry: `{path, rule}` |
| `aide_exclude_paths` | `[]` | Paths to explicitly exclude (`!` prefix added automatically) |

### `aide_extra_paths`

```yaml
aide_extra_paths:
  - { path: /opt/myapp/bin, rule: CONTENT_EX }
  - { path: /srv/data,      rule: DATAONLY }
```

### `aide_exclude_paths`

```yaml
aide_exclude_paths:
  - /var/log/myapp
  - /etc/myapp/dynamic.conf
```


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Configure filesystem integrity monitoring
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.aide
```

With custom paths:

```yaml
- name: Configure filesystem integrity monitoring
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.aide
      vars:
        aide_extra_paths:
          - { path: /opt/vault, rule: CONTENT_EX }
        aide_exclude_paths:
          - /var/log/vault
```


Notes
-----

- The database is only initialised if `/var/lib/aide/aide.db.gz` does not
  exist. To force a rebuild, remove that file and re-run the role.
- AIDE binary path is `/usr/bin/aide` on Debian and `/usr/sbin/aide` on
  RedHat. This is resolved at runtime.
- Rules referencing paths that don't exist (e.g. `/etc/dnf` on Debian) are
  silently skipped by AIDE.
