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

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `sshd_manage_package` | `true` | No | Install openssh-server; set false if it is already installed |
| `sshd_port` | `22` | No | Port sshd listens on |
| `sshd_address_family` | `any` | No | `inet`, `inet6`, or `any` |
| `sshd_listen_addresses` | `[]` | No | empty = listen on all interfaces |
| `sshd_permit_root_login` | `"no"` | No | `PermitRootLogin` policy |
| `sshd_max_auth_tries` | `4` | No | `MaxAuthTries`: authentication attempts per connection |
| `sshd_max_sessions` | `10` | No | `MaxSessions`: multiplexed sessions per connection |
| `sshd_pubkey_authentication` | `"yes"` | No | `PubkeyAuthentication` |
| `sshd_authorized_keys_file` | `".ssh/authorized_keys"` | No | `AuthorizedKeysFile` path |
| `sshd_authorized_keys_command` | `""` | No | `AuthorizedKeysCommand` lookup program (e.g. for LDAP-backed keys); empty disables |
| `sshd_authorized_keys_command_user` | `"nobody"` | No | User the lookup command runs as; only written when `sshd_authorized_keys_command` is set |
| `sshd_password_authentication` | `"no"` | No | `PasswordAuthentication` |
| `sshd_permit_empty_passwords` | `"no"` | No | `PermitEmptyPasswords` |
| `sshd_use_pam` | `"yes"` | No | `UsePAM` |
| `sshd_allow_users` | `[]` | No | `AllowUsers`; empty means no restriction |
| `sshd_allow_groups` | `[]` | No | `AllowGroups`; empty means no restriction |
| `sshd_deny_users` | `[]` | No | `DenyUsers` |
| `sshd_deny_groups` | `[]` | No | `DenyGroups` |
| `sshd_<allow\|deny>_<users\|groups>_extra_<suffix>` | not set | No | Entries added to the matching base list without replacing it; one variable per group or host layer (see **Layering**) |
| `sshd_login_grace_time` | `60` | No | `LoginGraceTime`: seconds to authenticate before disconnect |
| `sshd_client_alive_interval` | `300` | No | `ClientAliveInterval` in seconds |
| `sshd_client_alive_count_max` | `1` | No | `ClientAliveCountMax`; the CIS profile requires 1 |
| `sshd_log_level` | `"VERBOSE"` | No | `LogLevel` |
| `sshd_allow_tcp_forwarding` | `"no"` | No | `AllowTcpForwarding` |
| `sshd_allow_agent_forwarding` | `"no"` | No | `AllowAgentForwarding` |
| `sshd_allow_stream_local_forwarding` | `"no"` | No | `AllowStreamLocalForwarding` |
| `sshd_x11_forwarding` | `"no"` | No | `X11Forwarding` |
| `sshd_print_motd` | `"no"` | No | `PrintMotd` |
| `sshd_max_startups` | `"10:30:60"` | No | `MaxStartups` (start:rate:full) for unauthenticated connections |
| `sshd_banner` | `""` | No | Path to a pre-auth banner file; empty disables |
| `sshd_match_blocks` | `[]` | No | Conditional `Match` blocks appended to `sshd_config` (fields below) |
| `sshd_match_blocks_extra_<suffix>` | not set | No | `Match` blocks appended after the base blocks, in variable-name order |
| `sshd_scrub_directives` | *(list, 1 items)* | No | Directives removed from other `sshd_config.d/*.conf` drop-ins so CIS text-search checks see only this role's values |
| `sshd_ciphers` | *(AES-GCM and AES-CTR; see defaults)* | No | `Ciphers` list |
| `sshd_kex_algorithms` | *(curve25519, DH group14/16; see defaults)* | No | `KexAlgorithms` list |
| `sshd_macs` | *(hmac-sha2 etm and non-etm; see defaults)* | No | `MACs` list |

### Layering: base lists plus custom sets

To add to a list without restating it, set `sshd_<allow|deny>_<users|groups>_extra_<suffix>` or
`sshd_match_blocks_extra_<suffix>`, with a different suffix per group or host (Ansible replaces a
list when two levels set the same name, but leaves differently named variables alone). The role
unions the base and every extra, in variable-name order.

```yaml
# group_vars/k8smasters.yml
sshd_allow_groups_extra_k8smasters: [kube-admins]

# host_vars/kube1.example.com.yml: adds to the group's list
sshd_allow_groups_extra_host: [backup-ops]
```

An allow list switches the restriction on, so the first extra entry makes `AllowUsers` or
`AllowGroups` take effect where the base list was empty. Setting a base variable itself still
replaces it, as before.


### Access control

On IPA-enrolled hosts, access control is normally left to IPA HBAC rather
than `sshd_allow_groups` — see the CIS-Rocky9-ScanFindings wiki page for the
accepted-risk rationale on `sshd_limit_user_access`.

### Session

When `sshd_allow_tcp_forwarding`, `sshd_allow_agent_forwarding`,
`sshd_allow_stream_local_forwarding`, and `sshd_x11_forwarding` are all `no`,
the template also emits the consolidated `DisableForwarding yes` — CIS's
automated check looks for that literal directive, not the granular ones. Set
any one of the granular vars to `yes` and `DisableForwarding` is dropped
automatically (it would otherwise override them).

### Drop-in scrubbing

CIS's automated check for some `sshd` settings does a naive text search
across `sshd_config.d/*.conf` rather than resolving effective
(first-obtained-value-wins) config — a drop-in this role doesn't own (RPM
package defaults, `ipa-client-install`) can still trip the check even though
it has no runtime effect. Add a directive name here if a future CIS finding
turns out to be the same class of false positive.

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
- If setting `sshd_authorized_keys_command`, the target binary must be owned
  by root, not writable by group or other, and not itself a symlink or in a
  group/world-writable directory — sshd refuses to start otherwise. On an
  IPA-enrolled host, leave `sshd_authorized_keys_command` unset and let
  `ipa-client-install`'s drop-in supply it instead.
