proxmox_access
===============

Manages ProxMox VE's access-control (IAM) layer via the PVE REST API: users,
groups, custom roles (PVE privilege sets — not Ansible roles), ACLs, and
authentication realms (LDAP/AD/OpenID).

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.1.0` — `proxmox_role`,
  `proxmox_domain`, and `proxmox_domain_sync` are recent additions;
  `proxmox_user`/`proxmox_group` need `>= 1.2.0`,
  `proxmox_access_acl` needs `>= 1.1.0`).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Authentication
---------------

Two methods are supported — set one pair of variables, leave the other unset:

```yaml
proxmox_access_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_access_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
# or
proxmox_access_api_user:     "root@pam"
proxmox_access_api_password: "{{ vault_proxmox_api_password }}"
```

Unset `vault_*` variables resolve to `omit`. Grant the token `Sys.Modify` +
`Realm.AllocateUser` at minimum, plus `User.Modify`/`Group.Allocate` as
needed for the sections you use.


Role Variables
---------------

### Connection (required)

```yaml
proxmox_access_api_host: "pve2.example.com"
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_access_do_user` | `false` | `user` | Create/update/delete users |
| `proxmox_access_do_group` | `false` | `group` | Create/delete groups |
| `proxmox_access_do_role` | `false` | `role` | Create/update/delete IAM roles |
| `proxmox_access_do_acl` | `false` | `acl` | Grant/revoke ACL entries |
| `proxmox_access_do_domain` | `false` | `domain` | Create/update/delete auth realms |
| `proxmox_access_do_domain_sync` | `false` | `domain_sync` | Trigger an LDAP/AD directory sync |

**`acl` does not support `--check`** (the underlying module declares no
check_mode support). All other sections here support full check/diff mode.

### user

```yaml
proxmox_access_users:
  - userid: jdoe@pve
    state: present
    enable: true
    email: jdoe@example.com
    firstname: John
    lastname: Doe
    expire: 0
    groups: [admins]
    password: "{{ vault_proxmox_jdoe_password }}"   # PVE-realm users only
    tokens:
      - tokenid: automation
        privsep: false        # false = fully privileged token, true = ACL-restricted
        comment: "CI token"
```

`password` is only meaningful for PVE-realm users at creation — rotating a
password on an already-existing user through this module has unconfirmed
behavior upstream (the module's token-auth guard around the password-update
call reads inverted from what you'd expect). Verify against your cluster
before relying on it for password rotation; don't assume it works silently.

### group

```yaml
proxmox_access_groups:
  - groupid: admins
    comment: "IT Admins"
    state: present
```

`comment` only applies on creation (no update path). **There is no
`members` field on this module** — group membership is set from the user
side, via each user's `groups:` list above.

### role

```yaml
proxmox_access_roles:
  - roleid: VMOperator
    privs: [VM.PowerMgmt, VM.Console, VM.Monitor]
    state: present
```

"Role" here means a PVE IAM privilege set, unrelated to Ansible roles.
`privs` is replaced wholesale on update — there's no add/remove delta
semantics, always list the full desired privilege set.

### acl

```yaml
proxmox_access_acls:
  - path: /vms/100
    type: user          # user | group | token
    ugid: jdoe@pve       # the user/group/token identifier itself
    roleid: VMOperator
    propagate: true
    state: present
```

Each item is **one ACE** (path × role × principal) — to grant multiple
roles or principals on the same path, add multiple list items. For
`state: absent`, only `path` is strictly required; if `roleid`/`type`/`ugid`
are also given they narrow which ACEs on that path get removed — omit them
and **every** ACE on that path is removed.

### domain

```yaml
proxmox_access_domains:
  - realm: ipa
    state: present
    type: ldap                # ad | ldap | openid — pam/pve are built-in, not manageable here
    default: false
    ldap_base_dn: "cn=accounts,dc=lab,dc=example,dc=com"
    ldap_user_attr: uid
    ldap_bind_dn: "uid=svc-proxmox,cn=users,cn=accounts,dc=lab,dc=example,dc=com"
    ldap_password: "{{ vault_proxmox_ldap_bind_password }}"
    ldap_primary_server: ipa2.lab.example.com
    ldap_secondary_server: ipa3.lab.example.com
    ldap_mode: ldaps
    ldap_validate_certs: true
    ldap_sync_defaults_options:
      scope: both
      enable_new: true
      remove_vanished: "acl;properties;entry"
