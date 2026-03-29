kernel_modules
==============

Loads kernel modules immediately and persists them across reboots by writing
individual `.conf` files to `/etc/modules-load.d/` via `community.general.modprobe`.

Designed to be called by other roles rather than directly. Multiple roles can
call this on the same host safely — each module gets its own file so runs are
purely additive. Previously loaded modules are never removed by a subsequent
call with a different list.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.

The `community.general` collection must be installed:

```bash
ansible-galaxy collection install community.general
```


Role Variables
--------------

### `kernel_modules_list`

List of module names to load and persist. Defaults to an empty list (role is a
no-op if not set).

```yaml
kernel_modules_list:
  - br_netfilter
  - overlay
```


Dependencies
------------

- `community.general.modprobe`


Example Playbook
----------------

Direct use:

```yaml
- name: Load storage modules
  hosts: storage_nodes
  become: true
  roles:
    - role: mgcdrd.infrabase.kernel_modules
      vars:
        kernel_modules_list:
          - dm_thin_pool
          - dm_cache
```

Called from another role:

```yaml
- name: Load required kernel modules
  ansible.builtin.include_role:
    name: mgcdrd.infrabase.kernel_modules
  vars:
    kernel_modules_list: "{{ k8s_modules }}"
```


Notes
-----

- Each module is persisted as its own file, e.g.
  `/etc/modules-load.d/br_netfilter.conf`. This means calling this role
  multiple times with different lists on the same host is safe — modules
  accumulate rather than being replaced.
- Module removal is not supported by this role. To unload a module, use
  `community.general.modprobe` with `state: absent` directly.
- The role is a no-op when `kernel_modules_list` is empty.
