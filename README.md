# Ansible Collection - mgcdrd.infrabase

An Ansible collection providing reusable base roles that can be included in higher level roles, such a service installations/configurations. Not necessarily intended for sole use, but can be.

## Overview

This collection contains common infrastructure roles used to standardize and automate:

- Base system operations
- Higher level roles to minimize code rewriting
- Shared utilities and filters

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