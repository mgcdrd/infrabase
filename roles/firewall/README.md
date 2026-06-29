firewall
========

Installs and configures a host-based firewall with a default-deny inbound
policy. Addresses CIS Benchmark 3.4 (RHEL) and 3.5 (Debian).

| OS family | Tool | Management |
|-----------|------|------------|
| RedHat    | `firewalld` | `ansible.posix.firewalld` module — additive; adds rules, never removes |
| Debian    | `nftables` | Template-managed `/etc/nftables.conf` — full ruleset replaced on every run |

Default policy: drop inbound, accept outbound, accept established/related,
accept loopback, accept ICMP.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` and `gather_facts: true` are required.

`ansible.posix` collection must be installed (included in `ansible-base-ee`).


Role Variables
--------------

| Variable | Default | Description |
|---|---|---|
| `firewall_allowed_tcp_ports` | `[22]` | TCP ports to allow inbound. Applied on both OS families. |
| `firewall_allowed_udp_ports` | `[]` | UDP ports to allow inbound. |
| `firewall_allowed_services` | `[]` | firewalld named services to allow (e.g. `http`, `https`). **RedHat only.** |
| `firewall_default_zone` | `public` | firewalld zone to configure. **RedHat only.** |

On Debian, `firewall_allowed_services` is ignored — use ports only for
cross-platform playbooks.


Dependencies
------------

- `ansible.posix` (for `ansible.posix.firewalld` on RedHat)


Example Playbook
----------------

Basic server — SSH only:

```yaml
- name: Apply host firewall
  hosts: all
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.firewall
```

Web server — SSH, HTTP, HTTPS:

```yaml
- name: Apply host firewall
  hosts: web_servers
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.firewall
      vars:
        firewall_allowed_tcp_ports: [22, 80, 443]
```

Kubernetes API node (port-based, works on both OS families):

```yaml
firewall_allowed_tcp_ports:
  - 22
  - 6443    # kube-apiserver
  - 2379    # etcd client
  - 2380    # etcd peer
  - 10250   # kubelet
```

Keycloak cluster (RedHat, using named services + ports):

```yaml
firewall_allowed_tcp_ports:
  - 22
  - 8080
  - 8443
  - 7800    # JGroups cluster communication
firewall_allowed_services:
  - http
  - https
```

Custom zone (RedHat only):

```yaml
firewall_default_zone: dmz
firewall_allowed_tcp_ports: [22, 443]
```


Notes
-----

- **RedHat / additive behaviour**: `ansible.posix.firewalld` adds ports and
  services but does not remove ones that were previously configured. If you
  remove a port from `firewall_allowed_tcp_ports`, run `firewall-cmd
  --remove-port=<port>/tcp --permanent` manually or re-run with an explicit
  revoke task.
- **Debian / atomic behaviour**: The nftables ruleset is fully replaced from
  the template on every run. Removing a port from the list takes effect
  immediately on the next play.
- **SSH lockout**: The default `firewall_allowed_tcp_ports: [22]` keeps SSH
  open. If your `sshd_port` differs from 22, override this list or you will
  lose access when the firewall applies.
- **firewalld zones**: The role configures the default zone. If your host has
  interfaces in multiple zones, manage those zones separately via
  `ansible.posix.firewalld` in a wrapper playbook.
- **nftables on RHEL**: firewalld uses nftables as its backend on RHEL 8+.
  Do not install a separate nftables ruleset alongside firewalld on RHEL — the
  two will conflict.
