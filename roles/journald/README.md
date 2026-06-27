journald
========

Configures `systemd-journald` for CIS-aligned persistent logging and syslog
forwarding. Uses `community.general.ini_file` to manage individual settings in
`/etc/systemd/journald.conf` without touching unmanaged options.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.

The `community.general` collection must be installed (included in
`ansible-base-ee`).


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
