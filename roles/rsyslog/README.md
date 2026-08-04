rsyslog
=======

Installs rsyslog, sets CIS-required log file permissions, and configures
forwarding and/or receiving — from a single upstream client all the way up
to a multi-port category-routed aggregator with a queue-spooled relay.

Addresses CIS Benchmark 4.2.1.1–4.2.1.6. Designed to complement the
`mgcdrd.infrabase.journald` role — when `journald_forward_syslog: yes` (the
default), journald pipes all entries into rsyslog's socket so a single
forwarding rule ships everything.

Configuration is drop-in only — `/etc/rsyslog.conf` is not modified. All
managed files live under `/etc/rsyslog.d/`:

| File | Purpose | Deployed when |
|------|---------|---------------|
| `05-global.conf` | `$PreserveFQDN` | Always |
| `10-file-mode.conf` | `$FileCreateMode` (CIS 4.2.1.3) | Always |
| `15-file-inputs.conf` | File inputs (`imfile`) — tails flat files with no native syslog output | `rsyslog_file_inputs` is non-empty |
| `20-rulesets.conf` | Named rulesets — local file routing and/or forwarding | `rsyslog_rulesets` is non-empty |
| `30-listeners.conf` | Input modules (CIS 4.2.1.6) — merges `rsyslog_receiver_enable`'s port pair and `rsyslog_listeners` into one file so `imudp`/`imtcp` are each loaded once | Either is set |
| `50-remote.conf` | Single-target forwarding (CIS 4.2.1.5) | `rsyslog_remote_host` is set |

`rsyslog_log_archive_*` deploys a log compress/archive/purge script (default
path `/usr/local/sbin/logrotation.sh`) plus a daily root cron job — see
below. Not part of the `/etc/rsyslog.d/` drop-in set above.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts: true` is required (used for
OS-family apt cache update).


Two ways to configure this role
--------------------------------

**Simple vars** (`rsyslog_remote_host`, `rsyslog_receiver_enable`, etc.) cover
the common case — a client forwarding to one upstream, or a server listening
on one port pair. Start here.

**List vars** (`rsyslog_listeners`, `rsyslog_rulesets`) are additive and only
needed for multi-port aggregation, category-based log routing, or a
queue-spooled relay that forwards to different upstreams by hostname match.
Both mechanisms can be used together on the same host — e.g. a simple
receiver plus an extra category-routed listener.


Role Variables — simple
------------------------

| Variable | Default | Description |
|---|---|---|
| `rsyslog_file_create_mode` | `0640` | Permissions for log files created by rsyslog. |
| `rsyslog_preserve_fqdn` | `true` | Keep full FQDNs in hostnames (local and received) instead of truncating to the short name. |
| `rsyslog_remote_host` | `""` | Remote syslog server FQDN or IP. Leave empty to skip forwarding. |
| `rsyslog_remote_port` | `514` | Remote syslog port. |
| `rsyslog_remote_protocol` | `tcp` | `tcp` or `udp`. TCP is preferred for reliable delivery. |
| `rsyslog_remote_zip_level` | `0` | `omfwd` `ZipLevel` (0 = off, 1–9 = compress forwarded traffic). |
| `rsyslog_receiver_enable` | `false` | Accept incoming syslog from other hosts (log server role). |
| `rsyslog_receiver_tcp_port` | `514` | TCP listen port when receiver is enabled. |
| `rsyslog_receiver_udp_port` | `514` | UDP listen port when receiver is enabled. |


Role Variables — advanced (multi-port / multi-target)
-------------------------------------------------------

### `rsyslog_listeners`

One entry per input. Binds to a named ruleset (see below) or, if `ruleset`
is omitted, falls through to rsyslog's default ruleset.

| Field | Default | Description |
|---|---|---|
| `address` | *(all interfaces)* | Bind address. Omit to listen on all interfaces. |
| `port` | — required | Listen port. |
| `protocol` | — required | `udp` or `tcp`. |
| `ruleset` | *(default ruleset)* | Named ruleset from `rsyslog_rulesets` to route into. |

```yaml
rsyslog_listeners:
  - address: 192.0.2.10
    port: 514
    protocol: udp
    ruleset: Unix
  - address: 192.0.2.10
    port: 1518
    protocol: tcp
    ruleset: Windows
