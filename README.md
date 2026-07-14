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
| `docker` | Installs the latest Docker CE (Debian 12/13, Rocky 9/10) |
| `etc_hosts` | Manages `/etc/hosts` entries |
| `kernel_modules` | Loads and persists kernel modules; optionally blacklists modules via `/etc/modprobe.d/` |
| `lvm2` | Extends existing LVM logical volumes and volume groups (supports threshold-based automation) |
| `lvm2_provision` | Provisions LVM storage at setup time — creates VGs, LVs, filesystems, and mounts |
| `podman` | Installs Podman container runtime |
| `postfix` | Installs and configures Postfix MTA |
| `proxmox_disk` | Adds or resizes a disk on a ProxMox VM via the PVE API, then detects the resulting block device inside the VM |
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

## Installation

### From Git (recommended for internal use)

Add to `collections/requirements.yml`:

```yaml
collections:
  - name: mgcdrd.infrabase
    source: https://github.com/mgcdrd/infrabase.git
    type: git
    version: v0.4.0