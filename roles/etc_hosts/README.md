etc_hosts
=========

A role to populate `/etc/hosts` with cluster peer entries and optional static entries.
Designed for deployments (Kubernetes, HAProxy, Galera, etc.) where each node needs
reliable peer name resolution without depending on DNS.

Cluster entries are auto-populated from inventory facts. Static entries can be defined
manually for infrastructure hostnames outside the managed inventory (shared storage,
registries, external services, etc.).

All entries are written as distinct Ansible-managed blocks, so re-running the role is
fully idempotent and multiple clusters in the same inventory coexist without conflict.

Tested on: Debian 12/13, Rocky Linux 9/10

Requirements
------------

Role uses only builtin modules and does not require additional collections.

`gather_facts: true` is required as host IP and hostname facts are used to populate
the `/etc/hosts` entries.


Role Variables
--------------

```yaml
# Inventory group whose members will be written into /etc/hosts on every host in the play.
# If left empty, cluster node entries are skipped for that host.
# Set this in group_vars for the cluster group so only those hosts manage peer entries.
etc_hosts_group: ""

# Ansible facts key for the network interface used to resolve each host's IP address.
# Override if your cluster nodes communicate over a dedicated interface rather than
# the default route interface.
# Examples:
#   etc_hosts_interface: ansible_default_ipv4   # default route interface (default)
#   etc_hosts_interface: ansible_eth1           # second ethernet
#   etc_hosts_interface: ansible_bond0          # bonded interface
etc_hosts_interface: ansible_default_ipv4

# ---- STATIC ENTRIES ----

# Additional entries to write into /etc/hosts on every host in the play.
# Written as a separate managed block — coexists with cluster node entries.
# Each entry requires 'ip' and 'hostname'. 'aliases' is optional.
# Note: Ansible does not merge lists across variable files. If this is defined
# in multiple places (group_vars, host_vars), only the highest-precedence value
# applies — definitions are not concatenated.
etc_hosts_entries: []
# etc_hosts_entries:
#   - ip: 10.0.0.1
#     hostname: storage.internal
#   - ip: 10.0.0.2
#     hostname: registry.internal
#     aliases: registry
```


Dependencies
------------

No additional dependencies are required.


Example Playbook
----------------

Make sure to set `gather_facts: true` as host IP and hostname facts are required by the role.

**Targeting a specific cluster group:**

```yaml
- name: Configure cluster hosts file
  hosts: all
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.etc_hosts

# group_vars/k8s_nodes.yml
etc_hosts_group: k8s_nodes
```

**Cluster on a dedicated network interface:**

```yaml
etc_hosts_group: galera_nodes
etc_hosts_interface: ansible_eth1
```

**Multiple clusters — run the role twice with different groups:**

```yaml
- name: Configure hosts files for all clusters
  hosts: all
  gather_facts: true
  become: true
  tasks:
    - name: Add k8s nodes
      ansible.builtin.include_role:
        name: mgcdrd.infrabase.etc_hosts
      vars:
        etc_hosts_group: k8s_nodes

    - name: Add haproxy nodes
      ansible.builtin.include_role:
        name: mgcdrd.infrabase.etc_hosts
      vars:
        etc_hosts_group: haproxy_nodes
```

Each `include_role` call writes a separate managed block tagged with the group name,
so the two clusters' entries do not overwrite each other.

**Static infrastructure entries — defined in group_vars/all.yml:**

```yaml
etc_hosts_entries:
  - ip: 10.0.0.10
    hostname: storage.internal
  - ip: 10.0.0.11
    hostname: registry.internal
    aliases: registry
```

**Combining cluster peers and static entries:**

```yaml
- name: Configure hosts file
  hosts: k8s_nodes
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.etc_hosts

# group_vars/all.yml — static entries written on every host
etc_hosts_entries:
  - ip: 10.0.0.10
    hostname: storage.internal

# group_vars/k8s_nodes.yml
etc_hosts_group: k8s_nodes
```

