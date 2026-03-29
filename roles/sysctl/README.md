sysctl
======

Applies a list of sysctl parameters and persists them to a file under
`/etc/sysctl.d/`. Calls `sysctl --system` immediately after writing so changes
take effect without a reboot.

Designed to be called by other roles rather than directly — each caller should
pass a distinct `sysctl_conf_file` so multiple roles can manage separate
parameter sets on the same host without overwriting each other.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.


Role Variables
--------------

### `sysctl_params`

List of parameters to apply. Each entry requires `name` and `value` keys.
Defaults to an empty list (role is a no-op if not set).

```yaml
sysctl_params:
  - { name: net.ipv4.ip_forward,                 value: 1 }
  - { name: net.bridge.bridge-nf-call-iptables,  value: 1 }
  - { name: net.bridge.bridge-nf-call-ip6tables, value: 1 }
  - { name: vm.swappiness,                       value: 10 }
```

### `sysctl_conf_file`

Path to the file written under `/etc/sysctl.d/`. Defaults to
`/etc/sysctl.d/ansible-managed.conf`.

**Always override this when calling from another role** to avoid two roles
stomping on the same file. Use a name that reflects the caller:

| Caller role     | Recommended value                    |
|-----------------|--------------------------------------|
| k8s             | `/etc/sysctl.d/kubernetes.conf`      |
| GPU node tuning | `/etc/sysctl.d/gpu.conf`             |
| Network harden  | `/etc/sysctl.d/hardening.conf`       |

```yaml
sysctl_conf_file: /etc/sysctl.d/kubernetes.conf
```


Dependencies
------------

None.


Example Playbook
----------------

Direct use:

```yaml
- name: Apply network sysctl hardening
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.sysctl
      vars:
        sysctl_conf_file: /etc/sysctl.d/hardening.conf
        sysctl_params:
          - { name: net.ipv4.ip_forward,    value: 0 }
          - { name: net.ipv4.tcp_syncookies, value: 1 }
```

Called from another role:

```yaml
- name: Configure sysctl for k8s
  ansible.builtin.include_role:
    name: mgcdrd.infrabase.sysctl
  vars:
    sysctl_params:    "{{ k8s_sysctl }}"
    sysctl_conf_file: /etc/sysctl.d/kubernetes.conf
```


Notes
-----

- Multiple roles can safely call this on the same host as long as each uses a
  distinct `sysctl_conf_file`.
- Parameters are written exactly as given — no validation is performed. Invalid
  parameter names will cause `sysctl --system` to emit warnings but will not
  fail the play.
- The role is a no-op when `sysctl_params` is empty.
