proxmox_lxc
===========

Manages LXC container lifecycle in ProxMox VE via its REST API: create a
container from a template, clone one from an existing container, start/stop/
restart/destroy an existing container, convert a container into a template,
and query cluster/node/storage info. Parallels `mgcdrd.infrabase.proxmox_vm`
but for containers instead of QEMU VMs.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 1.4.0` — the SDN/network
  modules used elsewhere in this collection landed there; the LXC module
  itself has been present since the collection's first release).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset.
These are the same `proxmox_api_token_id`/`_secret`/`_user`/`_password`
vars every `proxmox_*` role uses — set them once, not per role:

```yaml
# API token (recommended)
proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"

# Password
proxmox_api_user:     "root@pam"
proxmox_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`, so only the pair you configure
is ever sent to the module. Grant the token at minimum `VM.Allocate`,
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

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_lxc_do_info` | `false` | `info` | Cluster/node/storage lookup |
| `proxmox_lxc_do_create` | `false` | `create` | Create a new container from a vztmpl |
| `proxmox_lxc_do_clone` | `false` | `clone` | Clone + start a new container from an existing one |
| `proxmox_lxc_do_lifecycle` | `false` | `lifecycle` | Start/stop/restart/destroy an existing container |
| `proxmox_lxc_do_template` | `false` | `template` | Convert a container into a template |

### info

No variables required. Sets facts:

| Fact | Source |
|---|---|
| `proxmox_lxc_cluster_status` | `community.proxmox.proxmox_cluster_status_info` |
| `proxmox_lxc_node_facts` | `community.proxmox.proxmox_node_info` |
| `proxmox_lxc_storage_facts` | `community.proxmox.proxmox_storage_info` |

### create

```yaml
proxmox_lxc_node:       "pve2"
proxmox_lxc_hostname:   "newct01"
proxmox_lxc_ostemplate: "local:vztmpl/rockylinux-9-default_20240523_amd64.tar.xz"
proxmox_lxc_password:   "{{ vault_proxmox_lxc_password }}"
proxmox_lxc_storage:    "local-lvm"
proxmox_lxc_disk_size:  "8"      # GiB, no suffix
proxmox_lxc_cores:      2
proxmox_lxc_memory:     1024
proxmox_lxc_swap:       512
proxmox_lxc_net0:       "name=eth0,bridge=vmbr0,ip=dhcp"
proxmox_lxc_pubkey:     "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
proxmox_lxc_unprivileged: true
proxmox_lxc_features:   ["nesting=1"]
proxmox_lxc_tags:       ["lab"]
```

`proxmox_lxc_vmid` defaults to `""`, letting PVE assign the next free VMID.
`proxmox_lxc_storage`/`proxmox_lxc_disk_size` are combined into the PVE
`disk` string (`storage:size`) — the underlying module treats `disk` and
`storage` as alternate ways to target the rootfs, so this role only ever
sends `disk`.

### clone

```yaml
proxmox_lxc_clone_source_name: "rocky9-lxc-template"   # looked up by name
proxmox_lxc_clone_hostname:    "newct02"
proxmox_lxc_clone_node:        ""       # "" = same node as the source
proxmox_lxc_clone_type:        "opportunistic"   # full | linked | opportunistic
proxmox_lxc_clone_storage:     "local-lvm"        # required for a full clone
```

`clone_type: linked` only works when the source container is itself a PVE
template. `opportunistic` (the module default) does a linked clone when the
source is a template and a full clone otherwise.

### lifecycle

```yaml
proxmox_lxc_target_name:     "oldct01"       # looked up by name via proxmox_vm_info
proxmox_lxc_lifecycle_state: "absent"        # started | stopped | restarted | absent
proxmox_lxc_force_stop:      false           # stopped only — skip graceful shutdown
proxmox_lxc_purge:           false           # absent only — remove from backup/replication/HA
proxmox_lxc_destroy_unreferenced_disks: true # absent only
```

Fails if zero or multiple containers match `proxmox_lxc_target_name` — same
discovery pattern as `proxmox_vm`.

### template

```yaml
proxmox_lxc_template_source_name: "rocky9-lxc-golden"
proxmox_lxc_template_force:       true   # stop the container first if running
```


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_lxc` | Entire role |
| `info` | Cluster/node/storage lookup |
| `create` | Create from vztmpl |
| `clone` | Clone + start |
| `lifecycle` | Start/stop/restart/destroy |
| `template` | Convert to template |


Example Playbook — create a container from a template
-------------------------------------------------------

```yaml
- name: Provision a new LXC container
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_lxc
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_lxc_do_create: true
        proxmox_lxc_node:       "pve2"
        proxmox_lxc_hostname:   "newct01"
        proxmox_lxc_ostemplate: "local:vztmpl/rockylinux-9-default_20240523_amd64.tar.xz"
        proxmox_lxc_password:   "{{ vault_proxmox_lxc_password }}"
        proxmox_lxc_storage:    "local-lvm"
        proxmox_lxc_disk_size:  "8"
        proxmox_lxc_cores:      2
        proxmox_lxc_memory:     1024
        proxmox_lxc_pubkey:     "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

Example Playbook — clone a container
--------------------------------------

```yaml
- name: Clone an LXC container from a template
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_lxc
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_lxc_do_clone: true
        proxmox_lxc_clone_source_name: "rocky9-lxc-template"
        proxmox_lxc_clone_hostname:    "newct02"
        proxmox_lxc_clone_type:        "linked"
```

Example Playbook — tear down a container
--------------------------------------------

```yaml
- name: Remove a decommissioned container
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_lxc
      vars:
        proxmox_api_host:         "pve2.example.com"
        proxmox_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_lxc_do_lifecycle: true
        proxmox_lxc_target_name: "oldct01"
        proxmox_lxc_lifecycle_state: "absent"
```


Notes
-----

- **`delegate_to: localhost`**: every task in this role talks to the PVE API,
  not the inventory host — run with `hosts: localhost`, as in the examples.
- **VMID uniqueness**: if multiple containers share a name across PVE nodes,
  `clone.yml`/`lifecycle.yml`/`to_template.yml` fail rather than guess.
- **`netif` is a raw string per interface** (`net0: "name=eth0,..."`), the
  same convention `proxmox_vm` uses for `net0` — not a nested dict of
  individual keys.
- **`startup` (boot/shutdown ordering) is deliberately not exposed** by this
  role — the upstream module accepts it as a list of strings but its exact
  per-element format isn't documented anywhere in the module's own docs.
  Set it directly in PVE's UI/API if you need it, or open an issue if you
  need it added here once the format is confirmed.
- **No handlers**: every module call is idempotent against PVE's own state.
