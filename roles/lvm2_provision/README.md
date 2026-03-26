lvm2_provision
==============

A role for provisioning LVM storage at system setup time. Creates volume groups,
logical volumes, filesystems, and mounts them persistently via fstab.

Designed to run **once at provisioning**. For ongoing volume management (extending
LVs, threshold-based automation), use `mgcdrd.infrabase.lvm2` after provisioning
is complete.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

Role uses `community.general.lvg`, `community.general.lvol`, and
`community.general.filesystem` and requires the `community.general` collection.

`gather_facts: true` is required as OS family facts are used for package installation.

`become: true` is required as LVM operations need root privileges.


Role Variables
--------------

```yaml
# Volume groups to create.
lvm_provision_vgs: []
# lvm_provision_vgs:
#   - vg: vg_data                   # VG name (required)
#     pvs:                          # Block devices to use as PVs (required)
#       - /dev/sdb
#       - /dev/sdc
#     pesize: "4"                   # PE size in MiB (optional, default: 4)

# Logical volumes to create.
lvm_provision_volumes: []
# lvm_provision_volumes:
#   - lv: lv_data                   # LV name (required)
#     vg: vg_data                   # VG name (required)
#     size: 100G                    # LV size (required)
#     fstype: ext4                  # Filesystem type (optional, default: ext4)
#     mount: /data                  # Mount point (optional — if set, formats + mounts + adds fstab entry)
#     mount_opts: defaults          # fstab mount options (optional, default: defaults)
```


Safety Checks
-------------

The following are validated before any action is taken:

- All `lvm_provision_vgs` entries have `vg` and `pvs` defined
- All `lvm_provision_volumes` entries have `lv`, `vg`, and `size` defined
- PV block devices exist and are block devices
- PV devices are not already claimed by a different VG
- A warning is emitted when `mount` is defined without an explicit `fstype`

All operations use `state: present` and are idempotent — safe to re-run if
provisioning is interrupted or repeated.


Dependencies
------------

Requires the `community.general` collection:

```yaml
# requirements.yml
collections:
  - name: community.general
```


Example Playbook
----------------

Make sure to set `gather_facts: true` and `become: true`.

**Create a VG from two disks, provision two LVs with different filesystems:**

```yaml
- name: Provision LVM storage
  hosts: all
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.lvm2_provision

# group_vars or host_vars:
lvm_provision_vgs:
  - vg: vg_data
    pvs:
      - /dev/sdb
      - /dev/sdc

lvm_provision_volumes:
  - lv: lv_data
    vg: vg_data
    size: 200G
    fstype: ext4
    mount: /data

  - lv: lv_backup
    vg: vg_data
    size: 100G
    fstype: xfs
    mount: /backup
    mount_opts: defaults,noatime
```

**Create an LV on an existing VG without mounting:**

```yaml
lvm_provision_volumes:
  - lv: lv_scratch
    vg: vg_existing
    size: 50G
```

**Full provisioning workflow — provision storage, then hand off to lvm2 for ongoing management:**

```yaml
- name: Provision base storage
  hosts: all
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.lvm2_provision

- name: Ongoing LV management
  hosts: all
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.lvm2
```


License
-------

GPL-3.0-or-later
