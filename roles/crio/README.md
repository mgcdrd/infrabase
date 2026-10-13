crio
====

Installs CRI-O from the official repository and ensures the service is enabled
and running. Intended for use with Kubernetes — `crio_version` should match
the Kubernetes minor version.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` and `gather_facts: true` are required.


Role Variables
--------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `crio_version` | `""` | Yes | CRI-O minor version used to build the repo URLs (e.g. `"1.32"`); match the Kubernetes minor version |


### `crio_version`

CRI-O minor version used to form the repository URL. **Required.**

Should match the Kubernetes minor version (e.g. `"1.32"` for Kubernetes 1.32).

```yaml
crio_version: "1.32"
```

Repository sources by OS:

| OS      | Source                                                                   |
|---------|--------------------------------------------------------------------------|
| Debian  | `download.opensuse.org/repositories/isv:/cri-o:/stable:/v<version>/deb/` |
| RedHat  | `download.opensuse.org/repositories/isv:/cri-o:/stable:/v<version>/rpm/` |



Dependencies
------------

None.


Example Playbook
----------------

Standalone:

```yaml
- name: Install CRI-O
  hosts: k8s_nodes
  become: true
  roles:
    - role: mgcdrd.infrabase.crio
      vars:
        crio_version: "1.32"
```

Called from another role:

```yaml
- name: Install container runtime
  ansible.builtin.include_role:
    name: mgcdrd.infrabase.crio
  vars:
    crio_version: "{{ k8s_version }}"
  when: k8s_container_runtime == 'cri-o'
```
