login_banner
============

Deploys a pre-login warning banner to `/etc/issue` (local console) and
`/etc/issue.net` (SSH pre-auth banner, when `Banner /etc/issue.net` is set in
`sshd_config`). Both files receive the same content from a single template.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.


Role Variables
--------------

| Variable | Default | Description |
|---|---|---|
| `login_banner_text` | Generic "authorized access only" text | Multi-line string written to `/etc/issue` and `/etc/issue.net`. |


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Deploy login banner
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.login_banner
```

Custom banner text:

```yaml
- name: Deploy login banner
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.login_banner
      vars:
        login_banner_text: |
          WARNING: Authorized use only.
          All sessions are recorded.
```


Notes
-----

- To show the banner over SSH, add `Banner /etc/issue.net` to your sshd_config
  (the `mgcdrd.infrabase.sshd` role sets this by default).
- `/etc/motd` (post-login message) is not managed by this role. Set it via a
  separate task if needed.
- The banner text should not contain OS version strings or hostnames — CIS
  recommends keeping pre-login banners generic to avoid disclosing system
  information to unauthenticated users.
