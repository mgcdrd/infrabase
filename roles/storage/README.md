storage
=======

Manages disks, LVM and mounts for a host from one variable structure:
partitions, PV/VG/LV create and extend, filesystems, fstab entries and mount
options, swap, and removal of mounts that are no longer defined. It replaces
`lvm2` and `lvm2_provision`, and takes over mount options from `secure_mounts`.

The role is built around the layouts used at build time (kickstart, preseed,
Foreman partition tables). Pick one with `storage_scheme`, then describe only
what differs on this host.

Tested on: not yet run against a live host. Targets Debian 12/13 and Rocky Linux 9/10.


Requirements
------------

- `community.general` and `ansible.posix` collections
- `gather_facts: true` and `become: true`


Role variables
--------------

| Variable | Default | Description |
|---|---|---|
| `storage_scheme` | `""` | Build-time layout to start from: `std`, `base-lvm`, `ext-lvm`, `foreman-el-uefi`, or empty |
| `storage_vg` | `""` | VG for mounts that set `lv` without `vg`. Empty: the VG of the root mount, then the profile's VG |
| `storage_disks` | `[]` | Disks to partition or add to a VG |
| `storage_vgs` | `[]` | Extra VG settings (`pesize`) or PVs not described by `storage_disks` |
| `storage_mounts` | `[]` | Mounts, merged over the profile by `path` |
| `storage_disks_extra_<suffix>` | unset | Extra disk layers, any number. Merged over `storage_disks` by `device`, in variable-name order |
| `storage_mounts_extra_<suffix>` | unset | Extra mount layers, any number. Merged over `storage_mounts` by `path`, in variable-name order |
| `storage_default_fstype` | `xfs` (RedHat), `ext4` (Debian) | Used when a new mount sets no `fstype` |
| `storage_default_opts` | `defaults` | Used when a mount has no `opts` and no existing fstab line |
| `storage_default_modes` | `/tmp`, `/var/tmp`: `1777` | Mode applied to a mount point after mounting |
| `storage_prune` | `false` | Unmount and comment out every disk/network fstab entry that is not defined |
| `storage_prune_exclude` | `[]` | Extra paths that pruning never touches |
| `storage_protected_paths` | `/ /boot /boot/efi /usr /var` | Never pruned, never set to `absent` |

### Mount entries

```yaml
storage_mounts:
  - path: /var/lib/pgsql        # absolute mount point, or "swap"
    lv: lv_pgsql                # LV-backed: created if missing
    vg: vg_data                 # optional, see storage_vg
    size: 30G                   # a minimum, never shrinks; 100%FREE allowed at creation
    fstype: xfs                 # xfs or ext4
    opts: noatime
    mode: "0750"                # also owner, group
    threshold: 85               # extend by extend_by when usage % >= threshold
    extend_by: 10G
    shadow: false               # true: allow mounting over a non-empty directory
  - path: /srv/share            # any other source: NFS, a device, tmpfs
    src: nfs.example.com:/export/share
    fstype: nfs4
    opts: _netdev,nofail
  - path: /boot                 # no lv/src: adopt the existing mount, set only what you give
    opts: nosuid
  - path: swap
    state: absent               # swapoff, comment out of fstab
```

How an entry is read:

- With `lv`, the device is `/dev/mapper/<vg>-<lv>`. The LV is created when
  missing and extended when smaller than `size`. An LV that is already larger
  is left alone, so profile sizes (build-time minimums) never fight later growth.
- With `src`, the source is used as given.
- With neither, the mount is adopted: source, type and options come from the
  existing `/etc/fstab` line, and only keys you set are changed.
- Keep `100%FREE` for the last LV in a VG; it takes everything left.

### Filesystems

A filesystem is only created on a blank device. If a device already holds one,
it is kept and mounted as the type it has, with a warning when that differs from
`fstype`. Mounting over a directory that has files in it fails unless the entry
sets `shadow: true`.

### Layering with `_extra_<suffix>`

A host or group that sets `storage_mounts` replaces the list from a broader
group instead of adding to it, so a service-specific layout would drop the
base list (for example the CIS mount options set for all hosts). Put the
service's entries in `storage_mounts_extra_<suffix>` instead (and
`storage_disks_extra_<suffix>` for disks). Layers are read in variable-name
order; a later layer that names the same `path` (mounts) or `device` (disks)
overrides the earlier entry key by key, and `state: absent` in a later layer
removes it. Disk `device` strings must match exactly to merge, so use by-id
paths in every layer.

```yaml
# group_vars/all: base hardening mounts
storage_mounts:
  - {path: /tmp, opts: "nodev,nosuid,noexec"}
# host_vars/foreman: the service's own LVs, added to the base
storage_disks_extra_foreman:
  - {device: /dev/disk/by-id/virtio-data01, vg: vg_foreman}
storage_mounts_extra_foreman:
  - {path: /var/lib/pulp, lv: lv_pulp, vg: vg_foreman, size: 100G}
```

### Disks

```yaml
storage_disks:
  - device: /dev/disk/by-id/virtio-data01     # prefer by-id paths
    partitions:
      - number: 1
        flags: [lvm]
        vg: vg_data                           # this partition becomes a PV in vg_data
  - device: /dev/sda                          # root disk grown by the hypervisor
    partitions:
      - number: 3
        grow: true                            # grow into free space, then pvresize
        vg: vg0
```

A partition table is only written to a disk that has no signature at all. The
label of an existing table is always kept. A disk with no partitions and `vg`
set is used whole as a PV. PVs are added to VGs and existing PVs are never
removed. A device that already belongs to a different VG stops the run.

### Boot firmware

UEFI is detected from `/sys/firmware/efi`. A UEFI host must define `/boot/efi`
(profiles mark it `efi_only`); a legacy BIOS host must not. The role validates
and mounts boot partitions but never creates or removes them.

### Removing mounts

- An entry with `state: absent` is unmounted and its fstab line commented out,
  always.
- With `storage_prune: true`, every disk or network fstab entry that is not
  defined is treated the same way. It is off by default because other roles
  also manage mounts.
- Commented lines read `# disabled by storage role: <original line>`. Data is
  never touched, and LVs, VGs and partitions are never deleted by this role.
- A busy mount stops the run and shows what holds it. Protected paths are left
  alone.
- Swap: leave it out and set `storage_prune`, or use `- { path: swap, state: absent }`.
  Kubernetes nodes need this.

### Profiles

| `storage_scheme` | Source | Layout |
|---|---|---|
| `std` | auto.packer | `/boot`, swap, `/` as plain partitions; everything adopted |
| `base-lvm` | auto.packer | `vGroup_01`: `/`, `/home`, `/tmp`, `/usr`, `/var`, swap (ext4) |
| `ext-lvm` | auto.packer | `base-lvm` plus `/opt`, `/usr/local`, `/var/log`, `/var/log/audit` |
| `foreman-el-uefi` | Foreman `EL Single Disk UEFI` | `vg0`, xfs, `lv_*` names, CIS mount options |

Hosts built differently override per entry, for example the older `vg_00`
naming or the rpiblades' `vg0-tmp` style: set `storage_vg` and give each
entry its own `lv`.


Example
-------

```yaml
- hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.storage
      vars:
        storage_scheme: foreman-el-uefi
        storage_disks:
          - device: /dev/disk/by-id/virtio-data01
            partitions: [{ number: 1, flags: [lvm], vg: vg_app }]
        storage_mounts:
          - { path: /var/lib/app, lv: lv_app, vg: vg_app, size: 200G, fstype: xfs, opts: noatime }
          - { path: swap, state: absent }
```
