pam
===

Configures the PAM stack on RedHat-family hosts:

- Selects an `authselect` profile and enables its features (mkhomedir, sudo, faillock, pwhistory)
- Restricts `su` to members of a dedicated group via `pam_wheel`

On Debian-family hosts the role does nothing.

Tested on: Rocky Linux 9/10

Requirements
------------

`become: true` is required. `gather_facts: true` is required (uses
`ansible_facts['os_family']`).

Role Variables
--------------

### Variable reference

| Variable | Default | Required | Description |
|---|---|---|---|
| `pam_authselect_profile` | `sssd` | No | `authselect` profile to select (RedHat); moving off `sssd` on IPA-enrolled hosts breaks LDAP auth |
| `pam_authselect_features` | *(list, 4 items)* | No | Features enabled on the profile; `with-faillock` and `with-pwhistory` wire in the `password_policy` conf files |
| `pam_su_group` | `sugroup` | No | Group allowed to `su` via `pam_wheel`; created empty, so add members explicitly |



Dependencies
------------

None. The `with-faillock` and `with-pwhistory` features wire in the
`faillock.conf`/`pwhistory.conf` values set by `mgcdrd.infrabase.password_policy`.

Example Playbook
----------------

```yaml
- name: Configure PAM
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.pam
      vars:
        pam_su_group: sugroup
```

Notes
-----

- Changing `pam_authselect_profile` away from `sssd` on IPA-enrolled hosts
  breaks LDAP authentication.
- `pam_su_group` is created empty, so no regular user can `su` until members
  are added to it.
