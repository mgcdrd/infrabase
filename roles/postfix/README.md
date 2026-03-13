postfix
=======

A role to install and configure Postfix MTA on Debian and RedHat family systems.

Supports two operating modes:
- **client** — sends all outbound mail through a configured relay host (typical for application or infrastructure hosts)
- **relay** — accepts mail from trusted networks and forwards it onward (the relay host itself)

Tested on: Debian 12/13, Rocky Linux 9/10

Requirements
------------

Role uses only builtin modules and does not require additional collections.

`gather_facts: true` is required as OS family facts are used to select the correct packages and file paths.


Role Variables
--------------

```yaml
# Role mode. Controls the overall configuration profile applied.
#   client - loopback-only listener, relayhost required, no public acceptance
#   relay  - full listener, accepts from mynetworks, forwards onward
postfix_mode: client

# Fully qualified hostname for this mail system. Defaults to ansible_fqdn.
postfix_myhostname: "{{ ansible_fqdn }}"

# Local internet domain name. Defaults to ansible_domain.
postfix_mydomain: "{{ ansible_domain }}"

# Domain appended to locally-posted mail.
postfix_myorigin: $mydomain

# Network interfaces Postfix listens on for incoming connections.
#   loopback-only  - localhost only (safe default for client mode)
#   all            - all interfaces (required for relay mode)
postfix_inet_interfaces: loopback-only

# IP protocols to use.
postfix_inet_protocols: all

# ---- UPSTREAM RELAY (both modes) ----

# Host to forward outbound mail to. Use [brackets] to disable MX lookup.
# Required when postfix_mode is 'client'.
# Optional when postfix_mode is 'relay' (tiered/smarthost setups).
# Examples:
#   postfix_relayhost: "[mail.example.com]:25"
#   postfix_relayhost: "[mail.example.com]:587"
postfix_relayhost: ""

# SASL (password) authentication to the upstream relay.
# Applies to both modes when postfix_relayhost is set.
postfix_sasl_enabled: false
postfix_sasl_username: ""   # required when postfix_sasl_enabled is true
postfix_sasl_password: ""   # use ansible-vault for this value

# Certificate authentication to the upstream relay.
# Applies to both modes when postfix_relayhost is set.
# Both variables must be set together. Can be combined with SASL.
# postfix_smtp_tls_cert_file: /path/to/client.pem
# postfix_smtp_tls_key_file:  /path/to/client.key

# ---- RELAY MODE ----

# Networks trusted to relay mail through this host.
# Extend with your internal subnets when running in relay mode.
postfix_mynetworks: "127.0.0.0/8 [::1]/128"

# Domains this relay accepts and forwards mail for.
# Leave empty to only relay for hosts in postfix_mynetworks.
postfix_relay_domains: ""

# ---- TLS (both modes) ----

# Enable TLS support. Disabling is not recommended.
postfix_tls_enabled: true

# TLS policy for both inbound (relay mode) and outbound connections.
#   may      - opportunistic TLS, plaintext fallback allowed
#   encrypt  - require TLS, reject plaintext connections
# Note: enabling SASL auth automatically forces 'encrypt' for outbound.
postfix_tls_security_level: may

# Inbound server certificate for relay mode (smtpd_tls_*).
# Defaults are set automatically per OS family (see Default Values below).
# postfix_tls_cert_file: /path/to/server.pem
# postfix_tls_key_file:  /path/to/server.key

# ---- ALIASES ----

# Entries to add to /etc/aliases. newaliases is run automatically after any change.
postfix_aliases: {}
# postfix_aliases:
#   root: admin@example.com
#   postmaster: admin@example.com
```


Default Values
--------------

The following OS-specific defaults are set automatically and do not need to be configured:

