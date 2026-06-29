coredump
========

Disables core dumps system-wide via two mechanisms:

1. **`/etc/security/limits.conf`** — sets `* hard core 0` so PAM-launched
   processes cannot produce core files regardless of ulimit.
2. **`/etc/systemd/coredump.conf`** — sets `Storage=none` and
   `ProcessSizeMax=0` so systemd-coredump drops any core files it receives.

Both are required: `limits.conf` covers PAM sessions; `coredump.conf` covers
the systemd handler for processes that crash outside a PAM session.

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
- name: Disable core dumps
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.coredump
```


Notes
-----

- Changes to `limits.conf` apply to new PAM sessions. Existing sessions are
  unaffected until the user logs out and back in.
- `coredump.conf` is read by systemd-coredump at event time — no restart
  required for it to take effect.
- This role does not set `fs.suid_dumpable`. To disable SUID core dumps via
  sysctl, add `{ name: fs.suid_dumpable, value: 0 }` to your `sysctl` role
  invocation.
