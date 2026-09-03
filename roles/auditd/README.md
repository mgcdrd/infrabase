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

### auditd.conf settings

| Variable | Default | Description |
|---|---|---|
| `auditd_local_events` | `yes` | Record events from local system |
| `auditd_log_format` | `ENRICHED` | Log format (ENRICHED or RAW) |
| `auditd_name_format` | `hostname` | How to identify this host in logs |
| `auditd_max_log_file_action` | `keep_logs` | Action when log reaches max size |
| `auditd_space_left` | `25` | MB remaining before space_left_action fires |
| `auditd_space_left_action` | `email` | Action when space_left threshold is hit |
| `auditd_action_mail_acct` | `root` | Email recipient for space alerts |
| `auditd_admin_space_left` | `12` | MB remaining before admin action fires |
| `auditd_admin_space_left_action` | `halt` | Action when admin_space_left is hit |
| `auditd_disk_full_action` | `single` | Action when disk is full |
| `auditd_disk_error_action` | `syslog` | Action on disk error |
| `auditd_overflow_action` | `syslog` | Action on audit queue overflow |

### Audit rule groups

Each variable is a list that drives a section of `auditd.rules.j2`. Override
to add or remove entries.

| Variable | Description |
|---|---|
| `auditd_perm_mod` | Syscalls audited for permission/ownership modification |
| `auditd_perm_mod_root` | Subset of perm_mod also audited for auid=0 |
| `auditd_file_delete` | Syscalls audited for file deletion |
| `auditd_file_access` | Syscalls audited for failed file access (EACCES/EPERM) |
| `auditd_kernel_module_syscalls` | Syscalls audited for module load/unload |
| `auditd_mount_syscalls` | Syscalls audited for mount/export |
| `auditd_time_syscalls` | Syscalls audited for time changes (list of `{name, key}`) |
| `auditd_privileged_commands_extra` | Extra paths unioned into the discovered setuid/setgid binary list |
| `auditd_watches` | File/dir watchpoints (`-w`), list of `{file, perm, key}` |

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
