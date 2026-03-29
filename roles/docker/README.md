docker
======

Installs Docker CE from Docker's official repository and ensures the service
is enabled and running.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` and `gather_facts: true` are required.


Role Variables
--------------

### `docker_apt_arch`

Architecture string for the apt repository URL. Auto-detected from
`ansible_architecture`. Only relevant on Debian.

| `ansible_architecture` | `docker_apt_arch` |
|------------------------|-------------------|
| `x86_64`               | `amd64`           |
| `aarch64`              | `arm64`           |
| other                  | passed through    |

Override only if auto-detection produces the wrong value:

```yaml
docker_apt_arch: amd64
```


Installed Packages
------------------

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Install Docker
  hosts: container_hosts
  become: true
  roles:
    - role: mgcdrd.infrabase.docker
```

Called from another role:

```yaml
- name: Install container runtime
  ansible.builtin.include_role:
    name: mgcdrd.infrabase.docker
  when: k8s_container_runtime == 'docker'
```


Notes
-----

- Docker is not CRI-compliant out of the box. Using it with Kubernetes requires
  the `cri-dockerd` shim, which is not managed by this role.
- The `docker-compose-plugin` provides `docker compose` (v2). The standalone
  `docker-compose` (v1) binary is not installed.
