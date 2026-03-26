lvm2
====

A role to safely extend existing LVM logical volumes and volume groups on Debian
and RedHat family systems.

Supports two use cases:
- **Configuration-time** — extend LVs to a defined absolute size or by a fixed amount as
  part of system provisioning
- **Monitoring-driven** — extend LVs automatically when filesystem usage crosses a
  configurable threshold, safe to run on a schedule with no side effects when disk is healthy

The role only extends existing volumes — it does not create LVs, VGs, or filesystems.
All operations are validated before execution: VG free space, LV existence, and
anti-shrink guards are checked and will fail fast with a clear message rather than
letting the underlying tools produce cryptic errors.

Tested on: Debian 12/13, Rocky Linux 9/10

Requirements
------------

Role uses `community.general.lvol` and `community.general.lvg` and requires the
`community.general` collection.

`gather_facts: true` is required as LVM and mount facts are used for pre-flight
validation and threshold checks.

`become: true` is required as LVM operations need root privileges.


Role Variables
--------------

```yaml
# Override the auto-detected OS volume group.
# The role detects this from the root mount device at runtime.
# Set explicitly if auto-detection fails or you are targeting a non-OS VG.
lvm_os_vg: ""

# ---- LOGICAL VOLUME OPERATIONS ----

# Logical volumes to extend. Role only extends existing LVs — it does not create them.
lvm_volumes: []
# lvm_volumes:
#   - lv: lv_home                   # LV name (required)
#     vg: vg_os                     # VG name (optional — defaults to detected OS VG)
#     size: 50G                     # Absolute target size (50G) or amount to add (+10G)
#     resizefs: true                # Resize the filesystem after extending (default: true)
#     shrink: false                 # Allow shrinking — must be explicitly true (default: false)
#     threshold: 85                 # Only extend when filesystem usage % is >= this value.
#     mount: /home                  # Mount point for threshold check (required with threshold).

# ---- VOLUME GROUP OPERATIONS ----

# Volume groups to extend by adding new physical volumes.
# Use this to bring a newly attached disk into an existing VG before extending LVs.
lvm_vg_extensions: []
# lvm_vg_extensions:
#   - vg: vg_data                   # VG to extend (required)
#     pvs:                          # Block devices to add as PVs (required)
#       - /dev/sdb
#       - /dev/sdc
```


Safety Checks
-------------

The following are validated before any action is taken:

- LVM facts are present on the host (LVM is configured)
- All `lvm_volumes` entries have `lv` and `size` defined
- Entries using `threshold` also define `mount`
- Target VG exists for each volume
- Target LV exists in the expected VG (role does not create LVs)
- VG has sufficient free space for the requested extension
- Absolute sizes are not smaller than the current LV size (anti-shrink guard unless `shrink: true`)
- PV block devices exist and are not already claimed by a different VG


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

Make sure to set `gather_facts: true` and `become: true` as LVM operations require
facts and root privileges.

**Extend a logical volume to an absolute size:**

```yaml
- name: Extend LVM volumes
  hosts: all
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.lvm2

# group_vars or host_vars:
lvm_volumes:
  - lv: lv_home
    size: 50G
```

**Extend a logical volume by a fixed amount:**

```yaml
lvm_volumes:
  - lv: lv_var
    size: +20G
```

**Threshold-based extension — safe for monitoring/scheduled runs:**

```yaml
lvm_volumes:
  - lv: lv_home
    mount: /home
    size: +10G
    threshold: 85   # only extend if /home usage is >= 85%
```

When usage is below the threshold the task is skipped cleanly with a debug message —
no changes are made. This makes the role safe to run from a monitoring system or cron
job without additional logic.

**Extend a volume on a non-OS VG:**

```yaml
lvm_volumes:
  - lv: lv_data
    vg: vg_data
    size: +50G
```

**Add a new disk to a VG, then extend an LV into the new space:**

```yaml
lvm_vg_extensions:
  - vg: vg_data
    pvs:
      - /dev/sdb

lvm_volumes:
  - lv: lv_data
    vg: vg_data
    size: +100G
```

VG extension runs first, facts are refreshed, then the LV is extended into the
newly available space — all in a single play.

**Multiple volumes with mixed threshold and explicit extension:**

```yaml
lvm_volumes:
  # Always extend lv_var by 5G (e.g. during provisioning)
  - lv: lv_var
    size: +5G

  # Only extend lv_home if usage exceeds 80% (monitoring use case)
  - lv: lv_home
    mount: /home
    size: +10G
    threshold: 80

  # Only extend lv_opt if usage exceeds 90%
  - lv: lv_opt
    mount: /opt
    size: +10G
    threshold: 90
```


License
-------

GPL-3.0-or-later
