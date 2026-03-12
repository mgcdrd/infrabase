Role Name
=========

Role looks for a group all hosts are a part of and adds all host in any group to the /etc/hosts on all hosts.

Requirements
------------

No external requirements are needed for this role.

Role Variables
--------------

Does not have variables.  Role uses the inventory file, gathered_facts, and becomes for root permissions.

Dependencies
------------

Hosts need to be in the same group in the inventory.

Example Playbook
----------------

```
# inventory excerpt
[cluster members]
node1
node2
node3
```

```
# playbook example
  - hosts: servers
    becomes: true
    gather_facts: true
    roles:
    - mgcdrd.infrabase.etc_hosts
```

License
-------

GPL-3.0-or-laterBSD

