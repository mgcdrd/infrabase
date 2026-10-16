fail2ban
========

Installs fail2ban and manages its configuration from variables: jail defaults
(ignored networks, ban times with escalation, firewall action by OS family),
custom jails and filters, and ready-made presets. The `nginx` preset bans
rate-limit offenders, scanner probes and bursts of 4xx responses from the
per-server-block logs written by `mgcdrd.infrasvc.nginx`.

Tested on: Debian 12/13, Rocky Linux 9/10 (configuration validated with
`fail2ban-client -t` and `fail2ban-regex` on Rocky 9; live bans through the
firewall are not yet exercised)


Requirements
------------

`become: true` and `gather_facts: true` are required.

- **RedHat**: fail2ban comes from EPEL (or a Foreman content view that carries
  it). The package pulls in `fail2ban-firewalld`, which provides the
  `firewallcmd-ipset` ban action; firewalld must be running.
- **Debian**: installs `fail2ban`, `nftables` (ban action) and `python3-systemd`
  (for `backend = systemd`). If another role manages the nftables ruleset and
  flushes it, fail2ban's table is lost on that role's next run until fail2ban
  reloads.


Role Variables
--------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `fail2ban_ignoreip` | loopback + RFC1918 | No | Networks never banned; add trusted external ranges |
| `fail2ban_bantime` | `1h` | No | First ban length |
| `fail2ban_findtime` | `10m` | No | Window in which `maxretry` failures trigger a ban |
| `fail2ban_maxretry` | `5` | No | Failures before a ban |
| `fail2ban_bantime_increment` | `true` | No | Repeat offenders get longer bans |
| `fail2ban_bantime_factor` | `2` | No | Multiplier per repeat offence |
| `fail2ban_bantime_maxtime` | `4w` | No | Longest ban |
| `fail2ban_backend` | `auto` | No | Log backend; `systemd` reads the journal |
| `fail2ban_banaction` | `firewallcmd-ipset` (RedHat), `nftables` (Debian) | No | Default ban action |
| `fail2ban_banaction_allports` | per OS family | No | Ban action for jails that block all ports (`recidive`) |
| `fail2ban_presets` | `[]` | No | Preset jail/filter bundles to enable; available: `nginx` |
| `fail2ban_nginx_access_logpath` | `/var/log/nginx/*.access.log` | No | Access logs for the nginx preset |
| `fail2ban_nginx_error_logpath` | `/var/log/nginx/*error.log` | No | Error logs for the nginx preset (where rate-limit lines land) |
| `fail2ban_nginx_limit_req_maxretry` / `_findtime` | `100` / `1m` | No | `nginx-limit-req` jail thresholds |
| `fail2ban_nginx_probe_maxretry` / `_findtime` / `_bantime` | `2` / `10m` / `1d` | No | `nginx-probe` jail thresholds |
| `fail2ban_nginx_4xx_maxretry` / `_findtime` | `30` / `1m` | No | `nginx-4xx` jail thresholds |
| `fail2ban_recidive_enabled` | `false` | No | Ban repeat offenders across all jails for longer |
| `fail2ban_recidive_bantime` / `_findtime` / `_maxretry` | `4w` / `1d` / `3` | No | `recidive` thresholds |
| `fail2ban_jails` | `[]` | No | Custom jails (below) |
| `fail2ban_filters` | `[]` | No | Custom filters (below) |

### The nginx preset

| Jail | Filter | Reads | Bans |
|---|---|---|---|
| `nginx-limit-req` | stock fail2ban filter | nginx error logs | Clients that keep hitting `limit_req` (the 429s) |
| `nginx-probe` | `nginx-probe` (this role) | nginx access logs | Requests for scanner paths: `.env`, `.git`, `wp-login.php`, `xmlrpc.php`, `phpmyadmin`, `/cgi-bin/`, `../` and similar, at any status code |
| `nginx-4xx` | `nginx-4xx` (this role) | nginx access logs | Bursts of 400/403/405/444, which includes blocked user agents and geoblocked clients |

The filters match the `reverse_proxy` log format (starts with `$remote_addr`).
Behind a load balancer, set `nginx_real_ip_from` in the nginx role first; without it
fail2ban sees, and would ban, the balancer.

### Custom jails and filters

```yaml
fail2ban_jails:
  - name: myapp                 # required
    filter: myapp               # default: name
    logpath: /var/log/myapp/access.log
    port: http,https
    maxretry: 10
    findtime: 5m
    bantime: 1h
    enabled: true               # default true
    options:                    # extra key = value lines
      usedns: "no"              # quote yes/no so YAML doesn't turn them into booleans

fail2ban_filters:
  - name: myapp                 # required
    failregex:                  # list; one pattern per entry
      - '^<HOST> - \S+ \[\] "[A-Z]+ [^"]*" 401 '
    ignoreregex: []
```

fail2ban removes the log timestamp before matching a line. A pattern written
against `[15/Oct/2026:10:00:00 +0000]` must therefore use an empty `\[\]` where the
date was, not `\[[^\]]+\]`. Check new filters first:

    fail2ban-regex /path/to/log /etc/fail2ban/filter.d/myapp.conf


Dependencies
------------

None. Run it after the service whose logs it reads, since every `logpath` must
exist for the configuration test (`fail2ban-client -t`, run before the reload) to
pass.


Example Playbook
----------------

```yaml
- name: Ban abusive clients of the nginx proxy
  hosts: webproxy
  become: true
  roles:
    - role: mgcdrd.infrabase.fail2ban
      vars:
        fail2ban_presets: [nginx]
        fail2ban_recidive_enabled: true
        fail2ban_ignoreip:
          - 127.0.0.1/8
          - 10.0.0.0/8
          - 203.0.113.0/27     # trusted external range
```


Notes
-----

- Files written: `jail.d/00-ansible-defaults.local` (defaults),
  `jail.d/10-ansible-jails.local` (all jails), and `filter.d/<name>.conf` per
  filter. fail2ban reads `.local` files after `.conf`, so these override the
  packaged defaults, including `fail2ban-firewalld`'s own `banaction`.
- The recidive jail reads `/var/log/fail2ban.log`; the role creates it so the
  configuration test passes on a host where fail2ban has not run yet.
- A change reloads the service (`fail2ban-client reload`), which keeps current bans.
- IPv6 clients are banned per address, so an attacker with a /64 can rotate.
- Not covered: sshd and other packaged jails; enable those through `fail2ban_jails`
  (set `enabled: true` and any `logpath`/`backend` the distro needs) or drop-in files.


License
-------

GPL-3.0-or-later
