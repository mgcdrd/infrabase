# Ansible Collection - mgcdrd.infrabase

An Ansible collection providing reusable base roles that can be included in higher level roles, such a service installations/configurations. Not necessarily intended for sole use, but can be.

## Overview

This collection contains common infrastructure roles used to standardize and automate:

- Base system operations
- Higher level roles to minimize code rewriting
- Shared utilities and filters

## Roles

| Role | Description |
|------|-------------|
| `acme_sh` | Installs acme.sh and manages ACME certificates (Let's Encrypt, ZeroSSL, EAB) via DNS or HTTP challenges |
| `aide` | Installs AIDE and configures filesystem integrity monitoring with a daily cron check |
| `auditd` | Installs auditd with CIS-aligned audit rules — syscall groups, watchpoints, and conf settings are variable-driven |
| `crio` | Installs CRI-O container runtime, version-pinned to the Kubernetes minor version |
| `cron` | CIS cron access hardening — removes `cron.deny`, creates `cron.allow` |
| `cron_jobs` | Manages per-user crontab entries from a variable list — generic, not tied to a deployment |
| `docker` | Installs the latest Docker CE (Debian 12/13, Rocky 9/10) |
| `etc_hosts` | Manages `/etc/hosts` entries |
| `file_deploy` | Deploys arbitrary files, templates, and directories with explicit owner/group/mode — generic, not tied to a deployment |
| `kernel_modules` | Loads and persists kernel modules; optionally blacklists modules via `/etc/modprobe.d/` |
| `lvm2` | Extends existing LVM logical volumes and volume groups (supports threshold-based automation) |
| `lvm2_provision` | Provisions LVM storage at setup time — creates VGs, LVs, filesystems, and mounts |
| `podman` | Installs Podman container runtime |
| `postfix` | Installs and configures Postfix MTA |
| `proxmox_access` | Manages ProxMox VE users, groups, IAM roles, ACLs, and auth realms via the PVE API |
| `proxmox_acme` | Manages ACME certificates for the PVE node's own web UI (pveproxy) via the PVE API |
| `proxmox_backup` | Manages ProxMox VE backup jobs, VM job membership, and on-demand backups via the PVE API |
| `proxmox_ceph` | Manages ProxMox VE-integrated Ceph monitors/managers/MDS, OSDs, and pools via the PVE API |
| `proxmox_cluster` | Creates a ProxMox VE cluster and joins additional nodes to it via the PVE API |
| `proxmox_disk` | Adds or resizes a disk on a ProxMox VM via the PVE API, then detects the resulting block device inside the VM |
| `proxmox_firewall` | Manages ProxMox VE's built-in firewall — options, rules, security groups, aliases, IP sets — via the PVE API |
| `proxmox_ha` | Manages ProxMox VE High Availability groups, resources, and node/resource-affinity rules via the PVE API |
| `proxmox_lxc` | Creates, clones, lifecycle-manages, and templates LXC containers via the ProxMox API |
| `proxmox_network` | Manages node-level physical network interfaces (bridges/bonds/VLANs/OVS) via the PVE API |
| `proxmox_node` | Manages ProxMox VE node power state, certificates/DNS/subscription config, and task monitoring via the PVE API |
| `proxmox_pool` | Creates/deletes ProxMox VE resource pools and manages VM/storage pool membership via the PVE API |
| `proxmox_sdn` | Manages ProxMox VE Software-Defined Networking — zones, vnets, and subnets — via the PVE API |
| `proxmox_snapshot` | Creates, deletes, and rolls back ProxMox VE VM/CT snapshots via the PVE API |
| `proxmox_storage` | Creates/deletes ProxMox VE storage backend definitions (NFS/CIFS/dir/iSCSI/CephFS/RBD/PBS/ZFS) via the PVE API |
| `proxmox_vm` | Clones, lifecycle-manages, and templates VMs via the ProxMox API; queries cluster/node/storage info |
| `sshd` | Installs and configures sshd with hardened defaults; crypto policy managed via `sshd_config.d/` drop-in |
| `ssl_scripting` | Deploys SSL certificate scripting utilities |
| `sudoers` | Hardens `/etc/sudoers` — enforces `timestamp_timeout` and configures a sudo log file |
| `sysctl` | Writes sysctl parameters to `/etc/sysctl.d/` and applies them |
| `firewalld` | *(planned)* Manage firewalld zones, services, ports, and rich rules idempotently |

It is designed for use with:
- Ansible Core >= 2.14
- AWX / Automation Controller
- Execution Environments

---

## ProxMox API connection

Every `proxmox_*` role talks to the PVE API through the exact same six
variables — there's no role-prefixed variant of these anymore:

```yaml
proxmox_api_host: "pve2.example.com"   # any PVE node — it manages the whole cluster
proxmox_api_user: "root@pam"
proxmox_api_password: "{{ vault_proxmox_api_password }}"
# or, recommended:
proxmox_api_token_id: "{{ vault_proxmox_api_token_id }}"
proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
proxmox_validate_certs: false
```

A VM/CT lives on one node in one cluster — it never has a different API
endpoint or credential depending on which `proxmox_*` role happens to be
acting on it, so there's nothing to override per role. Set these once
(deployment `group_vars`/`vault.yml`, or `inventory-common` group_vars for
a shared PVE cluster group) and every role in a play picks them up.
Multiple PVE clusters are an inventory concern — a different host group
with its own `proxmox_api_host` etc., not a per-role variable — see
`inventory-common/README.md`.

None of these vars have a collection-level default (the same way
`vault_proxmox_api_password` never has). `proxmox_api_host`/`proxmox_api_user`/
`proxmox_validate_certs` fail loudly with an "undefined variable" error if
unset — there's no sensible default for an endpoint/cluster identity, and
guessing wrong would mean silently talking to the wrong cluster.
`proxmox_api_password`/`proxmox_api_token_id`/`proxmox_api_token_secret`
are deliberately different: pick **one** auth method and leave the other
pair unset — every task wraps them in `| default(omit)`, so the unused
pair is simply never sent to the module rather than causing a crash or a
`required_one_of` error demanding you also populate a method you don't
want.

**One documented exception:** `proxmox_acme` (ACME account/plugin/certificate
management) is a hard PVE API restriction to `root@pam` password auth —
tokens are rejected outright. It does not use the shared
`proxmox_api_password`/`proxmox_api_token_id` for those tasks; it has its
own `proxmox_acme_api_password`. If it shared the connection vars, setting
a password to satisfy `proxmox_acme` would silently switch every other
`proxmox_*` role in the same play from token auth to password auth too
(the underlying module always prefers password over token when both are
present, with no way to force token). See that role's README.

`proxmox_disk`/`proxmox_nic`/`proxmox_vm_manage` also target a specific VM
by name — that one's legitimately per-invocation (a play can manage
several different VMs), so it stays a role-prefixed var defaulting from
the shared `proxmox_target_vm_name` — see each role's own README for
"VM targeting".

---

## Installation

### From Git (recommended for internal use)

Add to `collections/requirements.yml`:

```yaml
collections:
  - name: mgcdrd.infrabase
    source: https://github.com/mgcdrd/infrabase.git
    type: git
    version: v0.4.0