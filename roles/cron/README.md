cron
====

Applies CIS cron access hardening: removes `/etc/cron.deny` and ensures
`/etc/cron.allow` exists with `root:root 0600` permissions.

When `cron.allow` is present, only users listed in it can use crontab. An
empty `cron.allow` (which is what this role creates if it doesn't exist) means
no non-root users can schedule cron jobs. Add usernames to the file manually
or via a separate task if specific users need access.

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
- This role only manages access control files. It does not install or configure
  cron daemons.
