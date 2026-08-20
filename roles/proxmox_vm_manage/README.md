proxmox_vm_manage
==================

Orchestrator for post-provisioning changes on an existing ProxMox VM: add or
resize disks, add/update/remove NICs, and create/delete/roll back snapshots —
in a single role call, driven by one set of variables. Internally it fans out
to `proxmox_disk`, `proxmox_nic`, and `proxmox_snapshot`, which remain the
roles doing the actual work; this role just gives a deployment one variable
interface and one role entry instead of three.

Doesn't do anything `proxmox_disk`/`proxmox_nic`/`proxmox_snapshot` can't do
on their own — use those directly (as `deployments/foreman/site.yml` does)
when you only need one of the three, or need per-phase tags/`when` gating
finer than this role exposes.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.general` (for the disk sub-role) and `community.proxmox >= 2.0.0`
  (for the NIC/snapshot sub-roles) collections must be installed.
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller** — Python dependencies of both module families:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv
- If `proxmox_vm_manage_disks` is used: `become: true` and `gather_facts: true`
  on the play (the disk sub-role detects the new block device inside the VM).
  Not needed for NIC/snapshot-only runs — those are pure API calls.


Authentication
---------------

Two methods are supported for the NIC/snapshot sub-roles — set one pair,
leave the other unset:

```yaml
proxmox_vm_manage_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_vm_manage_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_vm_manage_api_user:     "root@pam"
proxmox_vm_manage_api_password: "{{ vault_proxmox_api_password }}"
```

The disk sub-role only supports password auth (`community.general`'s
`proxmox_disk`/`proxmox_vm_info` predate token support) — `proxmox_vm_manage_api_user`
and `_api_password` are always passed to it regardless of which method you
use for NICs/snapshots. If you're on token auth only, still set
`proxmox_vm_manage_api_password` (or leave disks unused).


Role Variables
---------------

### Connection (required)

```yaml
proxmox_vm_manage_api_host: "pve2.example.com"   # any PVE node or the cluster VIP
```

### VM targeting

```yaml
# Defaults to inventory_hostname — override if the VM name in PVE differs.
proxmox_vm_manage_vm_name: "{{ inventory_hostname }}"

# Set directly to skip the by-name lookup for NICs/snapshots. The disk
# sub-role always looks up by name — it has no VMID passthrough.
proxmox_vm_manage_vmid: ""
```

### Disks

```yaml
proxmox_vm_manage_disks:
  - slot: virtio1        # PVE disk slot — must not already be occupied for state=present
    storage: truenas      # PVE storage backend
    size: "400"           # GiB integer for state=present, "+XG" form for state=resized
    state: present          # present | resized
    resize_device: /dev/vdb  # resized only
    resize_vg: vg_data        # resized only
    resize_lvs:                # resized only
      - lv: lv_data
        size: 500G
        mount: /data
        fstype: xfs
```

One full `proxmox_disk` invocation (including its own by-name VM discovery)
runs per entry. See `mgcdrd.infrabase.proxmox_disk`'s README for the complete
key reference.

### NICs

```yaml
proxmox_vm_manage_nics:
  - interface: net1
    bridge: vmbr1
    tag: 100
    state: present   # present | absent
```

Passed straight through to `proxmox_nic_interfaces` — see
`mgcdrd.infrabase.proxmox_nic`'s README for the complete key reference
(`model`, `firewall`, `mtu`, `mac`).

### Snapshots

```yaml
proxmox_vm_manage_snapshots:
  - snapname: pre-updates
    state: present   # present | absent | rollback
    description: "Before OS updates"
    retention: 5
```

Passed straight through to `proxmox_snapshot_snapshots` — see
`mgcdrd.infrabase.proxmox_snapshot`'s README for the complete key reference
(`vmstate`, `force`, `unbind`). `snapname` has no safe default — always set
it explicitly.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_vm_manage` | Entire role |
| `storage` | Disk changes only |
| `network` | NIC changes only |
| `snapshot` | Snapshot changes only |


How it works
------------

Each section runs only if its list has entries — no separate on/off toggle,
populating the list is the opt-in:

1. **Disks** — loops over `proxmox_vm_manage_disks`, calling
   `mgcdrd.infrabase.proxmox_disk` once per entry via `include_role`.
2. **NICs** — calls `mgcdrd.infrabase.proxmox_nic` once, passing the whole
   `proxmox_vm_manage_nics` list through as `proxmox_nic_interfaces`.
3. **Snapshots** — calls `mgcdrd.infrabase.proxmox_snapshot` once, passing
   the whole `proxmox_vm_manage_snapshots` list through as
   `proxmox_snapshot_snapshots` (with `proxmox_snapshot_do_manage: true`
   forced on).


Example Playbook — add a disk, a NIC, and a pre-change snapshot
-----------------------------------------------------------------

```yaml
- name: Post-provision changes on an existing VM
  hosts: myhost
  gather_facts: true
  become: true
  roles:
    - role: mgcdrd.infrabase.proxmox_vm_manage
      vars:
        proxmox_vm_manage_api_host:         "pve2.example.com"
        proxmox_vm_manage_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_vm_manage_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_vm_manage_api_password:     "{{ vault_proxmox_api_password }}"
        proxmox_vm_manage_disks:
          - slot: virtio1
            storage: truenas
            size: "400"
            state: present
        proxmox_vm_manage_nics:
          - interface: net1
            bridge: vmbr1
            tag: 100
        proxmox_vm_manage_snapshots:
          - snapname: "pre-change-{{ ansible_date_time.date }}"
            description: "Before disk/NIC changes"
            retention: 5
```

Example Playbook — snapshot-only rollback
--------------------------------------------

```yaml
- name: Roll back a failed change
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_vm_manage
      vars:
        proxmox_vm_manage_api_host:         "pve2.example.com"
        proxmox_vm_manage_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_vm_manage_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_vm_manage_vm_name: "newhost01"
        proxmox_vm_manage_snapshots:
          - snapname: "pre-change-2026-08-19"
            state: rollback
```


Notes
-----

- **Not a replacement for the underlying roles**: this role exists for
  callers that want one entry point over all three. `deployments/foreman/site.yml`
  calls `proxmox_disk` and `proxmox_nic` directly, per-phase, with its own
  `when:` gates — that pattern is still correct when you need finer control
  than "run if the list is non-empty."
- **No `proxmox_vm` (clone/lifecycle/template) coverage**: this role is for
  changes *after* a VM exists. Cloning/creating a VM is
  `mgcdrd.infrabase.proxmox_vm`.
- **`hosts:` target**: the disk section needs to run against the VM's own
  inventory entry (`become`/`gather_facts` for on-guest block device
  detection); the NIC/snapshot sections are pure API calls that
  `delegate_to: localhost` internally regardless of the play's `hosts:` — so
  a single play targeting the VM works for all three sections. If you're only
  using NICs/snapshots, `hosts: localhost` works too (matching those
  sub-roles' own examples), as long as `proxmox_vm_manage_vm_name` is set
  explicitly (there's no VM inventory entry to default it from).
- **N disk entries = N discovery calls**: `proxmox_disk` looks up the VM by
  name on every invocation — a limitation of that role, not this one. If
  you're adding many disks to the same VM in one run, this means repeated API
  round trips.
