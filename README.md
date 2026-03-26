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
| `docker` | Installs the latest Docker CE (Debian 12/13, Rocky 9/10) |
| `etc_hosts` | Manages `/etc/hosts` entries |
| `lvm2` | Extends existing LVM logical volumes and volume groups (supports threshold-based automation) |
| `lvm2_provision` | Provisions LVM storage at setup time — creates VGs, LVs, filesystems, and mounts |
| `postfix` | Installs and configures Postfix MTA |
| `ssl_scripting` | Deploys SSL certificate scripting utilities |

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
    source: https://GITLAB_URL/ansible/collections/infrabase.git
    type: git
    version: v0.2.0