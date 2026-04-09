kernel_modules
==============

Loads kernel modules immediately and persists them across reboots by writing
individual `.conf` files to `/etc/modules-load.d/` via `community.general.modprobe`.

Also supports blacklisting modules — writes `blacklist` and `install /bin/false`
entries to `/etc/modprobe.d/ansible-blacklist.conf` to prevent both autoloading
and manual loading.

Designed to be called by other roles rather than directly. Multiple roles can
call this on the same host safely — each module gets its own file so load runs
are purely additive. Previously loaded modules are never removed by a subsequent
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

List of module names to load and persist. Defaults to an empty list (no-op).

```yaml
kernel_modules_list:
  - br_netfilter
  - overlay
```

### `kernel_modules_blacklist`

List of module names to blacklist. Each entry generates two lines in
`/etc/modprobe.d/ansible-blacklist.conf`:

```
blacklist <module>
install <module> /bin/false
```

`blacklist` prevents autoloading. `install /bin/false` prevents manual loading
with `modprobe`. Both are needed for full enforcement.

```yaml
kernel_modules_blacklist:
  - dccp
  - sctp
  - rds
  - tipc
  - cramfs
  - freevxfs
  - jffs2
  - hfs
  - hfsplus
  - squashfs
  - udf
  - usb-storage
```

Defaults to an empty list (no blacklist file is written).


Dependencies
------------

- `community.general.modprobe` (for loading modules)


Example Playbook
----------------

Load modules for Kubernetes:

```yaml
- name: Load k8s kernel modules
  hosts: k8s_nodes
  become: true
  roles:
    - role: mgcdrd.infrabase.kernel_modules
      vars:
        kernel_modules_list:
          - br_netfilter
          - overlay
```

Blacklist unused/unsafe protocols (CIS):

```yaml
- name: Blacklist unused kernel modules
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.kernel_modules
      vars:
        kernel_modules_blacklist:
          - dccp
          - sctp
          - rds
          - tipc
```

Called from another role:

```yaml
- name: Load required kernel modules
  ansible.builtin.include_role:
    name: mgcdrd.infrabase.kernel_modules
  vars:
    kernel_modules_list:    "{{ k8s_modules }}"
    kernel_modules_blacklist: "{{ k8s_blacklist | default([]) }}"
```


Notes
-----

- Each loaded module is persisted as its own file, e.g.
  `/etc/modules-load.d/br_netfilter.conf`. Load lists accumulate rather
  than being replaced across role calls.
- Module removal is not supported by this role. To unload a module, use
  `community.general.modprobe` with `state: absent` directly.
- The blacklist file is written atomically and replaces any previous version
  on each run — it is fully managed by this role.
- A reboot is required for blacklisted modules to be prevented from loading
  if they are currently loaded. The role does not reboot the host.
- The role is a no-op when both `kernel_modules_list` and
  `kernel_modules_blacklist` are empty.
