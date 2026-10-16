qemu_guest_agent
================

Installs and enables `qemu-guest-agent` on Debian and RedHat family systems.

Package and service name are identical across both OS families — the only
branching needed is the package manager (`apt` vs `dnf`).

Idempotent: safe to run against a host that already has the agent installed
and running.

Tested on: Debian 12/13, Rocky Linux 9/10

Scope
-----

This role is for QEMU/Proxmox **VM guests only**. Do not apply it to
hypervisor nodes (`proxmox_ve` group) or bare-metal hosts — the agent has
nothing to talk to outside a QEMU guest.

Inside a container (LXC, `systemd-nspawn`, Docker) the role self-skips:
`qemu-guest-agent` needs a virtio-serial channel that only a full QEMU/KVM
guest exposes, so its service can't start in a container. Detection is on
`ansible_facts['virtualization_type']` / `virtualization_role`.

Requirements
------------

Role uses only builtin modules and does not require additional collections.

`gather_facts: true` is required as OS family facts are used to select the
correct package manager.

Role Variables
---------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `qemu_guest_agent_skip_in_container` | `true` | No | Skip the role when running inside a container (LXC, systemd-nspawn, Docker, etc.) |
| `qemu_guest_agent_container_virt_types` | *(list, 6 items)* | No | Virtualization types (ansible_facts['virtualization_type']) treated as a container for the skip above |


Otherwise the role applies the same install-and-enable behavior on every
supported OS family.

Dependencies
------------

No additional dependencies are required.

Example Playbook
-----------------

```yaml
- name: Install and enable qemu-guest-agent
  hosts: all:!proxmox_ve
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.qemu_guest_agent
```

License
-------

GPL-3.0-or-later
