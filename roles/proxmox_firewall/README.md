proxmox_firewall
=================

Manages ProxMox VE's own built-in firewall via the PVE REST API: cluster and
node-level options, firewall rules (cluster/group/vnet/node/vm level),
security groups, aliases, and IP sets. This is **PVE's firewall**, distinct
from the OS-level `firewalld` role and from per-guest firewall *options*
(see Gaps below).

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Collection coverage — read before using
-------------------------------------------

`community.proxmox`'s firewall support is **mid-refactor** as of collection
2.0.0/2.1.0-dev (tracked upstream in
[issue #300](https://github.com/ansible-collections/community.proxmox/issues/300)).
What exists today:

| Module | Covers | Released? |
|---|---|---|
| `proxmox_cluster_firewall_options` | Cluster enable, default policies, log ratelimit | Yes (2.0.0) |
| `proxmox_node_firewall_options` / `_info` | Per-node enable, logging, protocol hardening | Yes (2.0.0) |
| `proxmox_firewall` / `_info` | Rules (any level), security-group create/delete (name only), aliases, IP sets | Yes (1.4.0) |
| `proxmox_cluster_firewall_security_group` | Security-group **rule content** | **No — targeted for 2.1.0** |

**Gaps not covered by this role, because no module exists for them:**

- **Security-group rule content** — this role can create/delete named
  security groups, but cannot populate what's inside them. That needs
  `proxmox_cluster_firewall_security_group`, unreleased. Once it ships,
  expect this role to gain a `group_rule` section and change how `group`
  idempotency works (index-based rule sync, not `pos`-based).
- **Per-guest firewall *options*** (`enable`, `policy_in`/`policy_out`,
  `dhcp`, `macfilter`, `ipfilter`, `ndp`, `radv`, per-guest log levels — the
  `/nodes/{node}/{qemu|lxc}/{vmid}/firewall/options` endpoint) — distinct
  from per-guest *rules*, which **are** covered via `rule`'s `level: vm`.
  No module exists for the options endpoint; not implemented here.
- **Per-NIC `firewall=1` flag** — set via `proxmox_vm`/`proxmox_lxc`'s
  network config, not this role.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.0.0`).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset:

```yaml
proxmox_firewall_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_firewall_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_firewall_api_user:     "root@pam"
proxmox_firewall_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. Grant the token
`Sys.Modify` at minimum.


Role Variables
---------------

### Connection (required)

```yaml
proxmox_firewall_api_host: "pve2.example.com"
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_firewall_do_info` | `false` | `info` | Query rules/groups/aliases/ipsets/node options |
| `proxmox_firewall_do_cluster_options` | `false` | `cluster_options` | Cluster-wide firewall enable/policy |
| `proxmox_firewall_do_node_options` | `false` | `node_options` | Per-node firewall options |
| `proxmox_firewall_do_rule` | `false` | `rule` | Manage firewall rules |
| `proxmox_firewall_do_group` | `false` | `group` | Create/delete security groups (name only) |
| `proxmox_firewall_do_alias` | `false` | `alias` | Manage aliases |
| `proxmox_firewall_do_ipset` | `false` | `ipset` | Manage IP sets |

**`rule`/`group`/`alias`/`ipset` do not support `--check`** (the underlying
`proxmox_firewall` module declares no check_mode support). `cluster_options`
and `node_options` support full check mode.

### info

```yaml
proxmox_firewall_info_level: "cluster"   # cluster | group | vnet | node | vm
proxmox_firewall_info_node:  ""          # required when level: node
proxmox_firewall_info_vmid:  ""          # required when level: vm
proxmox_firewall_info_vnet:  ""          # required when level: vnet
proxmox_firewall_info_group: ""          # required when level: group
proxmox_firewall_info_node_options_target: "pve1"   # "" = skip this lookup
```

Sets `proxmox_firewall_facts` (groups/ip_sets/aliases/firewall_rules — the
first two are cluster-level only) and, if
`proxmox_firewall_info_node_options_target` is set, `proxmox_firewall_node_options_facts`.

### cluster_options

```yaml
proxmox_firewall_cluster_state: "enabled"
proxmox_firewall_cluster_ebtables: true
proxmox_firewall_cluster_input_policy: "DROP"
proxmox_firewall_cluster_output_policy: "ACCEPT"
proxmox_firewall_cluster_forward_policy: "ACCEPT"
proxmox_firewall_cluster_log_ratelimit:
  enabled: true
  burst: 10
  rate: "5/second"
```

### node_options

```yaml
proxmox_firewall_node_options:
  - node_name: pve1
    state: enabled
    log_level_in: nolog
    nosmurfs: true
    protection_synflood: true
    protection_synflood_rate: 200
    protection_synflood_burst: 1000
```

Full field list: `state` (enabled/disabled), `log_level_in`/`log_level_out`/
`log_level_forward`/`smurf_log_level`/`tcp_flags_log_level` (emerg through
debug, or nolog), `ndp`, `nftables`, `nosmurfs`, `tcpflags`,
`nf_conntrack_allow_invalid`, `nf_conntrack_helpers`, `nf_conntrack_max`,
`nf_conntrack_tcp_timeout_established`, `nf_conntrack_tcp_timeout_syn_recv`,
`protection_synflood`, `protection_synflood_burst`,
`protection_synflood_rate`. Numeric min/max constraints mentioned in PVE's
own docs (e.g. `nf_conntrack_max` minimum 32768) aren't enforced client-side
by the module — the PVE API is the only backstop, so out-of-range values
fail at apply time, not pre-flight.

### rule

```yaml
proxmox_firewall_rules:
  - level: cluster        # cluster | group | vnet | node | vm
    state: present
    rules:
      - type: in            # in | out | forward | group
        action: ACCEPT       # ACCEPT | DROP | REJECT | a security-group name
        pos: 0                 # required per rule
        proto: tcp
        dport: "22"
        source: "10.0.0.0/8"
        log: nolog
        enable: true

  - level: vm
    vmid: 100
    state: present
    rules:
      - type: in
        action: ACCEPT
        pos: 0
        proto: tcp
        dport: "80"
```

`node`/`vmid`/`vnet`/`group` are required per-item when `level` is
`node`/`vm`/`vnet`/`group` respectively. `pos` (top-level, not inside
`rules`) is required when `state: absent` to identify which rule to delete.
Set `update: true` on an item to modify an existing rule in place rather
than create a new one.

### group

```yaml
proxmox_firewall_groups:
  - group: webservers
    comment: "Web tier"
    state: present
```

Name/comment only — see Gaps above for rule content.

### alias

```yaml
proxmox_firewall_aliases:
  - name: office
    cidr: "203.0.113.0/24"
    state: present
```

### ipset

```yaml
proxmox_firewall_ipsets:
  - name: hypervisors
    comment: "PVE hosts"
    state: present
    cidrs:
      - cidr: "192.168.1.10"
        comment: "pve1"
      - cidr: "192.168.1.11"
        comment: "pve2"
```


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_firewall` | Entire role |
| `info` | Query state |
| `cluster_options` | Cluster-wide options |
| `node_options` | Per-node options |
| `rule` | Manage rules |
| `group` | Manage security groups |
| `alias` | Manage aliases |
| `ipset` | Manage IP sets |


Example Playbook — enable the firewall and allow SSH from a management subnet
------------------------------------------------------------------------------------

```yaml
- name: Baseline PVE firewall
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_firewall
      vars:
        proxmox_firewall_api_host:         "pve2.example.com"
        proxmox_firewall_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_firewall_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_firewall_do_cluster_options: true
        proxmox_firewall_do_alias: true
        proxmox_firewall_do_rule: true
        proxmox_firewall_cluster_state: "enabled"
        proxmox_firewall_cluster_input_policy: "DROP"
        proxmox_firewall_aliases:
          - name: mgmt-subnet
            cidr: "10.0.0.0/24"
        proxmox_firewall_rules:
          - level: cluster
            rules:
              - type: in
                action: ACCEPT
                pos: 0
                proto: tcp
                dport: "22"
                source: "mgmt-subnet"
                log: nolog
                enable: true
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No handlers**: every module call is idempotent against PVE's own state
  (within the check_mode limits noted above).
