cron
====

Applies CIS cron and at access hardening:

- Removes `/etc/cron.deny` and `/etc/at.deny`
- Ensures `/etc/cron.allow` exists with `root:root 0600` permissions
- Restricts cron directories (`cron.d`, `cron.daily`, etc.) to `0700`
- Restricts `/etc/crontab` to `0600`

When `cron.allow` is present, only users listed in it can use crontab. An
empty `cron.allow` (which is what this role creates if it doesn't exist) means
no non-root users can schedule cron jobs.

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

- The `touch` task uses `modification_time: preserve` and `access_time: preserve`
  so re-runs do not update the file's timestamps if it already exists.
- The directory/file permission tasks use `failed_when: false` — paths that do
  not exist (e.g. `cron.weekly` on a minimal install) are silently skipped.
- This role only manages access control and permissions. It does not install or
  configure cron daemons.
