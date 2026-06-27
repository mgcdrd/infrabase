hardened_services
=================

Hardens system service configuration across three areas, each independently
toggleable:

| Feature | Default | What it does |
|---------|---------|--------------|
| `hardened_services_disable_nfs` | `true` | Disables and masks the NFS server service |
| `hardened_services_emergency_auth` | `true` | Requires sulogin for emergency/rescue systemd targets |
| `hardened_services_chronyd_user` | `true` | Ensures chronyd runs as an unprivileged user |

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. Facts (`gather_facts: true`) are required for
OS-family branching (chronyd task).


Role Variables
--------------

| Variable | Default | Description |
|---|---|---|
| `hardened_services_disable_nfs` | `true` | Disable and mask NFS server. Set to `false` on intentional NFS server hosts. |
| `hardened_services_emergency_auth` | `true` | Write drop-in overrides requiring `sulogin` for `emergency.service` and `rescue.service`. |
| `hardened_services_chronyd_user` | `true` | Set `OPTIONS="-u chrony"` (RedHat) or `OPTIONS="-u _chrony"` (Debian). Set to `false` if chrony is not installed. |


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Harden system services
  hosts: all
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.hardened_services
```

NFS server hosts — disable everything except NFS:

```yaml
- name: Harden system services
  hosts: nfs_servers
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.hardened_services
      vars:
        hardened_services_disable_nfs: false
```

Hosts without chrony installed:

```yaml
- name: Harden system services
  hosts: containers
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.hardened_services
      vars:
        hardened_services_chronyd_user: false
```


Notes
-----

- **NFS**: Uses `failed_when: false` — if the NFS server package is not
  installed, the task is silently skipped rather than failing.
- **Emergency/rescue targets**: Uses systemd drop-ins under
  `/etc/systemd/system/{emergency,rescue}.service.d/override.conf` rather than
  modifying vendor unit files. A `daemon-reload` is triggered on change.
  The `ExecStart=` blank line is required to clear the inherited value before
  setting the new one.
- **Chronyd**: Uses `failed_when: false` — if the chrony config file is absent
  (not installed), the task is silently skipped. The Debian user is `_chrony`;
  the RedHat user is `chrony`.
