proxmox_storage
================

Creates/deletes ProxMox VE storage backend definitions — NFS, CIFS,
directory, iSCSI, CephFS, RBD, Proxmox Backup Server, and ZFS pool storage —
via the PVE REST API. This manages cluster/node-level storage backends
themselves, not disks on a specific VM (see `mgcdrd.infrabase.proxmox_disk`
for that).

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 1.3.0` — `proxmox_storage`
  was added in that release).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


No LVM / LVM-thin / Btrfs support
------------------------------------

The underlying `community.proxmox.proxmox_storage` module's `type` choices
are exactly `cephfs`, `cifs`, `dir`, `iscsi`, `nfs`, `pbs`, `rbd`, `zfspool`
— **there is no `lvm`, `lvmthin`, or `btrfs` choice**, even though PVE
itself supports them. If you need LVM/LVM-thin storage, provision it
outside this role (`pvesm add lvm|lvmthin` via `ansible.builtin.command`, or
manually) until upstream adds support.


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset:

```yaml
proxmox_storage_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_storage_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_storage_api_user:     "root@pam"
proxmox_storage_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. Grant the token
`Datastore.Allocate` at minimum.


Role Variables
---------------

### Connection (required)

```yaml
proxmox_storage_api_host: "pve2.example.com"
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_storage_do_info` | `false` | `info` | List configured storage |
| `proxmox_storage_do_manage` | `false` | `manage` | Create/delete storage definitions |

### info

No variables required. Sets `proxmox_storage_facts`.

### manage

**No update path exists.** `state: present` against an already-existing
storage is always a no-op — the module doesn't compare or apply parameter
changes on a storage that's already there. Delete and recreate if you need
to change `content`, `nodes`, or backend options on an existing storage.

```yaml
proxmox_storage_definitions:
  - name: net-nfsshare01
    type: nfs
    state: present
    nodes: ["pve1", "pve2"]        # omit for cluster-wide availability
    content: ["images", "rootdir"]
    nfs_options:
      server: "10.0.0.124"
      export: "/mnt/tank/pve"

  - name: zfspool-storage
    type: zfspool
    content: ["images", "rootdir"]
    zfspool_options:
      pool: "rpool/data"
      sparse: true

  - name: local-extra
    type: dir
    nodes: ["pve1"]
    content: ["vztmpl", "iso", "backup"]
    dir_options:
      path: "/mnt/pve/local-extra"
```

Only the `<type>_options` dict matching an item's `type` is used — set the
others or leave them unset, they're ignored either way.

| `type` | Options key | Required suboptions |
|---|---|---|
| `cephfs` | `cephfs_options` | none enforced by the module (PVE's API is the only backstop — `monhost` etc. are accepted but not validated here) |
| `cifs` | `cifs_options` | `server`, `share`, `username`, `password` |
| `dir` | `dir_options` | `path` |
| `iscsi` | `iscsi_options` | `portal`, `target` |
| `nfs` | `nfs_options` | `server`, `export` |
| `pbs` | `pbs_options` | `server`, `datastore`, `username`, `password` |
| `rbd` | `rbd_options` | `pool` (enforced at the PVE API level, not by Ansible's own argument validation — omitting it fails at apply time, not pre-flight) |
| `zfspool` | `zfspool_options` | `pool` |

`content` accepts any of: `backup`, `images`, `import`, `iso`, `rootdir`,
`snippets`, `vztmpl`. `nodes` restricts the storage to specific nodes;
omitting it makes it available cluster-wide (despite the module's own docs
saying `nodes` is required for `state: present` — that's not actually
enforced in code, confirmed from source).


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_storage` | Entire role |
| `info` | List configured storage |
| `manage` | Create/delete storage definitions |


Example Playbook — add NFS and ZFS storage
------------------------------------------------

```yaml
- name: Configure cluster storage backends
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_storage
      vars:
        proxmox_storage_api_host:         "pve2.example.com"
        proxmox_storage_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_storage_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_storage_do_manage: true
        proxmox_storage_definitions:
          - name: truenas
            type: nfs
            content: ["images", "iso", "backup"]
            nfs_options:
              server: "10.0.0.124"
              export: "/mnt/tank/pve"
          - name: local-zfs
            type: zfspool
            content: ["images", "rootdir"]
            zfspool_options:
              pool: "rpool/data"
              sparse: true
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No `--diff` support**: the underlying module declares
  `diff_mode: support: none`.
- **No handlers**: every module call is idempotent against PVE's own state,
  within the limits of the "no update path" caveat above.
