proxmox_snapshot
=================

Creates, deletes, and rolls back ProxMox VE VM/CT snapshots via the PVE REST
API. Works for both QEMU VMs and LXC containers.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


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
proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_api_user:     "root@pam"
proxmox_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. **`unbind: true` (LXC only)
forces password auth** — it requires `api_user: root@pam` and
`api_password` set explicitly, and hard-fails under API token auth even if
you standardize on tokens for everything else.


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
| `proxmox_snapshot_do_info` | `false` | `info` | List/query snapshots |
| `proxmox_snapshot_do_manage` | `false` | `manage` | Create/delete/rollback snapshots |

### info

```yaml
proxmox_snapshot_info_hostname: "myvm"   # or proxmox_snapshot_info_vmid: 100
proxmox_snapshot_info_snapname: ""       # "" = list all snapshots for the target
```

Sets `proxmox_snapshot_facts`.

### manage

```yaml
proxmox_snapshot_snapshots:
  - hostname: myvm             # or vmid: 100 — vmid wins if both are set
    snapname: pre-updates
    state: present               # present | absent | rollback
    description: "Before OS updates"
    vmstate: false                # include RAM state — QEMU only, silently ignored on LXC
    retention: 0                  # keep only the N newest; 0 = keep all; applies on present only, and only when a NEW snapshot was actually created this run
    force: false                  # absent only — remove from config even if disk snapshot removal fails
    unbind: false                 # LXC only — see Authentication above
    timeout: 30
```

`snapname` has no safe default to fall back on — the underlying module
defaults to the literal string `ansible_snap` if you omit it, which is
almost never what you want, so always set it explicitly.

**`rollback` behaves differently from `absent`**: if the target snapshot
doesn't exist, `absent` is a graceful no-op, but `rollback` hard-fails the
task. Don't assume rollback is safe to run unconditionally the way
teardown/absent tasks usually are.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_snapshot` | Entire role |
| `info` | List/query snapshots |
| `manage` | Create/delete/rollback |


Example Playbook — pre-change snapshot with retention
-----------------------------------------------------------

```yaml
- name: Snapshot before maintenance
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_snapshot
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_snapshot_do_manage: true
        proxmox_snapshot_snapshots:
          - hostname: newhost01
            snapname: "pre-maint-{{ ansible_date_time.date }}"
            description: "Automated pre-maintenance snapshot"
            retention: 5
```

Example Playbook — rollback
-------------------------------

```yaml
- name: Roll back a failed change
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_snapshot
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_snapshot_do_manage: true
        proxmox_snapshot_snapshots:
          - hostname: newhost01
            snapname: "pre-maint-2026-07-14"
            state: rollback
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No update-in-place**: if a snapshot with the given `snapname` already
  exists, `state: present` is a no-op — it does not update `description` or
  `vmstate` on the existing snapshot. Delete and recreate if you need to
  change those.
- **No `--diff` support**: the underlying module supports `--check` fully
  but does not produce a diff.
- **No handlers**: every module call is idempotent against PVE's own state
  (except `manage`'s "always fires the API call" nature on `rollback`,
  which by definition changes guest state every time it succeeds).
