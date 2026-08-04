docker
======

Installs Docker CE from Docker's official repository, ensures the service is
enabled and running, and sets the default container logging driver.

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

### `docker_log_driver` / `docker_syslog_facility`

Deploys `/etc/docker/daemon.json` setting the default logging driver for
every container on this host (`log-driver`, default `syslog`) and, for the
syslog driver, which facility it tags messages with (`docker_syslog_facility`,
default `local3`) — targets the local rsyslog socket
(`unixgram:///dev/log`), tagged per-container via Docker's `{{.Name}}`
template, so it flows through the same rsyslog forwarding as everything
else. See `mgcdrd.infrabase.rsyslog`'s README for how `local3` gets routed
centrally.

```yaml
docker_log_driver: syslog
docker_syslog_facility: local3
```

**Trade-offs to know before enabling on a host with running containers:**
- `docker logs <container>` does not work with the `syslog` driver — the
  CLI can only read back from `json-file`/`local`. Read the centralized copy
  on the syslog server instead.
- The log driver is set at container *create* time. Existing containers
  (e.g. dockerized PostgreSQL/Galera) need to be recreated —
  `docker compose up -d --force-recreate` or equivalent — to pick this up;
  the role does not do this automatically.

Set `docker_log_driver: json-file` to opt a host out and keep Docker's
default behavior.


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
