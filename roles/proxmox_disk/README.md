proxmox_disk
============

Adds or resizes a disk on a ProxMox VM via the PVE API, then detects the
resulting block device inside the VM. Sets a `proxmox_disk_device` host fact
(e.g. `/dev/vdb`) that downstream roles such as `lvm2_provision` can consume
without any hardcoded device paths.

The VM is located by name — VMID and node are discovered automatically from the
PVE API, so neither needs to be known in advance.

Tested on: Rocky Linux 9 (target VM); any Ansible controller


Requirements
------------

- `gather_facts: true` and `become: true` are required on the target host
  (needed for block device detection).
- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.general` collection must be installed (provides `proxmox_vm_info`
  and `proxmox_disk` modules).
- **`proxmoxer >= 2.3` must be installed on the Ansible controller** — it is a
  Python dependency of the `community.general` ProxMox modules. Install it with:
  - Debian/Ubuntu: `apt install python3-proxmoxer` (verify version — use pip if too old)
  - RPM / pip: `pip3 install 'proxmoxer>=2.3'`
- For `proxmox_disk_state: resized`, the disk must already be a PV in an LVM
  VG managed on the host. Set `proxmox_disk_resize_device`,
  `proxmox_disk_resize_vg`, and `proxmox_disk_resize_lvs`.


Role Variables
--------------

### Required

```yaml
proxmox_disk_api_host:     "pve2.example.com"   # any PVE node
proxmox_disk_api_password: "{{ vault_lookup }}"
proxmox_disk_storage:      "truenas"             # PVE storage backend name
```

### VM targeting

```yaml
# Defaults to inventory_hostname — override if the VM name in PVE differs.
proxmox_disk_vm_name: "{{ inventory_hostname }}"
```

### Disk configuration

```yaml
proxmox_disk_slot: virtio1    # PVE disk slot — must not already be occupied for 'present'
proxmox_disk_size: "400G"
proxmox_disk_state: present   # present | resized
proxmox_disk_api_user: "root@pam"
```

### Resize-only variables

Only needed when `proxmox_disk_state: resized`:

```yaml
proxmox_disk_resize_device: /dev/vdb     # block device to pvresize
proxmox_disk_resize_vg: vg_foreman       # VG containing the LVs to extend
proxmox_disk_resize_lvs:                 # LVs to extend and grow filesystem on
  - lv: lv_pulp
    size: 500G
    mount: /var/lib/pulp
    fstype: xfs
```

### Output fact

After the role runs, the following host fact is set:

```yaml
proxmox_disk_device: /dev/vdb    # path to the newly added block device
```

For `resized`, no new device fact is set (the device already exists).


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_disk` | Entire role |
| `storage` | Entire role (alias) |


How it works
------------

**Add (`present`):**

1. `discover.yml` — calls `proxmox_vm_info` with the VM name, extracts VMID
   and node. Fails if zero or multiple VMs match.
2. `snapshot.yml` — records the current list of disk-type block devices inside
   the VM via `lsblk`.
3. `add.yml` — calls `proxmox_disk` to add the disk on the PVE side, then
   triggers a PCI bus rescan inside the VM (`/sys/bus/pci/rescan`) and waits
   up to 15 seconds for a new device to appear.
4. `detect.yml` — diffs before/after device lists to identify the new device
   and sets `proxmox_disk_device`.

**Resize (`resized`):**

1. `discover.yml` — same as above.
2. `snapshot.yml` — same as above.
3. `resize.yml` — calls `proxmox_disk` with `state: resized`, triggers rescan,
   runs `pvresize` on the device, `lvextend` on each LV, and `xfs_growfs` for
   XFS volumes (online, no unmount required).


Example Playbook — add disk and set up LVM
------------------------------------------

```yaml
- name: Add data disk via ProxMox
  hosts: myhost
  gather_facts: true
  become: true
  roles:
    - role: mgcdrd.infrabase.proxmox_disk
      vars:
        proxmox_disk_api_host: "pve2.example.com"
        proxmox_disk_api_password: "{{ vault_pve_password }}"
        proxmox_disk_vm_name: "{{ inventory_hostname | split('.') | first }}"
        proxmox_disk_slot: virtio1
        proxmox_disk_storage: truenas
        proxmox_disk_size: "400G"
        proxmox_disk_state: present

- name: Set up LVM on new disk
  hosts: myhost
  gather_facts: false
  become: true
  vars:
    lvm_provision_vgs:
      - vg: vg_data
        pvs:
          - "{{ proxmox_disk_device }}"
    lvm_provision_volumes:
      - lv: lv_data
        vg: vg_data
        size: 380G
        fstype: xfs
        mount: /data
  roles:
    - role: mgcdrd.infrabase.lvm2_provision
```

Example Playbook — resize existing disk
---------------------------------------

```yaml
- name: Expand Pulp volume
  hosts: foreman
  gather_facts: true
  become: true
  roles:
    - role: mgcdrd.infrabase.proxmox_disk
      vars:
        proxmox_disk_api_host: "pve2.example.com"
        proxmox_disk_api_password: "{{ vault_pve_password }}"
        proxmox_disk_slot: virtio1
        proxmox_disk_storage: truenas
        proxmox_disk_size: "600G"
        proxmox_disk_state: resized
        proxmox_disk_resize_device: /dev/vdb
        proxmox_disk_resize_vg: vg_foreman
        proxmox_disk_resize_lvs:
          - lv: lv_pulp
            size: 480G
            mount: /var/lib/pulp
            fstype: xfs
```


Notes
-----

- **PCI rescan**: The role writes `1` to `/sys/bus/pci/rescan` to hot-notify
  the kernel of the new device. This works reliably for virtio and SCSI disks
  under QEMU/KVM. If the device does not appear within 15 seconds, check the
  PVE console to confirm the disk was attached.
- **Disk slot**: PVE disk slots are bus-prefixed (e.g. `virtio0`, `scsi1`,
  `sata2`). The detected `/dev/` path depends on the bus type:
  `virtio` → `/dev/vdX`, `scsi`/`sata` → `/dev/sdX`.
- **VMID uniqueness**: If multiple VMs share the same name across PVE nodes,
  the role fails. Set `proxmox_disk_vm_name` to a more specific string or
  resolve the naming conflict in PVE.
- **XFS resize**: XFS filesystems can be grown online while mounted.
  Shrinking is not supported by XFS or this role.


License
-------

GPL-3.0-or-later
