proxmox_node
=============

Manages ProxMox VE node-level operations via the PVE REST API: power state
(wake-on-lan / shutdown), certificate/DNS/subscription config, and PVE task
listing/polling.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


No reboot, no target-MAC wake-on-lan
----------------------------------------

The underlying `community.proxmox.proxmox_node` module's power handling is
narrower than the name suggests — confirmed by reading its source directly,
not inferred:

- `power_state: online` triggers wake-on-lan **only if the node isn't
  already online**, and only using the node's own **server-side** WOL
  config (`pvenode config` sets the MAC separately, on the node itself) —
  there is **no parameter to pass a target MAC**.
- `power_state: offline` triggers a graceful **shutdown** — **not a
  reboot**. There is no reboot capability anywhere in this module.

If you need an actual reboot, that's out of scope for this role as of
`community.proxmox` 2.1.0 — it isn't exposed by any module in the
collection. Options: raw `ansible.builtin.uri` against
`POST /nodes/{node}/status` with `command=reboot`, or SSH + `reboot`.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 1.2.0` — `proxmox_node` was
  added in that release; `proxmox_tasks_info` needs `>= 1.0.0`).
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

Unset `vault_*` variables resolve to `omit`. Grant the token `Sys.Modify` +
`Sys.PowerMgmt` on `/nodes/<node>` at minimum.


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
| `proxmox_node_do_info` | `false` | `info` | List nodes with detailed status |
| `proxmox_node_do_power` | `false` | `power` | Wake-on-lan / shutdown a node |
| `proxmox_node_do_config` | `false` | `config` | Update certificates/DNS/subscription |
| `proxmox_node_do_task` | `false` | `task` | List/poll PVE tasks |

### info

No variables required. Sets `proxmox_node_facts` — per-node CPU/mem/disk/
uptime/version/network detail (this is the most detailed per-node status
available in the collection; there's no separate "detailed status" module).

### power

```yaml
proxmox_node_target: "pve2"
proxmox_node_power_state: "online"   # online (WOL) | offline (shutdown)
```

### config

```yaml
proxmox_node_config_target: "pve2"
proxmox_node_certificates:
  certificate_file_path: /opt/ansible/cert.pem
  private_key_file_path: /opt/ansible/key.pem
  state: present
  force: false
proxmox_node_dns:
  dns1: "10.0.0.1"
  dns2: "10.0.0.2"
  search: "lab.example.com"   # required within this dict if dns is set at all
proxmox_node_subscription:
  state: present
  key: "{{ vault_proxmox_subscription_key }}"
```

Set only the sub-dicts you need — each is independently optional.

### task

```yaml
proxmox_node_task_target: "pve2"       # required
proxmox_node_task_source: "archive"    # archive (finished, default) | active (running) | all
proxmox_node_task_upid:   ""           # "" = list; set to poll one specific task
proxmox_node_task_wait: false          # true = poll until proxmox_node_task_upid has a status
proxmox_node_task_wait_retries: 30
proxmox_node_task_wait_delay: 5
```

`source` defaults to `archive` (finished tasks) — pass `active` or `all` if
polling a task that might still be running, or the query can miss it. There
is no blocking "wait for task" module upstream; `proxmox_node_task_wait`
implements the collection's own recommended `until`/`retries`/`delay`
polling idiom against `proxmox_tasks_info`.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_node` | Entire role |
| `info` | List node status |
| `power` | WOL/shutdown |
| `config` | Certificates/DNS/subscription |
| `task` | List/poll tasks |


Example Playbook — poll a task started by another role
---------------------------------------------------------

```yaml
- name: Wait for a backup task to finish
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_node
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_node_do_task: true
        proxmox_node_task_target: "pve2"
        proxmox_node_task_upid: "{{ some_prior_result.backups[0].upid }}"
        proxmox_node_task_wait: true
        proxmox_node_task_wait_retries: 60
        proxmox_node_task_wait_delay: 10
```

Example Playbook — wake a node
-----------------------------------

```yaml
- name: Power on a node via wake-on-lan
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_node
      vars:
        proxmox_api_host:         "pve1.example.com"   # any online node's API
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_node_do_power: true
        proxmox_node_target: "pve2"
        proxmox_node_power_state: "online"
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No `--diff` support**: all modules used here declare `diff_mode:
  support: none` (though `check_mode` is fully supported).
- **No handlers**: every module call is idempotent against PVE's own state.
