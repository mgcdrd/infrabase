hardened_services
=================

Hardens system service configuration and misc CIS filesystem/permission
controls that don't warrant their own role, each independently toggleable:

| Feature | Default | What it does |
|---------|---------|--------------|
| `hardened_services_disable_nfs` | `true` | Disables and masks the NFS server service |
| `hardened_services_emergency_auth` | `true` | Requires sulogin for emergency/rescue systemd targets |
| `hardened_services_chronyd_user` | `true` | Ensures chronyd runs as an unprivileged user |
| `hardened_services_disable_bluetooth` / `_autofs` / `_rpcbind` | `true` | Disables and masks unused services, if present |
| `hardened_services_fix_grub_user_cfg` | `true` | Locks down GRUB password file permissions (RedHat) |
| `hardened_services_fix_unowned_files` | `false` | Chowns orphaned files on local filesystems to `root:root` |

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. Facts (`gather_facts: true`) are required for
OS-family branching (chronyd task).


Role Variables
--------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `hardened_services_disable_nfs` | `true` | No | Disable and mask the NFS server service |
| `hardened_services_emergency_auth` | `true` | No | Require sulogin authentication for emergency and rescue systemd targets via drop-in overrides in /etc/systemd/system/{emergency,rescue}.service.d/ |
| `hardened_services_chronyd_user` | `true` | No | Ensure chronyd runs as an unprivileged user (chrony on RedHat, _chrony on Debian) |
| `hardened_services_disable_bluetooth` | `true` | No | Disable and mask unused services |
| `hardened_services_disable_autofs` | `true` | No | Disable and mask `autofs.service` if present. |
| `hardened_services_disable_rpcbind` | `true` | No | Disable and mask `rpcbind.service` **and** `rpcbind.socket`. Set to `false` on NFSv3 client/server hosts — rpcbind is required for portmapper lookups. |
| `hardened_services_fix_grub_user_cfg` | `true` | No | chmod 0600 /boot/grub2/user.cfg (GRUB password file) |
| `hardened_services_fix_unowned_files` | `false` | No | Scan real (non-pseudo) local filesystems for files with no owning user or group and chown them to root:root |
| `hardened_services_local_fstypes` | *(list, 4 items)* | No | Local filesystem types to include in the unowned-file scan above |


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Harden system services
  hosts: all
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.hardened_services
```

NFS server hosts — disable everything except NFS:

```yaml
- name: Harden system services
  hosts: nfs_servers
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.hardened_services
      vars:
        hardened_services_disable_nfs: false
```

Hosts without chrony installed:

```yaml
- name: Harden system services
  hosts: containers
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.hardened_services
      vars:
        hardened_services_chronyd_user: false
```


Notes
-----

- **NFS**: Uses `failed_when: false` — if the NFS server package is not
  installed, the task is silently skipped rather than failing.
- **Emergency/rescue targets**: Uses systemd drop-ins under
  `/etc/systemd/system/{emergency,rescue}.service.d/override.conf` rather than
  modifying vendor unit files. A `daemon-reload` is triggered on change.
  The `ExecStart=` blank line is required to clear the inherited value before
  setting the new one.
- **Chronyd**: Uses `failed_when: false` — if the chrony config file is absent
  (not installed), the task is silently skipped. The Debian user is `_chrony`;
  the RedHat user is `chrony`.
