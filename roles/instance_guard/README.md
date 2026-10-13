instance_guard
==============

Pre-flight check for deployments whose inventory is split into per-instance
directories (`inventory-common/instances/<service>/<name>/`). Ansible merges
every loaded source into one group, so loading two instances at once applies
the last one's group_vars to every host in the group. This role turns that
into a hard failure, and also fails when no hosts match at all (which
`ansible-playbook` otherwise reports as a passing run).

Runs against `localhost` in its own play, so it can still fail when the
target group is empty. Tag it `always` so `--tags` runs don't skip it.

Requirements
------------

Builtin modules only. `gather_facts: false` is fine.

Role Variables
--------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `instance_guard_group` | `""` | Yes | Inventory group the deployment targets (e.g. `k8s`); the role fails if empty |
| `instance_guard_var` | `instance_name` | No | Host variable naming the instance a host belongs to; set it in a per-instance group, not on the shared group |


Example
-------

```yaml
- name: Guard - one instance only
  hosts: localhost
  connection: local
  gather_facts: false
  tags: [always]
  roles:
    - role: mgcdrd.infrabase.instance_guard
      vars:
        instance_guard_group: k8s
```

Fleet-wide deployments that intentionally span instances (e.g. `harden`)
should not use this role.

Tested on: Debian 12/13, Rocky Linux 9/10
