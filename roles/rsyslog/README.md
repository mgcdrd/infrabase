rsyslog
=======

Installs rsyslog, sets CIS-required log file permissions, and optionally
configures remote log forwarding and/or receiver mode.

Addresses CIS Benchmark 4.2.1.1–4.2.1.6. Designed to complement the
`mgcdrd.infrabase.journald` role — when `journald_forward_syslog: yes` (the
default), journald pipes all entries into rsyslog's socket so a single
forwarding rule ships everything.

Configuration is drop-in only — `/etc/rsyslog.conf` is not modified. All
managed files live under `/etc/rsyslog.d/`:

| File | Purpose | Deployed when |
|------|---------|---------------|
| `10-file-mode.conf` | `$FileCreateMode` (CIS 4.2.1.3) | Always |
| `50-remote.conf` | Remote forwarding (CIS 4.2.1.5) | `rsyslog_remote_host` is set |
| `90-receive.conf` | Receiver input modules (CIS 4.2.1.6) | `rsyslog_receiver_enable: true` |

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts: true` is required (used for
OS-family apt cache update).


Role Variables
--------------

| Variable | Default | Description |
|---|---|---|
| `rsyslog_file_create_mode` | `0640` | Permissions for log files created by rsyslog. |
| `rsyslog_remote_host` | `""` | Remote syslog server FQDN or IP. Leave empty to skip forwarding. |
| `rsyslog_remote_port` | `514` | Remote syslog port. |
| `rsyslog_remote_protocol` | `tcp` | `tcp` or `udp`. TCP is preferred for reliable delivery. |
| `rsyslog_receiver_enable` | `false` | Accept incoming syslog from other hosts (log server role). |
| `rsyslog_receiver_tcp_port` | `514` | TCP listen port when receiver is enabled. |
| `rsyslog_receiver_udp_port` | `514` | UDP listen port when receiver is enabled. |


Dependencies
------------

None. Pairs with `mgcdrd.infrabase.journald` — ensure `journald_forward_syslog: yes`
(the default) so journal entries reach rsyslog.


Example Playbook
----------------

Client — forward to central log server:

```yaml
- name: Configure rsyslog client
  hosts: all
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.journald   # ensures ForwardToSyslog=yes
    - role: mgcdrd.infrabase.rsyslog
      vars:
        rsyslog_remote_host: syslog.example.com
```

Log server — receive from other hosts (no forwarding):

```yaml
- name: Configure central syslog receiver
  hosts: syslog_servers
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.rsyslog
      vars:
        rsyslog_receiver_enable: true
```

Log server that also forwards upstream (syslog relay):

```yaml
- name: Configure syslog relay
  hosts: syslog_relay
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.rsyslog
      vars:
        rsyslog_remote_host: upstream-syslog.example.com
        rsyslog_receiver_enable: true
```

CIS-only — permissions fix, no remote forwarding:

```yaml
- name: Configure rsyslog (local only)
  hosts: air_gapped
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.rsyslog
```


Notes
-----

- **journald forwarding**: journald writes to `/run/systemd/journal/syslog` when
  `ForwardToSyslog=yes`. rsyslog reads this socket via its built-in `imjournal`
  or `imuxsock` module (present in the vendor `rsyslog.conf` on both Debian and
  RHEL). No additional configuration is needed for this to work.
- **$FileCreateMode**: This is a global rsyslog directive. It affects all log
  files rsyslog creates going forward, not files that already exist. Fix
  permissions on existing files separately if needed.
- **Receiver firewall**: When `rsyslog_receiver_enable: true`, open port 514
  (TCP and/or UDP) via `mgcdrd.infrabase.firewall`. rsyslog will not open the
  port automatically.
- **omfwd vs legacy syntax**: The `50-remote.conf` template uses the modern
  `omfwd` RainerScript action (rsyslog v7+). Both RHEL 9 and Debian 12 ship
  rsyslog v8, so this is safe.
- **Removing forwarding**: Set `rsyslog_remote_host: ""` and re-run to remove
  `50-remote.conf` and restart rsyslog. The role is fully reversible.
