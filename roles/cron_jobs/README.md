cron_jobs
=========

Manages per-user crontab entries from a variable list. Generic — it ships no
jobs of its own and isn't tied to any specific deployment. This is distinct
from the `cron` role, which only hardens cron/at access control (`cron.allow`,
directory permissions) and does not create or manage individual jobs.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

Role uses only the builtin `ansible.builtin.cron` module.

If the target host also runs the `mgcdrd.infrabase.cron` role, note that its
`/etc/cron.allow` is empty by default — a user must be added to it before
their crontab entries managed here will actually run.


Role Variables
--------------

### Variable reference

| Variable               | Default | Required | Description |
|------------------------|---------|----------|-------------|
| `cron_jobs_defaults`   | `[]`    | No       | Per-user cron entries to manage (fields below); an empty list is a no-op |
| `cron_jobs_additional` | `[]`    | No       | Per-user cron entries to manage (fields below); an empty list is a no-op |

```yaml
cron_jobs_defaults: []
# cron_jobs:
#   - name: nightly backup
#     user: appuser
#     job: /opt/app/bin/backup.sh
#     minute: "30"
#     hour: "2"
#   - name: cleanup tmp
#     user: root
#     special_time: daily
#     job: find /tmp -mtime +7 -delete
#   - name: old report job
#     user: reporting
#     state: absent
```

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


Dependencies
------------

No additional dependencies are required.


Example Playbook
----------------

### Create a crontab file for root with
```
FOO=/dev/null
#Ansible: Auto-updates
0 12 * * 0 /usr/bin/dnf -y update
```

```yaml
- name: Manage app cron jobs
  hosts: app_servers
  become: true
  roles:
    - role: mgcdrd.infrabase.cron_jobs
      vars:
        cron_jobs_defaults:
        - name: FOO
          env: true
          job: /dev/null
          insertbefore: "Auto-updates"
        - name: "Auto-updates"
          user: root
          weekday: 0
          minute: 0
          hour: 12
          job: /usr/bin/dnf -y update
```


Notes
-----

- Each item is passed almost directly through to `ansible.builtin.cron`; see
  that module's documentation for edge cases (e.g. `env` var management,
  `cron_file` for `/etc/cron.d` instead of a user crontab).
- Removing an item from `cron_jobs` does not remove the job from the host —
  set `state: absent` on that item explicitly, then it can be dropped from
  the list on a later run.
