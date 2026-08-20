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

```yaml
cron_jobs: []
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

| Field | Required | Description |
|---|---|---|
| `name` | yes | Descriptive job name — used as the idempotency key. |
| `user` | no | User the job runs as. Default: `root`. |
| `job` | yes, unless `state: absent` | Command to run. |
| `minute`, `hour`, `day`, `month`, `weekday` | no | Cron time fields. Default: `*` (every). |
| `special_time` | no | Named schedule (`reboot`, `daily`, `hourly`, `weekly`, `monthly`, `yearly`) instead of explicit time fields. |
| `state` | no | `present` (default) or `absent`. |
| `disabled` | no | `true` writes the job commented out. Default: `false`. |


Dependencies
------------

No additional dependencies are required.


Example Playbook
----------------

```yaml
- name: Manage app cron jobs
  hosts: app_servers
  become: true
  roles:
    - role: mgcdrd.infrabase.cron_jobs
      vars:
        cron_jobs:
          - name: nightly backup
            user: appuser
            job: /opt/app/bin/backup.sh
            minute: "30"
            hour: "2"
          - name: cleanup tmp
            special_time: daily
            job: find /tmp -mtime +7 -delete
```


Notes
-----

- Each item is passed almost directly through to `ansible.builtin.cron`; see
  that module's documentation for edge cases (e.g. `env` var management,
  `cron_file` for `/etc/cron.d` instead of a user crontab).
- Removing an item from `cron_jobs` does not remove the job from the host —
  set `state: absent` on that item explicitly, then it can be dropped from
  the list on a later run.
