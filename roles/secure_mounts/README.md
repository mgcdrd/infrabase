secure_mounts
=============

Applies security-hardened mount options (`nodev`, `noexec`, `nosuid`) to a
configurable list of mount points. Defaults to hardening `/dev/shm`.

Uses `ansible.posix.mount` with `state: mounted` — options are applied
immediately and persisted to `/etc/fstab`.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.

The `ansible.posix` collection must be installed (included in `ansible-base-ee`).


Role Variables
--------------

### `secure_mounts_list`

List of mount points to configure. Each entry requires:

| Key | Required | Description |
|-----|----------|-------------|
| `path` | yes | Mount point path |
| `opts` | yes | Mount options string |
| `src` | no | Device or source (e.g. `none` for tmpfs) |
| `fstype` | no | Filesystem type (e.g. `tmpfs`) |

`src` and `fstype` are passed through only when the entry does not already
exist in `/etc/fstab`. When updating an existing fstab entry, only `opts` is
changed.

Default:

```yaml
secure_mounts_list:
  - path:   /dev/shm
    src:    none
    fstype: tmpfs
    opts:   nodev,noexec,nosuid
```


Dependencies
------------

- `ansible.posix.mount`


Example Playbook
----------------

```yaml
- name: Harden mount points
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.secure_mounts
```

Additional mounts (e.g. /tmp on its own partition):

```yaml
- name: Harden mount points
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.secure_mounts
      vars:
        secure_mounts_list:
          - path:   /dev/shm
            src:    none
            fstype: tmpfs
            opts:   nodev,noexec,nosuid
          - path:   /tmp
            opts:   nodev,noexec,nosuid
```


Notes
-----

- `state: mounted` remounts with the new options immediately and writes to
  `/etc/fstab`. The mount persists across reboots.
- If `/tmp` is bind-mounted from another partition, include the full fstab
  entry (`src`, `fstype`) to avoid a mount failure.
- Do not add `noexec` to `/var` or `/usr` — package managers and scripts
  require execute permission there.