| Setting | Debian 12/13 | Rocky Linux 9/10 |
|---------|-------------|-----------------|
| `daemon_directory` | `/usr/lib/postfix/sbin` | `/usr/libexec/postfix` |
| `shlib_directory` | `/usr/lib/postfix` | `/usr/lib64/postfix` |
| `sendmail_path` | `/usr/sbin/sendmail` | `/usr/sbin/sendmail.postfix` |
| `newaliases_path` | `/usr/bin/newaliases` | `/usr/bin/newaliases.postfix` |
| `mailq_path` | `/usr/bin/mailq` | `/usr/bin/mailq.postfix` |
| TLS cert | `/etc/ssl/certs/ssl-cert-snakeoil.pem` | `/etc/pki/tls/certs/postfix.pem` |
| TLS key | `/etc/ssl/private/ssl-cert-snakeoil.key` | `/etc/pki/tls/private/postfix.key` |
| CA bundle | `/etc/ssl/certs/ca-certificates.crt` | `/etc/pki/tls/certs/ca-bundle.crt` |

The default TLS cert/key on Debian is the `ssl-cert` snakeoil certificate. For production relay hosts, set `postfix_tls_cert_file` and `postfix_tls_key_file` to a real certificate.


Dependencies
------------

No additional dependencies are required.


Example Playbook
----------------

Make sure to set `gather_facts: true` as OS family information is required by the role.

**Client host — send all mail to a relay:**

```yaml
- name: Configure postfix as mail client
  hosts: all
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.postfix

# group_vars or host_vars:
postfix_mode: client
postfix_relayhost: "[mail.example.com]:25"
postfix_aliases:
  root: admin@example.com
```

**Client host — SASL (password) authentication to relay:**

```yaml
postfix_mode: client
postfix_relayhost: "[mail.example.com]:587"
postfix_sasl_enabled: true
postfix_sasl_username: myhost@example.com
postfix_sasl_password: "{{ vault_postfix_sasl_password }}"
```

**Client host — certificate authentication to relay:**

```yaml
postfix_mode: client
postfix_relayhost: "[mail.example.com]:25"
postfix_smtp_tls_cert_file: /etc/ssl/certs/myhost-client.pem
postfix_smtp_tls_key_file:  /etc/ssl/private/myhost-client.key
```

**Relay host — accept from internal networks, deliver direct (no upstream):**

```yaml
postfix_mode: relay
postfix_inet_interfaces: all
postfix_mynetworks: "127.0.0.0/8 [::1]/128 10.0.0.0/8"
postfix_relay_domains: "example.com"
postfix_tls_cert_file: /etc/ssl/certs/mail.example.com.pem
postfix_tls_key_file:  /etc/ssl/private/mail.example.com.key
postfix_aliases:
  root: admin@example.com
  postmaster: admin@example.com
```

**Relay host — tiered setup, forward to an upstream smarthost with cert auth:**

```yaml
postfix_mode: relay
postfix_inet_interfaces: all
postfix_mynetworks: "127.0.0.0/8 [::1]/128 10.0.0.0/8"
postfix_tls_cert_file: /etc/ssl/certs/mail.example.com.pem
postfix_tls_key_file:  /etc/ssl/private/mail.example.com.key
# Forward everything to an upstream relay
postfix_relayhost: "[smarthost.example.com]:25"
postfix_smtp_tls_cert_file: /etc/ssl/certs/relay-client.pem
postfix_smtp_tls_key_file:  /etc/ssl/private/relay-client.key
```

**Mixed inventory — most hosts are clients, one group is the relay:**

```yaml
- name: Configure infrastructure mail
  hosts: all
  gather_facts: true
  become: true
  roles:
    - mgcdrd.infrabase.postfix

# group_vars/all.yml — default client config for all hosts
postfix_mode: client
postfix_relayhost: "[mail.example.com]:25"

# group_vars/mailrelay.yml — override for relay hosts
postfix_mode: relay
postfix_inet_interfaces: all
postfix_mynetworks: "127.0.0.0/8 [::1]/128 10.0.0.0/8"
```


License
-------

GPL-3.0-or-later