```

**`type` is immutable after creation** (as is `openid_username_claim`) —
the module warns and drops those fields from an update rather than failing;
delete and recreate the realm to change its type.

**AD and LDAP share the same parameter names.** `ad_primary_server`,
`ad_secondary_server`, `ad_port`, `ad_mode`, `ad_bind_dn`, `ad_password`,
etc. are pure aliases of the `ldap_*` keys — there's no separately
implemented AD argument set. Two fields are genuinely AD-only with no LDAP
equivalent: `ad_domain` (required for `type: ad`) and `ad_case_sensitive`.
Two fields are LDAP-only with no AD alias: `ldap_base_dn` and
`ldap_user_attr` — the module doesn't expose a base DN for AD realms at all.

```yaml
  - realm: corp-ad
    state: present
    type: ad
    ad_domain: CORP
    ad_primary_server: dc1.corp.example.com
    ldap_bind_dn: "svc-proxmox@corp.example.com"   # shared fields still use ldap_* names for AD
    ldap_password: "{{ vault_proxmox_ad_bind_password }}"
```

OpenID fields: `openid_issuer_url`, `openid_client_id` (both required for
`type: openid`), plus `openid_client_key`, `openid_username_claim`,
`openid_audiences`, `openid_acr_values`, `openid_autocreate`,
`openid_groups_autocreate`, `openid_groups_claim`, `openid_groups_overwrite`,
`openid_prompt`, `openid_query_userinfo`, `openid_scopes`.

### domain_sync

```yaml
proxmox_access_domain_sync_realm: "ipa"
proxmox_access_domain_sync_scope: "both"        # users | groups | both
proxmox_access_domain_sync_enable_new: true
proxmox_access_domain_sync_remove_vanished: "acl;properties;entry"   # or "none"
```


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_access` | Entire role |
| `user` | Manage users |
| `group` | Manage groups |
| `role` | Manage IAM roles |
| `acl` | Manage ACL entries |
| `domain` | Manage auth realms |
| `domain_sync` | Trigger directory sync |


Example Playbook — LDAP realm + role + group + ACL
--------------------------------------------------------

```yaml
- name: Wire up FreeIPA-backed access for the ops team
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_access
      vars:
        proxmox_access_api_host:         "pve2.example.com"
        proxmox_access_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_access_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_access_do_domain: true
        proxmox_access_do_role: true
        proxmox_access_do_group: true
        proxmox_access_do_acl: true
        proxmox_access_domains:
          - realm: ipa
            state: present
            type: ldap
            ldap_base_dn: "cn=accounts,dc=lab,dc=example,dc=com"
            ldap_user_attr: uid
            ldap_bind_dn: "uid=svc-proxmox,cn=users,cn=accounts,dc=lab,dc=example,dc=com"
            ldap_password: "{{ vault_proxmox_ldap_bind_password }}"
            ldap_primary_server: ipa2.lab.example.com
            ldap_secondary_server: ipa3.lab.example.com
            ldap_mode: ldaps
        proxmox_access_roles:
          - roleid: VMOperator
            privs: [VM.PowerMgmt, VM.Console, VM.Monitor]
        proxmox_access_groups:
          - groupid: ops-team
        proxmox_access_acls:
          - path: /
            type: group
            ugid: ops-team
            roleid: VMOperator
            propagate: true
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **No `proxmox_role_info`/`proxmox_group_info` used here** — `proxmox_user_info`
  and `proxmox_domain_info` exist upstream but aren't wired into this role
  (no `info` gated section); call them directly via
  `community.proxmox.proxmox_user_info`/`proxmox_domain_info` if you need
  read-only facts.
- **No handlers**: every module call is idempotent against PVE's own state.
