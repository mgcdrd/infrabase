proxmox_ceph
=============

Manages ProxMox VE-integrated Ceph components — monitor/manager/metadata
server daemons, OSDs, and pools — via the PVE REST API's simplified Ceph
wizard endpoints.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster with
Ceph packages already installed on the target nodes (see Gaps below).


This role is necessarily thin — read before using
-------------------------------------------------------

`community.proxmox`'s Ceph coverage mirrors PVE's own simplified Ceph
wizard, not full `ceph.conf`-level control. Confirmed by reading every
Ceph-related module's source directly: there are exactly 5 modules, all
authored as thin wrappers around `/nodes/{node}/ceph/*` endpoints, and nothing
else — `community.general` has zero Ceph modules either (never absorbed
into `community.proxmox`, since none existed to absorb).

**Explicitly NOT covered by this role, because no module exists:**

- **Initial Ceph package install / cluster init** (`pveceph init` /
  `POST /nodes/{node}/ceph/init`). Provision this yourself — SSH +
  `ansible.builtin.command`, or a raw API call — before using any section
  of this role. This role assumes Ceph is already initialized on the
  cluster.
- **Global Ceph config** (`public_network`, `cluster_network`, and other
  `ceph.conf`-level settings).
- **CRUSH rule management** — `pool`'s `crush_rule` only *assigns* an
  existing rule to a pool; creating/editing the rules themselves isn't
  covered.
- **Keyring/auth management.**
- **Standby-manager designation** — `mgr` is create/delete only, no
  active/standby control.
- **OSD-wide flags** (noout, norebalance, etc.).
- **No Ceph info/facts module exists** in this collection at all — there's
  no `info` gated section in this role; query cluster status via PVE's UI,
  `pvesh get /nodes/{node}/ceph/status`, or a raw `ansible.builtin.uri` call
  if you need read-only facts.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.0.0` — `proxmox_ceph_pool`
  needs 2.0.0; `mon`/`mgr`/`mds`/`osd` need `>= 1.5.0`).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset:

```yaml
proxmox_ceph_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_ceph_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_ceph_api_user:     "root@pam"
proxmox_ceph_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. Grant the token
`Sys.Modify` + `Datastore.Allocate` at minimum.


Role Variables
---------------

### Connection

Defaults from the shared `proxmox_api_*` vars (set those once for the whole
play/inventory) — override only if this role needs a different node or credential.

```yaml
proxmox_ceph_api_host: "pve2.example.com"   # optional — overrides the shared proxmox_api_host
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_ceph_do_mon` | `false` | `mon` | Create/delete monitor daemons |
| `proxmox_ceph_do_mgr` | `false` | `mgr` | Create/delete manager daemons |
| `proxmox_ceph_do_mds` | `false` | `mds` | Create/delete metadata server daemons |
| `proxmox_ceph_do_osd` | `false` | `osd` | Manage OSD lifecycle |
| `proxmox_ceph_do_pool` | `false` | `pool` | Create/update/delete pools |

### mon / mgr / mds

All three are identical in shape — create/delete only, no config knobs:

```yaml
proxmox_ceph_mons:
  - node: pve1
    state: present
proxmox_ceph_mgrs:
  - node: pve1
    state: present
proxmox_ceph_mds:
  - node: pve1
    state: present
```

The daemon's identity is implicitly the node name — there's no separate
mon-id/mgr-id param, and `mgr` has no way to designate active vs standby.

### osd

```yaml
proxmox_ceph_osds:
  - node: pve1
    state: present            # present | absent | in | out | scrub | start | stop | restart
    dev: /dev/sdb               # required for state: present
    crush_device_class: ssd
    db_dev: /dev/nvme0n1         # separate DB device, optional
    encrypted: false
  - node: pve1
    state: absent
    osdid: 0                     # required for every state except present
    cleanup: true
```

`dev` is required when `state: present`; `osdid` is required for every
other state. The module returns only `msg` — no OSD ID is handed back on
creation, so track `osdid` yourself (e.g. from PVE's UI, or a separate
facts lookup) if you need to reference it in a later `state: absent`/`in`/
`out`/`scrub` run.

### pool

```yaml
proxmox_ceph_pools:
  - node: pve1
    name: vm-pool
    state: present
    size: 3
    min_size: 2
    pg_num: 128
    pg_autoscale_mode: "on"
    crush_rule: replicated_rule
    add_storages: true            # auto-register the pool as a PVE storage
    timeout: 30
```

**This is the only module in the role with real idempotent update
semantics** — it diffs current vs. desired state and issues a `PUT` if the
pool exists but differs, rather than just create/delete. One caveat found
in the module's comparison logic: it checks your params against PVE's own
pool-status API response key-for-key: if a field comes back with a
different type than what you passed (e.g. int vs str), it could report a
spurious diff/PUT on every run. Not verifiable without a live Ceph cluster
— **flag as uncertain, worth empirically confirming idempotency** once you
have one to test against.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_ceph` | Entire role |
| `mon` | Monitor daemons |
| `mgr` | Manager daemons |
| `mds` | Metadata server daemons |
| `osd` | OSD lifecycle |
| `pool` | Pools |


Example Playbook — 3-node mon/mgr + OSDs + a pool
--------------------------------------------------------

```yaml
- name: Stand up Ceph on an already-initialized cluster
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_ceph
      vars:
        proxmox_ceph_api_host:         "pve1.example.com"
        proxmox_ceph_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_ceph_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_ceph_do_mon: true
        proxmox_ceph_do_mgr: true
        proxmox_ceph_do_osd: true
        proxmox_ceph_do_pool: true
        proxmox_ceph_mons:
          - node: pve1
          - node: pve2
          - node: pve3
        proxmox_ceph_mgrs:
          - node: pve1
          - node: pve2
        proxmox_ceph_osds:
          - node: pve1
            dev: /dev/sdb
          - node: pve2
            dev: /dev/sdb
          - node: pve3
            dev: /dev/sdb
        proxmox_ceph_pools:
          - node: pve1
            name: vm-pool
            size: 3
            min_size: 2
            pg_num: 128
            add_storages: true
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No `--diff` support**: all Ceph modules declare `diff_mode: support:
  none` (though `check_mode` is fully supported).
- **No handlers**: every module call is idempotent against PVE's own state,
  within the pool caveat noted above.
