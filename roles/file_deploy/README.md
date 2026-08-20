file_deploy
===========

Deploys arbitrary files, templates, and directories to hosts, with owner/group/mode
set explicitly on every item. Generic — it ships no content of its own and isn't
tied to any specific deployment. Consuming playbooks/deployments supply the file
list and their own `files/`/`templates/` directories.

Each entry in `file_deploy_items` is one file or directory. Files can come from a
source file (copied verbatim or rendered as a Jinja2 template) or from inline
literal content. Ownership and permissions are required on every item — this role
has no distro default to fall back on.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

Role uses only builtin modules and does not require additional collections.

`src` paths are resolved via the standard Ansible role/play search path — put
the referenced files/templates in the calling playbook's own `files/` or
`templates/` directory, not in this role.


Role Variables
--------------

```yaml
file_deploy_items: []
# file_deploy_items:
#   - dest: /etc/motd
#     src: motd.j2
#     is_template: true
#     owner: root
#     group: root
#     mode: "0644"
#   - dest: /opt/scripts/backup.sh
#     src: backup.sh
#     owner: root
#     group: root
#     mode: "0750"
#   - dest: /etc/app/app.conf
#     content: "setting = true\n"
#     owner: appuser
#     group: appgroup
#     mode: "0640"
#   - dest: /opt/app/data
#     state: directory
#     owner: appuser
#     group: appgroup
#     mode: "0750"
```

| Field | Required | Description |
|---|---|---|
| `dest` | yes | Destination path. |
| `state` | no | `file` (default) or `directory`. Directories ignore `src`/`content`/`is_template`. |
| `src` | no | Source file, resolved via the calling playbook's `files/`/`templates/`. Mutually exclusive with `content`. |
| `content` | no | Inline literal content, written verbatim (not templated). Mutually exclusive with `src`. |
| `is_template` | no | `true` renders `src` with `ansible.builtin.template` (Jinja2); `false` (default) copies it verbatim with `ansible.builtin.copy`. Ignored when `content` is set. |
| `owner`, `group`, `mode` | yes | Always explicit — no fallback default. |
| `backup` | no | Back up the existing file before overwriting. Default: `false`. |


Dependencies
------------

No additional dependencies are required.


Example Playbook
----------------

```yaml
- name: Deploy app config and scripts
  hosts: app_servers
  become: true
  roles:
    - role: mgcdrd.infrabase.file_deploy
      vars:
        file_deploy_items:
          - dest: /etc/app/app.conf
            src: app.conf.j2
            is_template: true
            owner: appuser
            group: appgroup
            mode: "0640"
          - dest: /opt/app/bin/run.sh
            src: run.sh
            owner: appuser
            group: appgroup
            mode: "0750"
          - dest: /opt/app/data
            state: directory
            owner: appuser
            group: appgroup
            mode: "0750"
```

Place `app.conf.j2` and `run.sh` in the calling playbook's `templates/` and
`files/` directories respectively.


Notes
-----

- This role does not manage file absence/removal — it only creates or updates
  the items listed. Use `ansible.builtin.file` with `state: absent` directly
  for cleanup.
- `src` and `content` are mutually exclusive per item; the role asserts this
  before making any changes.
