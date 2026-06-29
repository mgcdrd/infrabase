cron
====

Applies CIS cron and at access hardening:

- Removes `/etc/cron.deny` and `/etc/at.deny`
- Ensures `/etc/cron.allow` and `/etc/at.allow` exist with `root:root 0600` permissions
- Restricts cron directories (`cron.d`, `cron.daily`, etc.) to `0700`
- Restricts `/etc/crontab` to `0600`

When `cron.allow` / `at.allow` are present, only users listed in them can use
crontab or at. Empty allow files (what this role creates if they don't exist)
means no non-root users can schedule jobs.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.


Role Variables
--------------

None.


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Harden cron access
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.cron
```


Notes
-----

- The `touch` tasks use `modification_time: preserve` and `access_time: preserve`
  so re-runs do not update file timestamps if they already exist.
- The directory/file permission tasks use `failed_when: false` — paths that do
  not exist (e.g. `cron.weekly` on a minimal install) are silently skipped.
- This role only manages access control and permissions. It does not install or
  configure cron daemons.
