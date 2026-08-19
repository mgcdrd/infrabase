network_interfaces
===================

Configures Linux host network interfaces — physical NICs, LACP bonds, and
802.1q VLAN subinterfaces — through NetworkManager (`nmcli`), driven by a
single `network_interfaces` list.

Debian defaults to `ifupdown`, not NetworkManager, so on Debian this role
installs `network-manager`, sets `[ifupdown] managed=true` in
`/etc/NetworkManager/NetworkManager.conf` so NM will take over interfaces
even if something is still referencing them from `/etc/network/interfaces`,
and enables the service. Rocky already runs NetworkManager by default — the
role just ensures the package is present and the service is running. From
there, interface configuration itself is one shared `nmcli`-based task path
for all four OS targets — no OS-family branching in `configure.yml`.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` and `gather_facts: true` are required.

`community.general` collection must be installed (included in
`ansible-base-ee`) — provides the `nmcli` and `ini_file` modules.


Role Variables
--------------

### `network_interfaces`

List of interface definitions. Empty by default — see
`defaults/main.yml` for the full per-type key reference and a worked
bond + VLAN example. Default `[]` is deliberate: guessing a host's
physical device names (`eth0` vs `eno1` vs `ens192`) is a good way to
misconfigure the NIC carrying the current SSH session, so this must be
declared explicitly per host, never assumed.

| Key (all types) | Required | Description |
|---|---|---|
| `name` | yes | nmcli connection name |
| `type` | yes | `physical`, `bond`, or `vlan` |
| `state` | no | `present` or `absent`. Default: `present` |
| `autoconnect` | no | Start on boot. Default: `true` |
| `method4` | no | `manual`, `auto`, or `disabled`. Default: `manual` |
| `ip4` | no | List of IPv4 CIDRs |
| `gw4` | no | IPv4 gateway |
| `dns4` | no | List of IPv4 DNS servers |
| `mtu` | no | Interface MTU |

| Key (`type: physical`) | Required | Description |
|---|---|---|
| `device` | no | Kernel interface name. Defaults to `name` |

| Key (`type: bond`) | Required | Description |
|---|---|---|
| `device` | no | Bond interface name. Defaults to `name` |
| `bond_mode` | no | Default: `802.3ad` (LACP) |
| `bond_miimon` | no | MII link monitor interval, ms. Default: `100` |
| `bond_members` | yes | List of physical device names to enslave |

| Key (`type: vlan`) | Required | Description |
|---|---|---|
| `vlan_id` | yes | 802.1q VLAN ID (0-4095) |
| `vlan_parent` | yes | Parent's device name — a `physical` or `bond` entry's `device` |

`bond_members` entries each become their own nmcli slave connection
(`<bond name>-slave-<device>`) — don't also declare them as separate
`type: physical` entries; a bonded NIC carries no L3 config of its own.


Dependencies
------------

- `community.general` (`nmcli`, `ini_file`)


Example Playbook
----------------

**Bonded LACP uplink with tagged VLANs, plus a separate management NIC:**

```yaml
- name: Configure host network interfaces
  hosts: all
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.network_interfaces
      vars:
        network_interfaces:
          - name: mgmt0
            type: physical
            device: eno1
            ip4: ["10.0.0.5/24"]
            gw4: 10.0.0.1
            dns4: ["10.0.0.53"]

          - name: bond0
            type: bond
            bond_mode: 802.3ad
            bond_members: [eno2, eno3]

          - name: vlan100
            type: vlan
            vlan_id: 100
            vlan_parent: bond0
            ip4: ["10.100.0.5/24"]
            gw4: 10.100.0.1
```

**Single physical interface, DHCP:**

```yaml
network_interfaces:
  - name: eth0
    type: physical
    method4: auto
```


Notes
-----

- **SSH lockout risk**: applying this role to the interface your current
  SSH session is on can drop the connection — nmcli reactivates a modified
  connection profile to apply changes. Prefer running it over an
  out-of-band NIC (like `mgmt0` in the example above), or via console/IPMI
  access, not over the interface being reconfigured.
- **Bond members must not carry their own connection**: NetworkManager
  will refuse (or silently conflict) if a device already has an active,
  unrelated connection profile when this role tries to enslave it. Don't
  give a device both a `type: physical` entry and a `bond_members` entry.
- **VLAN parent is a device name, not a connection name**: `vlan_parent`
  must match the parent's `device` (its kernel interface name — `eno1`,
  `bond0`), not the parent's `name`, unless you set them equal.
- **Debian `[ifupdown] managed=true`**: this is a host-wide NetworkManager
  setting, not scoped to the interfaces this role manages. If other
  automation on the same host still relies on `/etc/network/interfaces`
  for a *different* device, that device now falls under NM's control too.
