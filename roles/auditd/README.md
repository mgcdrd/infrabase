auditd
======

Installs and configures auditd with CIS-aligned audit rules. Manages
`auditd.conf`, the base ruleset, and the loginuid immutability rule. All
syscall groups, watchpoints, and conf settings are variable-driven so callers
can extend or narrow coverage without forking the role.

On RedHat family hosts, also enables the audit kernel parameter at boot via
`grubby` (idempotent — skipped if the args are already present).

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts: true` is required (uses
`ansible_facts['os_family']` and `ansible_userspace_bits`).


Role Variables
--------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `auditd_local_events` | `"yes"` | No | `local_events` in auditd.conf: record events from the local system |
| `auditd_log_format` | `"ENRICHED"` | No | `log_format`: `ENRICHED` or `RAW` |
| `auditd_name_format` | `"hostname"` | No | `name_format`: how this host is identified in logs |
| `auditd_max_log_file_action` | `"keep_logs"` | No | Action when a log reaches its maximum size |
| `auditd_space_left` | `"25"` | No | MB free before `auditd_space_left_action` fires |
| `auditd_space_left_action` | `"email"` | No | Action when the `space_left` threshold is hit |
| `auditd_action_mail_acct` | `"root"` | No | Mail recipient for space alerts |
| `auditd_admin_space_left` | `"12"` | No | MB free before `auditd_admin_space_left_action` fires |
| `auditd_admin_space_left_action` | `"halt"` | No | Action when the `admin_space_left` threshold is hit |
| `auditd_disk_full_action` | `"single"` | No | Action when the audit volume is full |
| `auditd_disk_error_action` | `"syslog"` | No | Action on an audit disk error |
| `auditd_overflow_action` | `"syslog"` | No | Action on audit queue overflow |
| `auditd_time_syscalls` | *(list, 3 items)* | No | Syscalls audited for time changes (CIS 4.1.3.3) |
| `auditd_network_syscalls` | *(list, 2 items)* | No | Syscalls audited for network config changes (CIS 4.1.3.4) |
| `auditd_perm_mod` | *(list, 10 items)* | No | Syscalls audited for permission changes, present on all architectures (CIS 4.1.3.5) |
| `auditd_perm_mod_x86_only` | *(list, 3 items)* | No | Permission-change syscalls that exist only on x86_64 (chmod/chown/lchown) |
| `auditd_perm_mod_root` | *(list, 6 items)* | No | Permission-change syscalls audited for root-owned actions |
| `auditd_file_access_x86_only` | *(list, 2 items)* | No | Unsuccessful file-access syscalls that exist only on x86_64 (CIS 4.1.3.6) |
| `auditd_file_access` | *(list, 4 items)* | No | Unsuccessful file-access syscalls for all architectures |
| `auditd_file_delete_x86_only` | *(list, 3 items)* | No | File-deletion syscalls that exist only on x86_64 (CIS 4.1.3.9) |
| `auditd_file_delete` | *(list, 2 items)* | No | File-deletion syscalls for all architectures |
| `auditd_kernel_module_x86_only` | *(list, 2 items)* | No | Kernel-module syscalls that exist only on x86_64 (CIS 4.1.3.15) |
| `auditd_kernel_module_syscalls` | *(list, 3 items)* | No | Kernel-module syscalls for all architectures |
| `auditd_mount_syscalls` | *(list, 1 items)* | No | Mount/export syscalls (CIS 4.1.3.12/14) |
| `auditd_privileged_commands_extra` | *(list, 5 items)* | No | Extra privileged command paths audited on top of the setuid/setgid binaries found at play time (CIS 4.1.3.13) |
| `auditd_watches` | *(map, 28 lines)* | No | Watchpoints (path, permissions, key) for CIS 4.1.3.2/4/7/10/11/16 |
| `auditd_watches_redhat` | *(list, 6 items)* | No | Additional watchpoints applied on RedHat-family hosts only |
| `auditd_watches_debian` | *(list, 2 items)* | No | Additional watchpoints applied on Debian-family hosts only |


### Audit rule groups

Each variable is a list that drives a section of `auditd.rules.j2`. Override
to add or remove entries.

Network config and kernel module syscall rules include `-F auid>=1000 -F
auid!=unset` — CIS's automated check requires the filter to be present, not
just the syscall.

### Privileged commands (CIS 4.1.3.13)

Rather than a static path list (which drifts as packages change), `configure.yml`
discovers setuid/setgid binaries at play time: it rejects mounts with
`noexec`/`nosuid` (nothing there can execute as setuid anyway) and `/proc`,
then runs `find <mount> -xdev -perm /6000 -type f` on what's left. The result
is unioned with `auditd_privileged_commands_extra` and deduplicated. This
mirrors the CIS/SSG remediation's own discovery method exactly.

`auditd_privileged_commands_extra` defaults to `chacl`, `setfacl`, `chcon`,
`kmod`, `usermod` — these five have their own dedicated CIS rules
(`audit_rules_execution_*`, `audit_rules_privileged_commands_kmod`/`_usermod`)
that require the audit rule unconditionally, regardless of whether the binary
is actually setuid/setgid on this particular host. Discovery alone isn't
enough for these five.


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Harden audit subsystem
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.auditd
```

Extending watches:

```yaml
- name: Harden audit subsystem
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.auditd
      vars:
        auditd_watches: "{{ auditd_watches + extra_watches }}"
```


Notes
-----

- Rules changes (base rules, loginuid) trigger `augenrules --load` via handler.
  `auditd.conf` changes trigger a full daemon restart instead — `augenrules`
  does not reload daemon configuration.
- `augenrules --load` is available on both Debian and RedHat via the
  `auditd` / `audit` package.
- The `grubby` boot-time audit flag task only runs on RedHat family and is
  skipped if `audit=1` is already present in the default kernel args, or if
  `grubby` / a bootloader entry isn't present (some cloud/container images) —
  the check tolerates failure and the update is gated on it having succeeded.
  Debian manages this via GRUB configuration separately.
- Rule paths that don't exist on the target (e.g. SELinux paths on Debian)
  are silently ignored by auditd.
- The role uses `ansible_userspace_bits` to correctly emit b32/b64 rules.
- The base ruleset sets `-e 2` (immutable mode) — audit config cannot be
  changed without a reboot once rules are loaded.
