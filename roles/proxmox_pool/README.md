proxmox_pool
=============

Creates/deletes ProxMox VE resource pools and manages VM/storage membership
within them, via the PVE REST API.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
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
proxmox_pool_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_pool_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_pool_api_user:     "root@pam"
proxmox_pool_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. Grant the token `Pool.Allocate`
at minimum.


Role Variables
---------------

### Connection (required)

```yaml
proxmox_pool_api_host: "pve2.example.com"
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_pool_do_pool` | `false` | `pool` | Create/delete pools |
| `proxmox_pool_do_member` | `false` | `member` | Add/remove/reconcile pool membership |

### pool

```yaml
proxmox_pool_pools:
  - poolid: customer-a
    comment: "Customer A resources"
    state: present
```

`comment` is only applied on **creation** — the underlying module has no
update path, so changing it here on an existing pool is a no-op; edit it in
PVE's UI/API directly if needed. A pool must be empty (no VM or storage
members) before `state: absent` will succeed.

### member

```yaml
proxmox_pool_poolid: "customer-a"
proxmox_pool_members:
  - vm: 101
  - vm: "pxe.home.arpa"    # VM name is resolved to a vmid automatically
  - storage: "zfs-data"
proxmox_pool_member_state: "present"   # present | absent — ignored when exclusive: true
proxmox_pool_exclusive: false          # true = reconcile to exactly this list (adds missing, removes extras)
proxmox_pool_allow_move: false          # true = allow adding a guest that's already in another pool
```

Each item needs exactly one of `vm` or `storage`. Storage names are
validated to exist in the cluster before the API call — the task fails if a
referenced storage doesn't exist. Note there is no way to add a VM to a
pool at creation time through this role — either set `pool` directly in
`mgcdrd.infrabase.proxmox_vm`/`proxmox_lxc` at create time (their underlying
modules support it there), or use `member` here for existing VMs (which
`proxmox_vm`/`proxmox_lxc` cannot update after creation).


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_pool` | Entire role |
| `pool` | Create/delete pools |
| `member` | Manage membership |


Example Playbook — create a pool and populate it
------------------------------------------------------

```yaml
- name: Set up customer resource pool
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_pool
      vars:
        proxmox_pool_api_host:         "pve2.example.com"
        proxmox_pool_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_pool_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_pool_do_pool: true
        proxmox_pool_do_member: true
        proxmox_pool_pools:
          - poolid: customer-a
            comment: "Customer A resources"
        proxmox_pool_poolid: "customer-a"
        proxmox_pool_exclusive: true
        proxmox_pool_members:
          - vm: 101
          - vm: 102
          - storage: "zfs-data"
```

Example Playbook — remove a pool (must already be empty)
---------------------------------------------------------------

```yaml
- name: Decommission customer pool
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_pool
      vars:
        proxmox_pool_api_host: "pve2.example.com"
        proxmox_pool_do_pool: true
        proxmox_pool_pools:
          - poolid: customer-a
            state: absent
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No `proxmox_pool_info` module exists upstream** — there's no dedicated
  read-only fact-gathering task in this role; query `/pools` directly
  (`ansible.builtin.uri` or `pvesh get /pools`) if you need to audit
  membership outside of a `member` task's own idempotency check.
- **`exclusive: true` is not loop-aware** — pass the full desired membership
  list in one task; the module reconciles adds and removes together.
- **No handlers**: every module call is idempotent against PVE's own state.
