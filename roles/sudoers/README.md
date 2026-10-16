sudoers
=======

Hardens the system sudo configuration:

- Enforces a re-authentication `timestamp_timeout`
- Configures a dedicated sudo log file
- Restricts sudo to a TTY (`use_pty`)
- Disables password-sharing escalation flags (`targetpw`, `rootpw`, `runaspw`)
- Opt-in: declaratively manages per-user/group sudo grants as
  `/etc/sudoers.d/` drop-in files (`sudoers_rules`) — see below

All edits go through `visudo -c` validation — a bad value will fail the task
rather than silently corrupt `/etc/sudoers`.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.


Role Variables
--------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `sudoers_timestamp_timeout` | `5` | No | Minutes before sudo asks for the password again |
| `sudoers_log_file` | `/var/log/sudo.log` | No | Path for sudo command logging |
| `sudoers_use_pty` | `true` | No | Run sudo commands in a pty; blocks background privilege escalation |
| `sudoers_disable_pwflags` | *(list, 3 items)* | No | Defaults flags forced off (`targetpw`, `rootpw`, `runaspw`) to stop password-sharing escalation |
| `sudoers_rules_group` | `""` | If `sudoers_rules` is used | Namespace prefix for `/etc/sudoers.d/<group>-<rule>` files; rules not declared under this prefix are pruned, so each caller manages its own slice |
| `sudoers_rules` | `[]` | No | Declarative sudoers drop-ins; each takes `name`, `principals` (users and/or `%groups`), plus the command and option fields shown in the README. Files under the group prefix not listed are removed |


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


Per-user/group sudo grants (`sudoers_rules`)
---------------------------------------------

Opt-in, separate from the global hardening above. Declaratively manages
`/etc/sudoers.d/<sudoers_rules_group>-<rule.name>` drop-in files — creates
every `state: present` entry, and **prunes** any existing file under that
group's prefix that isn't currently declared (removed from the list
entirely, or explicitly `state: absent`). `sudoers_rules` is the complete
source of truth for that group's slice of `/etc/sudoers.d/`, not an
additive patch.

```yaml
sudoers_rules_group: webproxy   # required whenever sudoers_rules is
                                 # non-empty, and while pruning down to []
sudoers_rules:
  - name: nginx-test-restart     # -> /etc/sudoers.d/webproxy-nginx-test-restart
    principals:                  # always a list — users and/or %groups
      - svc-webproxy-devops      # (sudoers' own %group syntax), mixed freely
      - "%webproxy-devops"
    commands:                    # matched literally by sudoers, no
      - /usr/sbin/nginx -t       # wildcards — only these exact invocations
      - /usr/sbin/nginx -s reload
    runas: root                  # user for run as; defaults to root
    nopasswd: true               # if 'NOPASSWD' is needed
    state: present                # present (default) | absent
```

Renders one `Cmnd_Alias` + `User_Alias` + NOPASSWD grant line per rule,
validated with `visudo -cf %s` the same as every other edit this role
makes — a bad rule fails the task, it never reaches a live sudoers file.

**Why `sudoers_rules_group` is required:** it namespaces the file prefix so
multiple unrelated callers (e.g. `deployments/harden`'s baseline hardening
pass and `deployments/webproxy`'s own grant, both invoking this same role)
each manage their own slice of `/etc/sudoers.d/` without one invocation's
prune sweeping up another's files. Never share a group name across
unrelated purposes.

**Gotcha this role guards against:** sudo silently *ignores* any
`/etc/sudoers.d/` file whose name contains a `.` or ends in `~` — a rule
would quietly never apply instead of erroring. `rules.yml` asserts against
this before templating anything.
