proxmox_guest_exec
===================

Runs a command inside a VM through the QEMU guest agent channel, via the
PVE API — not SSH. The command reaches the guest even if the VM has no
network path back to the controller (mid-VLAN-cutover, firewalled,
whatever), as long as `qemu-guest-agent` is installed and running (see
`mgcdrd.infrabase.qemu_guest_agent`).

No `community.proxmox` module wraps the guest agent exec endpoints
(confirmed against the 2.x module list) — this role talks to
`/nodes/{node}/qemu/{vmid}/agent/exec` and `/agent/exec-status` directly,
the same raw-`uri` + `PVEAPIToken` pattern `mgcdrd.infrabase.proxmox_backup`
uses for `/cluster/backup`.

Requirements
------------

- `community.proxmox` (VM-by-name lookup)
- **API token auth only.** `ansible.builtin.uri` can't perform PVE's
  login-ticket + CSRF flow, so `proxmox_api_token_id`/
  `proxmox_api_token_secret` must be set — password/ticket auth isn't
  supported by this role.
- The target VM must have `qemu-guest-agent` installed, running, and
  the corresponding `agent: 1` (or `agent: enabled=1`) option set on the
  VM in PVE, or the exec call will hang/fail.

Role Variables
---------------

```yaml
# By-name lookup (one API call) unless both of these are set explicitly —
# set both to skip the lookup, e.g. right after a proxmox_vm clone.
proxmox_guest_exec_vm_name: "{{ proxmox_target_vm_name | default(inventory_hostname) }}"
proxmox_guest_exec_vmid: ""
proxmox_guest_exec_node: ""

# List of argv strings — first element is the executable, rest are its
# args. No shell involved, so no quoting/injection concerns, but also no
# pipes/redirects/globbing — write a script to disk first (stdin +
# `tee`) if the operation needs any of that.
proxmox_guest_exec_command: []

# Optional data piped to the command's stdin.
proxmox_guest_exec_input_data: ""

# Fail the play if the command exits non-zero.
proxmox_guest_exec_fail_on_nonzero: true

# How long to wait for the command to finish, and how often to poll.
proxmox_guest_exec_timeout: 60
proxmox_guest_exec_poll_interval: 2

# Suppress request/response logging on the submit/poll tasks — command
# input-data and output routinely carry file contents. Set false only to
# debug a failing command.
proxmox_guest_exec_no_log: true
```

Result: `proxmox_guest_exec_result` is set to the final `agent/exec-status`
response (`exitcode`, `out-data`, `err-data`, etc.) for the caller to
inspect.

Example Playbook
-----------------

Write a file into the guest and apply it, entirely from the controller —
no SSH connection to the VM at any point:

```yaml
- name: Push a netplan config into a VM via guest agent
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Write the netplan file
      ansible.builtin.include_role:
        name: mgcdrd.infrabase.proxmox_guest_exec
      vars:
        proxmox_guest_exec_vm_name: kc1.lab.provenzawt.dev
        proxmox_guest_exec_command:
          - /usr/bin/tee
          - /etc/netplan/01-migrate.yaml
        proxmox_guest_exec_input_data: "{{ lookup('template', 'netplan.yaml.j2') }}"

    - name: Apply it
      ansible.builtin.include_role:
        name: mgcdrd.infrabase.proxmox_guest_exec
      vars:
        proxmox_guest_exec_vm_name: kc1.lab.provenzawt.dev
        proxmox_guest_exec_command:
          - /usr/sbin/netplan
          - apply
```

Dependencies
------------

`community.proxmox` (already a dependency of every other `proxmox_*` role
in this collection).

License
-------

GPL-3.0-or-later
