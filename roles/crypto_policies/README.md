crypto_policies
===============

Installs `crypto-policies` and deploys CIS-aligned system crypto-policy modules
on RedHat-family hosts (`/etc/crypto-policies/policies/modules/`):

- `NO-SSHCBC`, `NO-SSHWEAKCIPHERS`, `NO-SSHWEAKMACS`: drop weak SSH ciphers and MACs
- `NO-WEAKMAC`, `NO-RPMSHA1`: drop weak MACs and SHA-1 for RPM verification
- Optional extra policy modules from `crypto_policies_additional` (`src` template, `dst` file name)

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
| `crypto_policies_cis` | `true` | No | Apply the CIS-aligned crypto policy |
| `crypto_policies_additional` | `[]` | No | Extra policy modules; each entry takes `src` (template) and `dst` (module file name only, always written under `/etc/crypto-policies/policies/modules/`) |




Dependencies
------------

None.

Example Playbook
----------------

```yaml
- name: Apply CIS crypto policy modules
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.crypto_policies
```

Notes
-----

- The role only places the module files. Selecting a policy that includes
  them (`update-crypto-policies --set DEFAULT:NO-SSHCBC:...`) is not done here.
