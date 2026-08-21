proxmox_ha
==========

Manages ProxMox VE High Availability configuration via the PVE REST API:
legacy HA groups, HA resource assignment (VM/CT → HA management), and PVE
9.0+ node-affinity/resource-affinity rules.

Tested on: any Ansible controller against a ProxMox VE 8.x or 9.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.0.0` — `proxmox_cluster_ha_rules_info`
  was added in that release; `proxmox_cluster_ha_rules` needs `>= 1.4.0`,
  `proxmox_cluster_ha_groups`/`proxmox_cluster_ha_resources` need `>= 1.1.0`).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset:

```yaml
proxmox_ha_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_ha_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_ha_api_user:     "root@pam"
proxmox_ha_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. Grant the token `Sys.Console`
and HA-related privileges (`PVEVMAdmin` or similar) at the relevant path.


Groups vs. rules — which to use
---------------------------------

ProxMox VE 9.0 deprecated **HA groups** in favor of **HA node-affinity
rules**. The legacy `/cluster/ha/groups` API still works on 9.x, but new
deployments should use `rule` (type `node-affinity`) instead. Rules also add
a concept groups never had — **resource-affinity** (keep resources together
or apart across nodes) — with no group equivalent. This role supports both;
pick based on your cluster's PVE version:

| PVE version | Recommended |
|---|---|
| 8.x | `group` + `resource` |
| 9.x+ | `rule` + `resource` |


Role Variables
---------------

### Connection

Defaults from the shared `proxmox_api_*` vars (set those once for the whole
play/inventory) — override only if this role needs a different node or credential.

```yaml
proxmox_ha_api_host: "pve2.example.com"   # optional — overrides the shared proxmox_api_host
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_ha_do_info` | `false` | `info` | Query HA rules (no info module exists for legacy groups/resources) |
| `proxmox_ha_do_group` | `false` | `group` | Manage legacy HA groups |
| `proxmox_ha_do_resource` | `false` | `resource` | Assign/remove VM/CT HA resources |
| `proxmox_ha_do_rule` | `false` | `rule` | Manage PVE 9+ node/resource-affinity rules |

**Neither `group`/`resource` nor `rule` support `--check`** (the underlying
modules declare no check_mode support), except `rule`, which does support
full check/diff mode.

### info

```yaml
proxmox_ha_info_rule:     ""   # filter to one rule by name — mutually exclusive with type/resource below
proxmox_ha_info_type:     ""   # node-affinity | resource-affinity
proxmox_ha_info_resource: ""   # e.g. "vm:100" — filter to rules affecting this resource
```

Sets `proxmox_ha_rule_facts`. There is no `proxmox_cluster_ha_groups_info`/
`proxmox_cluster_ha_resources_info` upstream — query
`/cluster/ha/groups`/`/cluster/ha/resources` directly (`ansible.builtin.uri`
or `pvesh`) if you need to audit legacy state.

### group

```yaml
proxmox_ha_groups:
  - name: ha0
    state: present
    nodes: "node0:0,node1:1"   # list or "node:priority,node:priority" string — higher number = higher priority
    nofailback: false
    restricted: false
    comment: "Primary HA group"
```

### resource

```yaml
proxmox_ha_resources:
  - name: "vm:100"       # HA resource id ("sid") — "vm:<id>" or "ct:<id>"
    state: present
    group: ha0            # legacy group assignment — omit if using rules instead
    max_relocate: 2
    max_restart: 2
    hastate: started       # started | stopped | disabled | ignored
    comment: "Web frontend VM"
```

**Gotcha**: the module compares resource IDs by stripping the `vm:`/`ct:`
prefix internally — a VM and a CT sharing the same numeric ID in the same
cluster can collide during idempotency checks. Avoid overlapping VMID/CTID
ranges if you use both.

### rule

```yaml
proxmox_ha_rules:
  - name: prefer-node0
    state: present
    type: node-affinity
    nodes: ["node0:10", "node1:20"]
    resources: ["vm:100"]
    strict: false          # false = resource can move to a non-listed node if none of the listed nodes are available
    disable: false
    comment: "VM 100 prefers node0, falls back to node1"

  - name: separate-web-nodes
    type: resource-affinity
    affinity: negative     # positive = keep resources together, negative = keep them apart
    resources: ["vm:100", "vm:101"]
```

`type` is immutable on an existing rule unless you set `force: true` (which
deletes and recreates it). `affinity` is required when `type:
resource-affinity`; `nodes` is required when `type: node-affinity`.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_ha` | Entire role |
| `info` | Query HA rules |
| `group` | Manage legacy HA groups |
| `resource` | Manage HA resources |
| `rule` | Manage HA rules |


Example Playbook — PVE 9+ node-affinity + resource assignment
------------------------------------------------------------------

```yaml
- name: Configure HA for the web tier
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_ha
      vars:
        proxmox_ha_api_host:         "pve2.example.com"
        proxmox_ha_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_ha_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_ha_do_rule: true
        proxmox_ha_do_resource: true
        proxmox_ha_rules:
          - name: separate-web-nodes
            type: resource-affinity
            affinity: negative
            resources: ["vm:100", "vm:101"]
        proxmox_ha_resources:
          - name: "vm:100"
            hastate: started
            max_restart: 2
          - name: "vm:101"
            hastate: started
            max_restart: 2
```

Example Playbook — legacy PVE 8.x group
-------------------------------------------

```yaml
- name: Configure legacy HA group
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_ha
      vars:
        proxmox_ha_api_host:         "pve2.example.com"
        proxmox_ha_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_ha_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_ha_do_group: true
        proxmox_ha_do_resource: true
        proxmox_ha_groups:
          - name: ha0
            nodes: "pve1:1,pve2:0"
            restricted: true
        proxmox_ha_resources:
          - name: "vm:100"
            group: ha0
            hastate: started
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No handlers**: every module call is idempotent against PVE's own state.
