sudoers
=======

Hardens the system sudo configuration:

- Enforces a re-authentication `timestamp_timeout`
- Configures a dedicated sudo log file
- Restricts sudo to a TTY (`use_pty`)
- Disables password-sharing escalation flags (`targetpw`, `rootpw`, `runaspw`)

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
| `sudoers_use_pty` | `true` | Enforce `Defaults use_pty` — prevents background privilege escalation without a terminal. |
| `sudoers_disable_pwflags` | `[targetpw, rootpw, runaspw]` | List of sudo flags to disable. Prevents escalation via target/root/runas passwords instead of the invoking user's password. |


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

Tighter timeout, no PTY enforcement (e.g. automation accounts):

```yaml
- name: Harden sudo configuration
  hosts: automation
  become: true
  roles:
    - role: mgcdrd.infrabase.sudoers
      vars:
        sudoers_timestamp_timeout: 0
        sudoers_use_pty: false
        sudoers_disable_pwflags: []
```


Notes
-----

- The role uses `backrefs: true` on the first `lineinfile` call to update an
  existing `timestamp_timeout` line in place. If no such line exists, a second
  task inserts it unconditionally.
- `sudoers_disable_pwflags` defaults to all three flags; set to `[]` to skip.
- `sudoers_use_pty` can be set to `false` for service accounts that invoke sudo
  without a TTY (e.g. AWX runner, CI agents).