```

### `rsyslog_rulesets`

Each ruleset routes messages to one or more destinations — a local dynamic
file, a forward action, or both.

| Field | Default | Description |
|---|---|---|
| `name` | — required | Ruleset name, no spaces. |
| `exclusive` | `false` | `false`: every destination fires independently, each optionally gated by its own `when`. `true`: destinations form an if/elif/…/else chain — first match wins. A destination with no `when` is the else/default branch and **must be listed last**. |
| `queue` | *(unset)* | Optional dict enabling a disk-spooled queue on this ruleset — see below. Omit for no queue. |
| `destinations` | — required | List of destination dicts — see below. |

`queue` fields (all optional):

| Field | Default | Description |
|---|---|---|
| `spool_directory` | `/var/spool/rsyslog` | Must exist and be writable by the rsyslog user; the role does not create it. |
| `filename` | ruleset name | Queue file base name. |
| `max_disk_space` | `1g` | Disk cap for spooled messages. |
| `type` | `LinkedList` | rsyslog queue type. |
| `save_on_shutdown` | `true` | Persist in-flight queue across restarts. |

`destinations` fields:

| Field | Applies to | Default | Description |
|---|---|---|---|
| `when` | any | *(unconditional)* | Rainerscript condition string, e.g. `'$hostname contains "web"'` or `'prifilt("authpriv.*")'`. Omit for unconditional (or the else branch when `exclusive: true`). |
| `type` | any | — required | `file` or `forward`. |
| `name` | `file` | `<ruleset>_dest<N>` | Name for the generated `template()` (shows up in the rendered config, e.g. `dynaFile="secure"`). Give two destinations the same `name` to have them share one `template()` declaration and write to the same dynamic file — e.g. routing both `uucp.crit` and `news.crit` to the same spooler log. |
| `path` | `file` | — required | Dynamic file path using rsyslog property-replacer syntax, e.g. `"/syslog/%HOSTNAME:::lowercase%-%$YEAR%%$MONTH%%$DAY%.log"`. |
| `dir_create_mode` | `file` | `0750` | |
| `file_create_mode` | `file` | `0640` | |
| `owner` / `group` | `file` | `root` / `root` | Applied to both the created directory and file. |
| `target` | `forward` | — required | Destination host/IP. |
| `port` | `forward` | `514` | |
| `protocol` | `forward` | `tcp` | `tcp` or `udp`. |
| `zip_level` | `forward` | `0` | `omfwd` `ZipLevel` (0 = off, 1–9 = compress). |

Example — category routing to local files (non-exclusive, every destination
fires):

```yaml
rsyslog_rulesets:
  - name: Security
    destinations:
      - type: file
        name: security_log
        path: "/syslog/security/%HOSTNAME:::lowercase%-%$YEAR%%$MONTH%%$DAY%.log"
```

Example — mutually-exclusive routing by facility, one file per message
(`exclusive: true`, if/elif/else chain):

```yaml
rsyslog_rulesets:
  - name: Unix
    exclusive: true
    destinations:
      - when: 'prifilt("authpriv.*")'
        type: file
        name: secure
        path: "/syslog/unix/%HOSTNAME:::lowercase%/secure-%$YEAR%%$MONTH%%$DAY%.log"
      - when: 'prifilt("mail.*")'
        type: file
        name: mail
        path: "/syslog/unix/%HOSTNAME:::lowercase%/mail-%$YEAR%%$MONTH%%$DAY%.log"
      - type: file    # else/default — no `when`, must be last
        name: messages
        path: "/syslog/unix/%HOSTNAME:::lowercase%/messages-%$YEAR%%$MONTH%%$DAY%.log"
```

Example — queue-spooled relay, routed by hostname, first match wins:

```yaml
rsyslog_rulesets:
  - name: Forwarding
    exclusive: true
    queue:
      spool_directory: /var/spool/rsyslog/relay
      max_disk_space: 5g
    destinations:
      - when: '$hostname contains "win"'
        type: forward
        target: 192.0.2.20
        port: 6514
        protocol: tcp
        zip_level: 9
      - type: forward   # default/else — no `when`, must be last
        target: 192.0.2.21
        port: 514
        protocol: tcp
```

### `rsyslog_file_inputs`

Tails a flat file (or glob) via `imfile` and injects it into the local
rsyslog pipeline — for services with no native syslog output. Resulting
messages flow through the same `rsyslog_rulesets`/`rsyslog_remote_host`
forwarding as everything else, tagged and faceted like any other message.

| Field | Default | Description |
|---|---|---|
| `path` | — required | File path or glob — `imfile` supports wildcards. |
| `tag` | — required | Becomes `%programname%` downstream — use this to route/name dynamic files by source. |
| `facility` | `local3` | `local0`–`local7`. |
| `severity` | `info` | Set precisely (e.g. `notice`) only when matching an existing exact-severity rule elsewhere in `rsyslog_rulesets`. |
| `ruleset` | *(default ruleset)* | Named ruleset from `rsyslog_rulesets` to route into. Omit for the default ruleset. |

```yaml
rsyslog_file_inputs:
  - path: /var/log/example/production.log
    tag: example-app
    facility: local4
