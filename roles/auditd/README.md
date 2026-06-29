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
| `auditd_privileged_exec` | Paths audited with `perm=x` |
| `auditd_privileged_access` | Paths audited for privileged access (no perm filter) |
| `auditd_watches` | File/dir watchpoints (`-w`), list of `{file, perm, key}` |


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
  skipped if `audit=1` is already present in the default kernel args. Debian
  manages this via GRUB configuration separately.
- Rule paths that don't exist on the target (e.g. SELinux paths on Debian)
  are silently ignored by auditd.
- The role uses `ansible_userspace_bits` to correctly emit b32/b64 rules.
- The base ruleset sets `-e 2` (immutable mode) — audit config cannot be
  changed without a reboot once rules are loaded.
