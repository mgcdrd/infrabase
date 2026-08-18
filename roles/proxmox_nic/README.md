proxmox_nic
===========

Adds, updates, or removes VM network interfaces (`net0`–`net31`) via the PVE
API using `community.proxmox.proxmox_nic`. Complements
`mgcdrd.infrabase.proxmox_vm`, which only sets `net0` once, at clone time —
this role owns every NIC change after that: additional interfaces, VLAN/
bridge/model changes on an existing NIC, and deletion.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.0.0`) — same module family
  as `proxmox_vm`, not the deprecated `community.general` proxmox modules
  `proxmox_disk` still uses.
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller** — Python dependencies of every `community.proxmox` module:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset
(same pattern as `proxmox_vm`):

```yaml
# API token (recommended — scoped, revocable without touching root's password)
proxmox_nic_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_nic_api_token_secret: "{{ vault_proxmox_api_token_secret }}"

# Password
proxmox_nic_api_user:     "root@pam"
proxmox_nic_api_password: "{{ vault_proxmox_api_password }}"
```

A token needs at least `VM.Config.Network` on the relevant path.


Role Variables
---------------

### Connection (required)

```yaml
proxmox_nic_api_host: "pve2.example.com"   # any PVE node or the cluster VIP
```

### VM targeting

```yaml
# Defaults to inventory_hostname — override if the VM name in PVE differs.
proxmox_nic_vm_name: "{{ inventory_hostname }}"

# Set directly to skip the by-name lookup entirely — useful right after
# proxmox_vm's clone task, when the VMID is already known.
proxmox_nic_vmid: ""
```

Name-based lookup fails if zero or multiple VMs share that name — the same
discovery pattern `proxmox_vm`/`proxmox_disk` use, so ambiguous names surface
as a clear error instead of silently acting on the wrong VM.

### NIC configuration

```yaml
proxmox_nic_interfaces:
  - interface: net1
    bridge: vmbr1
    model: virtio        # e1000 | rtl8139 | virtio (default) | ...
    tag: 100              # VLAN tag
    firewall: false
    mtu: ""               # virtio only; PVE ignores it on other models
    mac: ""               # "" lets PVE generate one / keeps the existing one
    state: present         # present | absent

  - interface: net2
    state: absent
```

One list entry per interface slot — a single role run can add, update, and
delete several NICs on the same VM in one pass. `net0` is normally owned by
`proxmox_vm`'s `proxmox_vm_net0` at clone time; only list `net0` here if you
need to change it after the VM already exists.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_nic` | Entire role |
| `network` | Entire role (alias) |


How it works
------------

1. `discover.yml` — calls `proxmox_vm_info` with the VM name, extracts the
   VMID. Skipped if `proxmox_nic_vmid` is already set.
2. `nic.yml` — loops over `proxmox_nic_interfaces`, calling `proxmox_nic`
   once per entry with `state: present` (create or update) or
   `state: absent` (delete).

`check_mode` is fully supported by the underlying module — unlike
`proxmox_disk` and `proxmox_network`, `--check` runs report what would
change without making any API calls that modify state.


Example Playbook — add a NIC to an existing VM
------------------------------------------------

```yaml
- name: Add a second NIC
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_nic
      vars:
        proxmox_nic_api_host:         "pve2.example.com"
        proxmox_nic_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_nic_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_nic_vm_name: "newhost01"
        proxmox_nic_interfaces:
          - interface: net1
            bridge: vmbr1
            tag: 100
```

Example Playbook — chained right after a proxmox_vm clone
-------------------------------------------------------------

```yaml
- name: Provision VM and attach a second NIC
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_vm
      vars:
        proxmox_vm_do_clone: true
        proxmox_vm_clone_source: "rocky9-template"
        proxmox_vm_name: "newhost01"
        proxmox_vm_node: "pve2"
        proxmox_vm_storage: "truenas"

    - role: mgcdrd.infrabase.proxmox_nic
      vars:
        proxmox_nic_api_host:         "pve2.example.com"
        proxmox_nic_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_nic_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        # proxmox_vm_clone_result.newid or the module's returned facts can be
        # used here instead of a name lookup if the caller wants to avoid the
        # extra API round trip.
        proxmox_nic_vm_name: "newhost01"
        proxmox_nic_interfaces:
          - interface: net1
            bridge: vmbr1
            tag: 100
```

Example Playbook — remove a NIC
-----------------------------------

```yaml
- name: Remove a decommissioned NIC
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_nic
      vars:
        proxmox_nic_api_host:         "pve2.example.com"
        proxmox_nic_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_nic_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_nic_vm_name: "newhost01"
        proxmox_nic_interfaces:
          - interface: net1
            state: absent
```


Notes
-----

- **No handlers**: every module call is idempotent against PVE's own state;
  nothing needs restarting on the controller side.
- **`delegate_to: localhost`**: every task in this role talks to the PVE API,
  not the inventory host — meant to be run with `hosts: localhost`, but
  tasks delegate explicitly anyway so it also works from a play targeting
  other hosts.
- **VMID uniqueness**: as with `proxmox_vm`/`proxmox_disk`, if multiple VMs
  share a name across PVE nodes, discovery fails rather than guess. Set
  `proxmox_nic_vmid` directly to bypass the lookup.
- **`net0` ownership**: kept with `proxmox_vm` by convention (clone-time
  `proxmox_vm_net0`) so a VM's primary interface is always defined in one
  place. Nothing stops this role from managing `net0` post-creation if a
  later change is needed.
- **MTU**: only honored for `model: virtio`; PVE silently ignores it on other
  NIC models.
