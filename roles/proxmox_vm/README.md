proxmox_vm
==========

Manages VM lifecycle in ProxMox VE via its REST API: clone a VM from a
template, start/stop/destroy an existing VM, convert a VM into a template,
and query cluster/node/storage info. Complements `mgcdrd.infrabase.proxmox_disk`,
which adds/resizes a disk on a VM that already exists — this role creates
and tears down the VM itself.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.0.0`) — same module family
  as every other `proxmox_*` role in this collection.
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller** — Python dependencies of every `community.proxmox` module:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset.
These are the same `proxmox_api_token_id`/`_secret`/`_user`/`_password`
vars every `proxmox_*` role uses — set them once, not per role:

```yaml
# API token (recommended — scoped, revocable without touching root's password)
proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"      # e.g. "svc-ansible@pve!automation"
proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"

# Password (matches proxmox_disk's default)
proxmox_api_user:     "root@pam"
proxmox_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`, so only the pair you configure
is ever sent to the module. To create a token in PVE:
`Datacenter > Permissions > API Tokens`, and grant it at minimum `VM.Allocate`,
`VM.Clone`, `VM.Config.*`, `VM.PowerMgmt`, `Datastore.AllocateSpace` on the
relevant path.


Role Variables
---------------

### Connection

Every `proxmox_*` role in this collection uses the same `proxmox_api_*`
vars — see `collections/infrabase/README.md`. Set them once for the whole
play/inventory; a VM/CT lives on one node in one cluster, so there's
nothing role-specific to override here.

```yaml
proxmox_api_host: "pve2.example.com"   # any PVE node or the cluster VIP
```

### Execution gates

Each section below is independently re-runnable via its gate + tag:

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_vm_do_info` | `false` | `info` | Cluster/node/storage lookup |
| `proxmox_vm_do_clone` | `false` | `clone` | Clone + configure + start a new VM |
| `proxmox_vm_do_lifecycle` | `false` | `lifecycle` | Start/stop/destroy an existing VM |
| `proxmox_vm_do_template` | `false` | `template` | Convert a VM into a template |

```bash
ansible-playbook site.yml --tags clone
```

### info

No variables required. Sets facts:

| Fact | Source |
|---|---|
| `proxmox_vm_cluster_status` | `community.proxmox.proxmox_cluster_status_info` |
| `proxmox_vm_node_facts` | `community.proxmox.proxmox_node_info` |
| `proxmox_vm_storage_facts` | `community.proxmox.proxmox_storage_info` |

### clone

```yaml
proxmox_vm_clone_source: "rocky9-template"   # name of the template/VM to clone
proxmox_vm_name:         "newhost01"
proxmox_vm_node:         "pve2"
proxmox_vm_storage:      "truenas"
proxmox_vm_newid:        ""        # "" = let PVE assign the next free VMID
proxmox_vm_full_clone:   true      # false = linked clone (template source only)
proxmox_vm_format:       "qcow2"

proxmox_vm_cores:   2
proxmox_vm_memory:   2048
proxmox_vm_net0:     "virtio,bridge=vmbr0"
proxmox_vm_tags:     ["lab"]

# Cloud-init (leave proxmox_vm_ipconfig0 blank to skip entirely)
proxmox_vm_ipconfig0: "ip=10.0.0.50/24,gw=10.0.0.1"
proxmox_vm_ciuser:    "admin"
proxmox_vm_sshkeys:   "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"

proxmox_vm_start_after_clone: true
```

PVE's clone operation only copies the disk — cores, memory, network, and
cloud-init are applied in a follow-up `update` call against the new VMID.
That update needs `update_unsafe: true` to change `net0` (PVE blocks
net/virtio/ide/sata/scsi changes on update by default, since they can
change a MAC address or attach a fresh disk); this role sets it via
`proxmox_vm_update_unsafe` (default `true`). Set it `false` if you'd rather
leave `net0` as whatever the source template already has.

### lifecycle

```yaml
proxmox_vm_target_name:     "oldhost01"     # looked up by name via proxmox_vm_info
proxmox_vm_lifecycle_state: "absent"        # started | stopped | absent
proxmox_vm_force_stop:      false           # stopped only — skip graceful shutdown
proxmox_vm_destroy_unreferenced_disks: true # absent only
```

Fails if zero or multiple VMs match `proxmox_vm_target_name` — the same
discovery pattern `proxmox_disk` uses, so ambiguous names surface as a clear
error rather than silently acting on the wrong VM.

### template

```yaml
proxmox_vm_template_source_name: "rocky9-golden"
```

Converts an existing VM into a reusable template. The VM should already be
stopped and generalized (cloud-init installed, machine-id cleared, SSH host
keys removed) — this role does no in-guest cleanup, it only flips the PVE
`template` flag.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_vm` | Entire role |
| `info` | Cluster/node/storage lookup |
| `clone` | Clone + configure + start |
| `lifecycle` | Start/stop/destroy |
| `template` | Convert to template |


Example Playbook — clone a VM from a template
-----------------------------------------------

```yaml
- name: Provision a new VM from template
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_vm
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_vm_do_clone: true
        proxmox_vm_clone_source: "rocky9-template"
        proxmox_vm_name:    "newhost01"
        proxmox_vm_node:    "pve2"
        proxmox_vm_storage: "truenas"
        proxmox_vm_cores:   4
        proxmox_vm_memory:  8192
        proxmox_vm_ipconfig0: "ip=10.0.0.50/24,gw=10.0.0.1"
        proxmox_vm_ciuser:    "admin"
        proxmox_vm_sshkeys:   "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

Example Playbook — tear down a VM
-----------------------------------

```yaml
- name: Remove a decommissioned VM
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_vm
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_vm_do_lifecycle: true
        proxmox_vm_target_name: "oldhost01"
        proxmox_vm_lifecycle_state: "absent"
```

Example — chaining with proxmox_disk and lvm2_provision
-----------------------------------------------------------

```yaml
- name: Provision VM
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_vm
      vars:
        proxmox_vm_do_clone: true
        # ... clone vars ...

- name: Add data disk and set up LVM
  hosts: newhost01           # requires the new host to already be in inventory
  gather_facts: true
  become: true
  roles:
    - role: mgcdrd.infrabase.proxmox_disk
      vars:
        proxmox_api_host: "pve2.example.com"
        proxmox_disk_vm_name:  "newhost01"
        # ... disk vars ...
```


Notes
-----

- **No handlers**: every module call is idempotent against PVE's own state;
  nothing needs restarting on the controller side.
- **`delegate_to: localhost`**: every task in this role talks to the PVE API,
  not the inventory host — the role is meant to be run with `hosts: localhost`
  (see examples above), but tasks delegate explicitly anyway so it also works
  correctly if invoked from a play targeting other hosts.
- **VMID uniqueness**: as with `proxmox_disk`, if multiple VMs share a name
  across PVE nodes, `lifecycle.yml`/`to_template.yml` fail rather than guess.
- **Linked clones**: `proxmox_vm_full_clone: false` only works when
  `proxmox_vm_clone_source` is itself a PVE template, not a regular VM.
