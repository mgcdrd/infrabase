proxmox_network
================

Manages node-level physical network configuration in ProxMox VE — bridges,
bonds, VLANs, and Open vSwitch interfaces — via the PVE REST API. Distinct
from `mgcdrd.infrabase.proxmox_sdn`, which manages PVE's Software-Defined
Networking layer (zones/vnets/subnets) on top of this physical layer.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 1.4.0` — `proxmox_node_network`
  and `proxmox_node_network_info` were added in that release).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset:

```yaml
proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_api_user:     "root@pam"
proxmox_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. Grant the token `Sys.Modify` on
`/nodes/<node>` at minimum.


Role Variables
---------------

### Connection

Every `proxmox_*` role in this collection uses the same `proxmox_api_*`
vars — see `collections/infrabase/README.md`. Set them once for the whole
play/inventory; a VM/CT lives on one node in one cluster, so there's
nothing role-specific to override here.

```yaml
proxmox_api_host: "pve2.example.com"
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_network_do_info` | `false` | `info` | Read interfaces, or check pending changes |
| `proxmox_network_do_iface` | `false` | `iface` | Create/modify/delete interfaces (staged, not live) |
| `proxmox_network_do_apply` | `false` | `apply` | Push staged changes live |

**Changing an interface never takes effect on its own.** `iface` writes to
`/etc/network/interfaces.new` on the node; a separate `apply` run against
the same node is required to make it live. Run both in the same play, or as
two clearly separated plays if you want a review window in between.

### info

```yaml
proxmox_network_info_node:          "pve2"   # required
proxmox_network_info_iface:         ""       # "" = all interfaces
proxmox_network_info_iface_type:    ""       # "" = all types; bridge|bond|eth|vlan|OVSBridge|OVSBond|OVSPort|OVSIntPort
proxmox_network_info_check_changes: false    # true = report pending/staged diff instead of live config
```

Sets `proxmox_network_facts` (list of interface dicts) when
`check_changes: false`, or `proxmox_network_pending_facts` (with
`has_pending_changes` bool and a unified-diff `pending_changes` string) when
`check_changes: true`.

### iface

```yaml
proxmox_network_node: "pve2"   # default node for every item below

proxmox_network_interfaces:
  - iface: vmbr0
    iface_type: bridge
    state: present
    cidr: "192.168.1.10/24"
    gateway: "192.168.1.1"
    bridge_ports: "eth0"
    bridge_vlan_aware: true
    autostart: true

  - iface: bond0
    iface_type: bond
    bond_mode: active-backup
    bond_primary: eth0
    slaves: "eth0 eth1"
    cidr: "10.10.10.5/24"
```

Each item mirrors `community.proxmox.proxmox_node_network`'s parameters —
only `iface` is required per item; everything else is `omit`ted when unset.
Set a per-item `node` key to target a different node than
`proxmox_network_node` within the same run (useful for provisioning matching
bonds/bridges across every node in a cluster in one pass).

| Field | Applies to | Notes |
|---|---|---|
| `iface_type` | all | `bridge`,`bond`,`eth`,`vlan`,`OVSBridge`,`OVSBond`,`OVSIntPort`. **Immutable after creation** — delete and recreate to change it. |
| `cidr`, `gateway`, `cidr6`, `gateway6` | eth, bridge, bond, vlan, OVSBridge, OVSIntPort | Set to `""` to delete an existing value |
| `autostart` | eth, bridge, bond, vlan, OVSBridge | |
| `comments`, `mtu` | all | `mtu`: 1280–65520; `""`/`-1` deletes |
| `bridge_ports`, `bridge_vids`, `bridge_vlan_aware` | bridge only | `bridge_vids` needs `bridge_vlan_aware: true` |
| `bond_mode`, `bond_primary`, `bond_xmit_hash_policy`, `slaves` | bond only | `bond_primary` required for `active-backup`; `bond_xmit_hash_policy` required for `balance-xor`/`802.3ad`; `slaves` is space-separated |
| `vlan_raw_device` | vlan only | Required only when `iface` is named `vlanXY` — omit when using `parent_iface.vlan_id` naming |
| `ovs_ports`, `ovs_options` | OVSBridge, OVSBond, OVSIntPort | |
| `ovs_bonds` | OVSBond only | Space-separated |
| `ovs_bridge`, `ovs_tag` | OVSBond, OVSIntPort | `ovs_bridge` required for those types |

### apply

```yaml
proxmox_network_apply_node: "pve2"   # required
```

Checks for pending changes first and only applies if any exist — safe to run
unconditionally after `iface`.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_network` | Entire role |
| `info` | Read interfaces / pending changes |
| `iface` | Create/modify/delete (staged) |
| `apply` | Push staged changes live |


Example Playbook — create a bridge and bond, then apply
-----------------------------------------------------------

```yaml
- name: Configure node networking
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_network
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_network_do_iface: true
        proxmox_network_do_apply: true
        proxmox_network_node: "pve2"
        proxmox_network_apply_node: "pve2"
        proxmox_network_interfaces:
          - iface: bond0
            iface_type: bond
            bond_mode: active-backup
            bond_primary: eth0
            slaves: "eth0 eth1"
          - iface: vmbr0
            iface_type: bridge
            bridge_ports: bond0
            bridge_vlan_aware: true
            cidr: "10.0.0.5/24"
            gateway: "10.0.0.1"
            autostart: true
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **`--check` is not supported** by the underlying modules (`community.proxmox.
  proxmox_node_network` declares `diff_mode`/`check_mode` support as `none`).
  A `--check` run against this role will not simulate network changes.
- **No rollback on apply failure**: if `apply` fails partway (e.g. a bad
  `gateway` makes the node unreachable), PVE does not automatically revert —
  use `state: revert` in a follow-up run (not currently exposed as a gated
  section here; call the module directly if you need it) to discard staged
  changes before they're applied, or fix and re-`apply`.
- **No handlers**: every module call is idempotent against PVE's own state.