```


Role Variables — log archive/rotation
---------------------------------------

Off by default. Only relevant on a receiver/aggregator host using
`rsyslog_rulesets`' dynamic file destinations (e.g. `/syslog/unix/...`) —
classic `/var/log/*` rotation is handled by the OS's own `logrotate` and is
untouched by this role.

When enabled, deploys a script that daily: gzips `*.log` files older than
`compress_after_days`, moves `*.gz` files older than `move_after_days` from
`source_dir` to `dest_dir` (mirroring the directory structure underneath),
then deletes archived `*.log.gz` files older than `delete_after_days` from
`dest_dir`. Runs via a root cron job at `cron_hour:cron_minute`.

| Variable | Default | Description |
|---|---|---|
| `rsyslog_log_archive_enable` | `false` | Deploy the script and its cron job. |
| `rsyslog_log_archive_source_dir` | `/syslog` | Directory tree scanned for `*.log` files — should match/contain the `path` values used in `rsyslog_rulesets`. |
| `rsyslog_log_archive_dest_dir` | `/archive` | Where compressed files land once they age past `move_after_days`. |
| `rsyslog_log_archive_compress_after_days` | `1` | `find -mtime` threshold for gzip compression. |
| `rsyslog_log_archive_move_after_days` | `4` | `find -mtime` threshold for moving to `dest_dir`. |
| `rsyslog_log_archive_delete_after_days` | `180` | `find -mtime` threshold for deletion from `dest_dir`. |
| `rsyslog_log_archive_script_path` | `/usr/local/sbin/logrotation.sh` | Where the script gets installed. |
| `rsyslog_log_archive_cron_hour` | `"0"` | Cron hour field. |
| `rsyslog_log_archive_cron_minute` | `"1"` | Cron minute field. |

Both `source_dir` and `dest_dir` must already exist/be mounted — the role
does not provision storage.

```yaml
rsyslog_log_archive_enable: true
# defaults otherwise match the retention policy above
```


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

Aggregator — multi-port category-based intake, local storage, and a
queue-spooled relay onward by hostname:

```yaml
- name: Configure syslog aggregator
  hosts: syslog_aggregators
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.rsyslog
      vars:
        rsyslog_listeners:
          - address: 192.0.2.10
            port: 514
            protocol: udp
            ruleset: Unix
          - address: 192.0.2.10
            port: 1518
            protocol: tcp
            ruleset: Windows
        rsyslog_rulesets:
          - name: Unix
            exclusive: true
            destinations:
              - when: 'prifilt("authpriv.*")'
                type: file
                name: secure
                path: "/syslog/unix/%HOSTNAME:::lowercase%/secure-%$YEAR%%$MONTH%%$DAY%.log"
              - type: file
                name: messages
                path: "/syslog/unix/%HOSTNAME:::lowercase%/messages-%$YEAR%%$MONTH%%$DAY%.log"
          - name: Windows
            destinations:
              - type: file
                name: windows_log
                path: "/syslog/windows/%HOSTNAME:::lowercase%/%HOSTNAME:::lowercase%-%$YEAR%%$MONTH%%$DAY%.log"
          - name: Forwarding
            exclusive: true
            queue:
              spool_directory: /var/spool/rsyslog/relay
              max_disk_space: 5g
            destinations:
              - when: '$hostname contains "win"'
                type: forward
                target: 192.0.2.20
                port: 6514
                protocol: tcp
                zip_level: 9
              - type: forward
                target: 192.0.2.21
                port: 514
                protocol: tcp
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
- **File-destination directories**: `dynaFile` paths under `rsyslog_rulesets`
  are created automatically by rsyslog (`createDirs="on"`), but the parent
  mount (e.g. `/syslog`) must already exist — this role doesn't provision
  storage.
- **Queue spool directory**: for `rsyslog_rulesets[].queue`, `spool_directory`
  must already exist and be writable by the rsyslog user (typically the
  `syslog` account) — the role does not create it.
- **Firewall**: when using `rsyslog_receiver_enable` or `rsyslog_listeners`,
  open the relevant ports (TCP and/or UDP) via `mgcdrd.infrabase.firewall`.
  rsyslog will not open ports automatically.
- **Ruleset ordering**: `20-rulesets.conf` deploys before `30-listeners.conf`
  (alphabetical `/etc/rsyslog.d/*.conf` load order), so ruleset names are
  always defined before `rsyslog_listeners` references them.
- **`exclusive` else branch**: when `exclusive: true`, at most one destination
  may omit `when`, and it must be the last entry in the list — it becomes the
  chain's `else` block.
- **`when` condition syntax**: message properties need the `$` prefix in
  RainerScript — `'$hostname contains "web"'`, not `'hostname contains
  "web"'` (the bare form is a parse error). `prifilt(...)` and other function
  calls don't take a `$`.
- **omfwd vs legacy syntax**: all forwarding uses the modern `omfwd` RainerScript
  action (rsyslog v7+). Both RHEL 9 and Debian 12 ship rsyslog v8, so this is
  safe.
- **Removing config**: clear the corresponding variable (`rsyslog_remote_host:
  ""`, `rsyslog_receiver_enable: false`, `rsyslog_rulesets: []`,
  `rsyslog_listeners: []`, `rsyslog_log_archive_enable: false`) and re-run to
  remove the matching drop-in file/script/cron job and restart rsyslog. The
  role is fully reversible.
