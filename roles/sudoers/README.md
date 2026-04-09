sudoers
=======

Hardens the system sudo configuration: enforces a `timestamp_timeout` and
configures a dedicated sudo log file. Deduplicates any stray `timestamp_timeout`
entries in `/etc/sudoers.d/*` before writing to `/etc/sudoers` to avoid
conflicts.

All edits go through `visudo -c` validation — a bad value will fail the task
rather than silently corrupt `/etc/sudoers`.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.


Role Variables
--------------

| Variable | Default | Description |
|---|---|---|
| `sudoers_timestamp_timeout` | `5` | Minutes before sudo re-prompts for a password. `0` = always prompt, `-1` = never expire. |
| `sudoers_log_file` | `/var/log/sudo.log` | Path for sudo command logging via `Defaults logfile=` |


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Harden sudo configuration
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.sudoers
```

Tighter timeout for bastion hosts:

```yaml
- name: Harden sudo configuration
  hosts: bastions
  become: true
  roles:
    - role: mgcdrd.infrabase.sudoers
      vars:
        sudoers_timestamp_timeout: 0
```


Notes
-----

- The role uses `backrefs: true` on the first `lineinfile` call to update an
  existing `timestamp_timeout` line in place. If no such line exists, a second
  task inserts it unconditionally.
- Only `timestamp_timeout` and `logfile` are managed. All other sudoers
  defaults are left as-is.
