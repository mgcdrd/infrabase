sshd
====

Installs openssh-server, deploys a hardened `sshd_config`, and manages a
crypto drop-in under `sshd_config.d/`. All security-relevant settings have
hardened defaults that can be overridden per host or group.

Handles OS differences between Debian and RedHat families:

| Detail | Debian | RedHat |
|---|---|---|
| Service name | `ssh` | `sshd` |
| Host key group | `ssh` | `ssh_keys` |
| sftp-server path | `/usr/lib/openssh/sftp-server` | `/usr/libexec/openssh/sftp-server` |
| `/etc/sysconfig/sshd` | not present | `CRYPTO_POLICY` override removed |

The `sshd_config` is validated with `sshd -t` before being placed — a
syntax error will fail the task without touching the running config.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts: true` is required (used to select
service name, key group, and sftp path).


Role Variables
--------------

### Connection

| Variable | Default | Description |
|---|---|---|
| `sshd_port` | `22` | Port sshd listens on |
| `sshd_address_family` | `any` | `inet`, `inet6`, or `any` |
| `sshd_listen_addresses` | `[]` | Explicit listen addresses; empty = all |

### Authentication

| Variable | Default | Description |
|---|---|---|
| `sshd_permit_root_login` | `no` | Root login policy |
| `sshd_max_auth_tries` | `4` | Max authentication attempts per connection |
| `sshd_max_sessions` | `10` | Max multiplexed sessions per connection |
| `sshd_pubkey_authentication` | `yes` | Enable public key auth |
| `sshd_authorized_keys_file` | `.ssh/authorized_keys` | AuthorizedKeysFile path |
| `sshd_password_authentication` | `no` | Enable password auth |
| `sshd_permit_empty_passwords` | `no` | Permit empty passwords |
| `sshd_use_pam` | `yes` | Enable PAM |

### Access control

| Variable | Default | Description |
|---|---|---|
| `sshd_allow_users` | `[]` | Whitelist of users; empty = no restriction |
| `sshd_allow_groups` | `[]` | Whitelist of groups; empty = no restriction |
| `sshd_deny_users` | `[]` | Blacklist of users |
| `sshd_deny_groups` | `[]` | Blacklist of groups |

On IPA-enrolled hosts, access control is normally left to IPA HBAC rather
than `sshd_allow_groups` — see the CIS-Rocky9-ScanFindings wiki page for the
accepted-risk rationale on `sshd_limit_user_access`.

### Session

| Variable | Default | Description |
|---|---|---|
| `sshd_login_grace_time` | `60` | Seconds to complete auth before disconnect |
| `sshd_client_alive_interval` | `300` | Keepalive interval in seconds |
| `sshd_client_alive_count_max` | `3` | Keepalives before disconnect |
| `sshd_allow_tcp_forwarding` | `no` | TCP port forwarding |
| `sshd_allow_agent_forwarding` | `no` | SSH agent forwarding |
| `sshd_x11_forwarding` | `no` | X11 forwarding |
| `sshd_print_motd` | `no` | Print MOTD on login |
| `sshd_banner` | `""` | Path to banner file; empty = no banner |

### Match blocks

```yaml
sshd_match_blocks:
  - type: Group
    targets: [wheel]
    options:
      - AuthenticationMethods publickey
  - type: User
    targets: [deploy]
    options:
      - ForceCommand /usr/local/bin/deploy-hook
```

### Crypto

| Variable | Default | Description |
|---|---|---|
| `sshd_ciphers` | `aes256-gcm@…,aes128-gcm@…,aes256-ctr,…` | Ciphers list |
| `sshd_kex_algorithms` | `curve25519-sha256,…` | Key exchange algorithms |
| `sshd_macs` | `hmac-sha2-512-etm@…,…` | Message authentication codes |

Written to `/etc/ssh/sshd_config.d/00-crypto.conf`. Override to match your
site policy or compliance requirement.


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Configure sshd
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.sshd
```

Key-only auth with group restriction:

```yaml
- name: Configure sshd
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.sshd
      vars:
        sshd_allow_groups: [sshusers, wheel]
        sshd_password_authentication: "no"
```


Notes
-----

- `sshd -t` validation runs before the config is placed. A bad template or
  variable value will fail the task rather than restart sshd with a broken
  config.
- Host key permission tasks use `failed_when: false` — if a key type is not
  present on the host (e.g. no RSA key), the task skips without failing.
- The `CRYPTO_POLICY` removal task only runs on RedHat family. On Debian this
  file does not exist.
- The crypto drop-in is written to `00-crypto.conf` so it loads first among
  drop-ins and can be overridden by higher-numbered ones if needed.
- `Include /etc/ssh/sshd_config.d/*.conf` is placed at the *end* of the
  managed config, not the top. `sshd_config` uses first-obtained-value-wins,
  so this keeps every directive above authoritative even when a drop-in
  outside Ansible's control (RPM package defaults, `ipa-client-install`,
  Anaconda) sets the same key. Drop-ins still supply anything this file
  doesn't set (e.g. IPA's `AuthorizedKeysCommand`).
- On RedHat family, the Anaconda-generated
  `/etc/ssh/sshd_config.d/01-permitrootlogin.conf` is removed — it exists
  only to let root log in during/after kickstart and has no purpose once
  this role manages the host.
