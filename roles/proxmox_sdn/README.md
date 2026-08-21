proxmox_sdn
============

Manages ProxMox VE's Software-Defined Networking layer — zones, vnets, and
subnets — via the PVE REST API. Builds on top of the physical interfaces
managed by `mgcdrd.infrabase.proxmox_network` (e.g. a `vlan`-type SDN zone
references an existing bridge such as `vmbr0`).

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.
Lock/rollback behavior differs on PVE 9+ vs PVE 8 — see Notes.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 1.4.0` — the SDN modules
  were added in that release).
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

Unset `vault_*` variables resolve to `omit`. Grant the token `SDN.Allocate`
(and `SDN.Audit` for read-only use) at the `/sdn` path.


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
| `proxmox_sdn_do_info` | `false` | `info` | List zones and vnets |
| `proxmox_sdn_do_zone` | `false` | `zone` | Create/update/delete SDN zones |
| `proxmox_sdn_do_vnet` | `false` | `vnet` | Create/update/delete SDN vnets |
| `proxmox_sdn_do_subnet` | `false` | `subnet` | Create/update/delete SDN subnets |

Unlike `proxmox_network`, **there is no separate apply step** — each
zone/vnet/subnet task stages *and* applies its change internally (PVE 9+
uses a lock/apply/rollback-on-failure sequence; PVE 8 does a plain apply and
blocks until the reload task completes, with no rollback on failure — see
Notes). Run `zone` before `vnet` before `subnet` if creating a full stack in
one play; a vnet referencing a not-yet-created zone will fail.

### info

No variables required. Sets facts:

| Fact | Source |
|---|---|
| `proxmox_sdn_zone_facts` | `community.proxmox.proxmox_zone_info` |
| `proxmox_sdn_vnet_facts` | `community.proxmox.proxmox_vnet_info` |

There is no `proxmox_subnet_info` module upstream — subnets aren't listable
through this role; check PVE's UI or `pvesh get /cluster/sdn/subnets`
directly if you need to audit them.

### zone

```yaml
proxmox_sdn_zones:
  - zone: lab
    type: vlan          # simple | vlan | qinq | vxlan | evpn
    bridge: vmbr0        # required for type: vlan
    state: present

  - zone: labvx
    type: vxlan
    fabric: my_fabric    # fabric OR peers required for type: vxlan
```

`type` is **immutable** once a zone exists — the module fails rather than
changing it in place; delete and recreate to change a zone's type. Full
field list (all optional except `zone`/`type`): `bridge` (vlan), `tag` +
`vlan_protocol` (qinq), `fabric`/`peers` (vxlan), `controller` + `vrf_vxlan`
(evpn), plus `mtu`, `dhcp`, `dns`, `dnszone`, `reversedns`, `ipam`, `mac`,
`nodes`, `exitnodes`, `exitnodes_local_routing`, `exitnodes_primary`,
`advertise_subnets`, `disable_arp_nd_suppression`, `rt_import`, `dp_id`,
`bridge_disable_mac_learning`, `vxlan_port`.

### vnet

```yaml
proxmox_sdn_vnets:
  - vnet: labnet
    zone: lab
    tag: 100
    vlanaware: true
```

Fields: `vnet`, `zone` (required), `alias`, `tag`, `vlanaware`,
`isolate_ports`, `delete` (comma-separated list of settings to unset).

### subnet

```yaml
proxmox_sdn_subnets:
  - subnet: "10.10.2.0/24"
    vnet: labnet
    zone: lab
    gateway: "10.10.2.1"
    snat: true
    dhcp_range:
      - start: "10.10.2.10"
        end: "10.10.2.200"
    dhcp_range_update_mode: append   # append | overwrite
```

Fields: `subnet`, `vnet`, `zone` (all required — `zone` is required by the
module even for `state: absent`), `gateway`, `snat`, `dhcp_dns_server`,
`dhcp_range` (list of `{start, end}`), `dhcp_range_update_mode`,
`dnszoneprefix`, `delete`.

`dhcp_range_update_mode: append` (the module default) merges new ranges
with existing ones and fails on partial overlap; if you omit `dhcp_range` on
an update, existing ranges are left alone. `overwrite` replaces all existing
ranges with the ones you provide; omitting `dhcp_range` on an update with
`overwrite` **deletes all existing DHCP ranges**.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_sdn` | Entire role |
| `info` | List zones/vnets |
| `zone` | Manage zones |
| `vnet` | Manage vnets |
| `subnet` | Manage subnets |


Example Playbook — zone, vnet, and subnet in one pass
----------------------------------------------------------

```yaml
- name: Configure SDN for the lab VLAN
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_sdn
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_sdn_do_zone: true
        proxmox_sdn_do_vnet: true
        proxmox_sdn_do_subnet: true
        proxmox_sdn_zones:
          - zone: lab
            type: vlan
            bridge: vmbr0
        proxmox_sdn_vnets:
          - vnet: labnet
            zone: lab
            tag: 100
        proxmox_sdn_subnets:
          - subnet: "10.10.2.0/24"
            vnet: labnet
            zone: lab
            gateway: "10.10.2.1"
            snat: true
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **`--check` is not supported**: all three modules declare `check_mode`/
  `diff_mode` support as `none`.
- **PVE 9+ vs PVE 8 behavior** (auto-detected per-task via the cluster's own
  `/version`): PVE 9+ acquires a global SDN lock before each change, applies,
  and releases it — on failure it rolls back automatically via
  `/cluster/sdn/rollback`. PVE 8 has no lock/rollback endpoints; the module
  does a plain apply and blocks on task completion, but a failure mid-way
  through a zone→vnet→subnet sequence leaves earlier, already-applied
  changes in place (no all-or-nothing guarantee).
- **No handlers**: every module call is idempotent against PVE's own state.
