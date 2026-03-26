# docker

Installs the latest Docker CE from Docker's official repository.

## Supported Platforms

| OS              | Versions       |
|-----------------|----------------|
| Debian          | 12 (bookworm), 13 (trixie) |
| Rocky Linux     | 9, 10          |

## Installed Packages

- `docker-ce`
- `docker-ce-cli`
- `containerd.io`
- `docker-buildx-plugin`
- `docker-compose-plugin`

The Docker service is enabled and started automatically.

## Variables

| Variable         | Default                                              | Description                              |
|-----------------|------------------------------------------------------|------------------------------------------|
| `docker_apt_arch` | `amd64` (x86_64) / `arm64` (aarch64) | Architecture string for the apt repo URL |

## Example Playbook

```yaml
- hosts: all
  roles:
    - mgcdrd.infrasvc.docker
```
