journald
========

Configures `systemd-journald` for CIS-aligned persistent logging and syslog
forwarding. Manages `/etc/systemd/journald.conf` via template and restarts
the service on any change.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.


Role Variables
--------------

| Variable | Default | Description |
|---|---|---|
| `journald_storage` | `persistent` | Where to store journal data. `persistent` writes to `/var/log/journal/` and survives reboots. |
| `journald_compress` | `yes` | Compress journal data on disk. |
| `journald_forward_syslog` | `yes` | Forward journal entries to the syslog socket. Set to `no` if rsyslog reads directly from the journal. |


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Configure journald
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.journald
```

Disable syslog forwarding if using imjournal in rsyslog:

```yaml
- name: Configure journald
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.journald
      vars:
        journald_forward_syslog: "no"
```


Notes
-----

- The role restarts `systemd-journald` when any setting changes. Existing journal
  data is preserved — `Storage=persistent` does not clear volatile data.
- `/var/log/journal/` is created automatically by journald on first restart when
  `Storage=persistent` is set.
- `systemd-journal-remote` is **not** installed by this role — `ForwardToSyslog`
  is native to journald and needs no extra package. If something else pulls
  the package in, `systemd-journal-remote.socket` is masked rather than left
  merely disabled (CIS `socket_systemd-journal-remote_disabled` — a disabled
  but unmasked socket can still be started on demand).
