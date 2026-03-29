podman
======

Installs Podman from the base OS repositories and enables the Podman socket.
No external repository configuration is required — Podman is available in the
default repos on all supported platforms.

Primarily intended for standalone container hosts. Not recommended for
Kubernetes nodes without additional CRI shim configuration.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` and `gather_facts: true` are required.


Role Variables
--------------

None. Podman requires no version pinning or external repository.


Installed Packages
------------------

- `podman`
- `podman-compose`


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Install Podman
  hosts: container_hosts
  become: true
  roles:
    - role: mgcdrd.infrabase.podman
```

Called from another role:

```yaml
- name: Install container runtime
  ansible.builtin.include_role:
    name: mgcdrd.infrabase.podman
  when: k8s_container_runtime == 'podman'
```


Notes
-----

- `podman.socket` is enabled for rootful (system-level) container access.
  Rootless Podman per-user setup is not managed by this role.
- Podman is not CRI-compliant. Using it with Kubernetes requires the
  `crun` or `runc` OCI runtime and additional configuration not handled
  here.
