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

Multiple interfaces are supported: each zone in `firewall_zones` can specify
which interfaces it applies to. On RHEL, this maps directly to firewalld zone
assignment. On Debian, nftables rules are scoped with `iifname { ... }`.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` and `gather_facts: true` are required.

`ansible.posix` collection must be installed (included in `ansible-base-ee`).


Role Variables
--------------

### `firewall_default_zone`

The firewalld default zone. Traffic on interfaces not explicitly assigned to
a zone falls into this zone. **RedHat only.** Default: `public`.

### `firewall_zones`

List of zone definitions. Each zone controls which interfaces it applies to
and what traffic it permits.

| Key | Required | Description |
|-----|----------|-------------|
| `name` | yes | firewalld zone name (RedHat) or logical label (Debian) |
| `interfaces` | no | Interface names to assign to this zone. Empty = no explicit assignment (default zone). |
| `allowed_tcp_ports` | no | TCP ports to allow inbound on this zone's interfaces. |
| `allowed_udp_ports` | no | UDP ports to allow inbound on this zone's interfaces. |
| `allowed_services` | no | firewalld named services to allow (e.g. `http`, `https`). **RedHat only.** |

Default (single-interface, SSH only):

```yaml
firewall_zones:
  - name: public
    interfaces: []
    allowed_tcp_ports:
      - 22
    allowed_udp_ports: []
    allowed_services: []
```

On Debian, zones with an empty `interfaces` list apply their rules to all
interfaces. On RedHat, the zone must be set as default (via `firewall_default_zone`)
or assigned interfaces explicitly for its rules to take effect.


Dependencies
------------

- `ansible.posix` (for `ansible.posix.firewalld` on RedHat)


Example Playbook
----------------

**Single interface — SSH only (default):**

```yaml
- name: Apply host firewall
  hosts: all
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.firewall
```

**Single interface — web server:**

```yaml
firewall_zones:
  - name: public
    interfaces: []
    allowed_tcp_ports: [22, 80, 443]
```

**Multi-interface — management + public-facing:**

```yaml
firewall_default_zone: public

firewall_zones:
  - name: mgmt
    interfaces: [eth0]
    allowed_tcp_ports:
      - 22     # SSH
      - 9100   # Prometheus node_exporter
  - name: public
    interfaces: [eth1]
    allowed_tcp_ports:
      - 80
      - 443
    allowed_services:   # RedHat only
      - http
      - https
```

**Kubernetes node (multi-interface, cross-platform):**

```yaml
firewall_zones:
  - name: mgmt
    interfaces: [eth0]
    allowed_tcp_ports:
      - 22
  - name: k8s
    interfaces: [eth1]
    allowed_tcp_ports:
      - 6443    # kube-apiserver
      - 10250   # kubelet
      - 2379    # etcd client
      - 2380    # etcd peer
    allowed_udp_ports:
      - 8472    # Flannel VXLAN
```

**Global rule + interface-scoped rule (Debian mix):**

```yaml
# SSH allowed on all interfaces; web traffic only on eth1
firewall_zones:
  - name: base
    interfaces: []
    allowed_tcp_ports: [22]
  - name: web
    interfaces: [eth1]
    allowed_tcp_ports: [80, 443]
```


Notes
-----

- **RedHat / additive behaviour**: `ansible.posix.firewalld` adds ports,
  interfaces, and services but does not remove previously configured ones.
  To revoke a rule, use `firewall-cmd --remove-port=<port>/tcp --permanent`
  manually, or extend the role with explicit revoke tasks.
- **Debian / atomic behaviour**: The nftables ruleset is fully replaced from
  the template on every run. Removing a zone or port takes effect on the next
  play.
- **SSH lockout**: The default zone includes port 22. If your `sshd_port`
  differs from 22, update `firewall_zones` before applying or you will lose
  SSH access when nftables reloads.
- **K8s forward chain**: The nftables forward chain defaults to `policy drop`.
  This will break Kubernetes pod networking, which needs forwarding between
  the node and CNI interfaces. Either set the forward policy to `accept` in a
  wrapper or manage K8s nodes with firewalld (RHEL) where masquerade handles
  this.
- **nftables on RHEL**: firewalld uses nftables as its backend on RHEL 8+.
  Do not deploy a standalone nftables ruleset alongside firewalld on RHEL —
  the two will conflict.
- **firewalld zones on RHEL**: Zones must exist in firewalld before interfaces
  can be assigned to them. The built-in zones (`public`, `internal`, `dmz`,
  `trusted`, etc.) are always available. Custom zones require additional
  configuration outside this role.
