proxmox_cluster
================

Creates a ProxMox VE cluster and joins additional nodes to it, via the PVE
REST API — no SSH or `pvecm` CLI needed. Also exposes cluster status and
join-info (fingerprint/nodelist) lookups.

Tested on: any Ansible controller against ProxMox VE 8.x nodes.


How this actually works — read before using
-----------------------------------------------

`community.proxmox.proxmox_cluster` calls the PVE REST API directly
(`POST /cluster/config` for create, `POST /cluster/config/join` for join) —
it does **not** shell out to `pvecm`. The important nuance: **`api_host` is
the node the action is performed against, not necessarily the cluster
master.**

- `create` — `api_host` must be the intended **master**; the module calls
  create on that node's own API.
- `join` — `api_host` must be the **new node being added**; the module
  calls join on that node's own API, which then contacts `master_ip`
  (a separate parameter) to authorize and complete the join. This mirrors
  running `pvecm add <master-ip>` locally on the new node, just over HTTPS
  instead of SSH.

**There is no `state: absent` / leave-cluster action.** Cluster removal
(`pvecm delnode`) isn't covered by `community.proxmox` — that requires
`ansible.builtin.command` run via SSH on a remaining cluster member; this
role doesn't attempt it.


Requirements
------------

- The Ansible controller must be able to reach every node's PVE API on
  port 8006 (the master's, for create/info; each joining node's own, for
  join).
- `community.proxmox` collection installed (`>= 1.0.0`).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset:

```yaml
proxmox_cluster_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_cluster_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_cluster_api_user:     "root@pam"
proxmox_cluster_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. **Always set
`proxmox_cluster_master_api_password` explicitly for `join`** — the
underlying module falls back to whatever authenticates the *local* node's
API call if you don't, silently reusing the wrong credential when you use
per-node API tokens rather than one shared password.


Role Variables
---------------

### Connection

Defaults from the shared `proxmox_api_*` vars (set those once for the whole
play/inventory) — override only if this role needs a different node or credential.

```yaml
proxmox_cluster_api_host: "pve1.example.com"   # master for create/info; overridden per-item for join
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_cluster_do_info` | `false` | `info` | Query cluster status + join info |
| `proxmox_cluster_do_create` | `false` | `create` | Create a new cluster |
| `proxmox_cluster_do_join` | `false` | `join` | Join nodes to an existing cluster |

### info

No variables required beyond the connection block. Sets:

| Fact | Source |
|---|---|
| `proxmox_cluster_status` | `community.proxmox.proxmox_cluster_status_info` |
| `proxmox_cluster_join_facts` | `community.proxmox.proxmox_cluster_join_info` |

Use `proxmox_cluster_join_facts.cluster_join[0].nodelist[].pve_fp` as the
fingerprint input for `join` below — run `info` against the master first.

### create

```yaml
proxmox_cluster_api_host: "pve1.example.com"   # the intended master
proxmox_cluster_name:  "labcluster"
proxmox_cluster_link0: "10.10.1.1"
proxmox_cluster_link1: "10.10.2.1"
```

### join

```yaml
proxmox_cluster_master_ip:           "pve1.example.com"
proxmox_cluster_master_fingerprint:  "{{ proxmox_cluster_join_facts.cluster_join[0].nodelist[0].pve_fp }}"
proxmox_cluster_master_api_password: "{{ vault_proxmox_cluster_master_api_password }}"

proxmox_cluster_join_nodes:
  - api_host: "pve2.example.com"   # required — the new node's own API
    link0: "10.10.1.2"
    link1: "10.10.2.2"
```

Each item's `api_host` is required; `api_user`/`api_password`/
`api_token_id`/`api_token_secret` may be set per-item if that node's own
credentials differ from the top-level `proxmox_cluster_api_user`/etc.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_cluster` | Entire role |
| `info` | Query cluster status/join info |
| `create` | Create a cluster |
| `join` | Join nodes to a cluster |


Example Playbook — create then join two nodes
-----------------------------------------------------

```yaml
- name: Create the cluster on the master
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_cluster
      vars:
        proxmox_cluster_api_host:     "pve1.example.com"
        proxmox_cluster_api_user:     "root@pam"
        proxmox_cluster_api_password: "{{ vault_proxmox_api_password }}"
        proxmox_cluster_do_create: true
        proxmox_cluster_name: "labcluster"
        proxmox_cluster_link0: "10.10.1.1"

- name: Fetch join fingerprint from the master
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_cluster
      vars:
        proxmox_cluster_api_host:     "pve1.example.com"
        proxmox_cluster_api_user:     "root@pam"
        proxmox_cluster_api_password: "{{ vault_proxmox_api_password }}"
        proxmox_cluster_do_info: true

- name: Join additional nodes
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_cluster
      vars:
        proxmox_cluster_api_user:     "root@pam"
        proxmox_cluster_api_password: "{{ vault_proxmox_api_password }}"
        proxmox_cluster_do_join: true
        proxmox_cluster_master_ip:           "pve1.example.com"
        proxmox_cluster_master_fingerprint:  "{{ hostvars['localhost']['proxmox_cluster_join_facts']['cluster_join'][0]['nodelist'][0]['pve_fp'] }}"
        proxmox_cluster_master_api_password: "{{ vault_proxmox_api_password }}"
        proxmox_cluster_join_nodes:
          - api_host: "pve2.example.com"
            link0: "10.10.1.2"
          - api_host: "pve3.example.com"
            link0: "10.10.1.3"
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No `state: absent`**: leaving/removing a node from a cluster isn't
  covered by this role — use `pvecm delnode <name>` via SSH on a remaining
  member.
- **`cluster_name` fallback**: if omitted on `create`, the underlying module
  falls back to using `api_host` as the cluster name — always set
  `proxmox_cluster_name` explicitly rather than relying on that.
- **No handlers**: every module call is idempotent against PVE's own state
  (`check_mode` is fully supported by `proxmox_cluster`, though `diff_mode`
  is not).
