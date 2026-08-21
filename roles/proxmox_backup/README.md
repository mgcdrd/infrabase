proxmox_backup
===============

Manages ProxMox VE VM/CT backups via the PVE REST API: scheduled backup
jobs (cron + retention + storage target), toggling a VM's membership in an
existing job, and one-off on-demand backups.

Tested on: any Ansible controller against a ProxMox VE 8.x cluster.


Requirements
------------

- The Ansible controller must be able to reach the PVE API host on port 8006.
- `community.proxmox` collection installed (`>= 2.0.0`).
- **`proxmoxer >= 2.3` and `requests` must be installed on the Ansible
  controller**:
  - RPM: `pip3 install 'proxmoxer>=2.3' requests`
  - Debian 12+ (system Ansible): `pip3 install 'proxmoxer>=2.3' requests --break-system-packages`
  - Debian 12+ (Ansible in a venv): same command inside the venv


Why this role isn't all `community.proxmox` modules
-----------------------------------------------------

**No module in `community.proxmox` creates or updates a scheduled backup
job** (cron schedule, retention, storage, vmid selection) — confirmed by
reading the collection's source directly. The collection only ships:

- `proxmox_backup_schedule` — adds/removes a single vmid from a job that
  **already exists**; cannot create the job itself.
- `proxmox_backup` — fires an on-demand ("Backup now") run; not a scheduled
  job.
- `proxmox_backup_info` — read-only job/VM listing.

So `job` (scheduled job CRUD) in this role talks to
`/cluster/backup` directly via `ansible.builtin.uri`, while `membership` and
`run` use the real collection modules. **The `job` section requires API
token auth** — it sends a `PVEAPIToken=...` header, and doesn't implement
PVE's ticket + CSRF-token login flow that password auth would need.


Authentication
---------------

```yaml
proxmox_backup_api_token_id:     "{{ vault_proxmox_api_token_id }}"
proxmox_backup_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
```

`membership`, `run`, and `info` also accept password auth
(`proxmox_backup_api_user`/`proxmox_backup_api_password`) like every other
role in this collection, but `job` will fail its precondition check without
a token. Grant the token `VM.Backup` + `Datastore.AllocateSpace` at minimum,
plus `Sys.Modify` on `/` for `job` (job CRUD requires cluster-wide modify).


Role Variables
---------------

### Connection

Defaults from the shared `proxmox_api_*` vars (set those once for the whole
play/inventory) — override only if this role needs a different node or credential.

```yaml
proxmox_backup_api_host: "pve2.example.com"   # optional — overrides the shared proxmox_api_host
```

### Execution gates

| Gate variable | Default | Tag | What it runs |
|---|---|---|---|
| `proxmox_backup_do_info` | `false` | `info` | Query backup jobs / per-VM membership |
| `proxmox_backup_do_job` | `false` | `job` | Create/update/delete scheduled jobs (requires token auth) |
| `proxmox_backup_do_membership` | `false` | `membership` | Add/remove a VM from an existing job |
| `proxmox_backup_do_run` | `false` | `run` | Trigger an on-demand backup |

### info

```yaml
proxmox_backup_info_vm_name: "newhost01"   # mutually exclusive with vm_id and jobs: true
proxmox_backup_info_jobs: false             # true = raw job list, false = per-VM view
```

Sets `proxmox_backup_facts`.

### job

```yaml
proxmox_backup_jobs:
  - id: backup-webtier          # required — idempotency key; PVE auto-generates one if omitted via the raw API, creating a new job every run
    state: present               # present | absent
    comment: "Weekly full backup - web tier"
    schedule: "sun 02:00"         # systemd-calendar subset, e.g. "mon,wed,fri 03:30"
    storage: pbs-main
    vmid: "100,101,102"          # comma-separated STRING, not a YAML list
    mode: snapshot                # snapshot | suspend | stop
    compress: zstd                # "0" | "1" | gzip | lzo | zstd
    prune_backups: "keep-last=7,keep-daily=7,keep-weekly=4,keep-monthly=6,keep-yearly=0"
    enabled: true
    notification_mode: notification-system   # auto | legacy-sendmail | notification-system
```

Update semantics follow standard PVE API behavior: a `PUT` only touches the
fields you send — fields you omit are left alone on an existing job (not
reset to a default). There is no drift-correction beyond what you
explicitly set each run.

### membership

```yaml
proxmox_backup_membership:
  - vm_name: newhost01    # or vm_id: "100"
    backup_id: backup-webtier   # effectively required even for state=present — see note below
    state: present
```

**`backup_id` is effectively mandatory for `state: present`** despite being
marked optional in the underlying module's schema — the module's own
present-path logic doesn't handle a missing `backup_id` sanely (confirmed
from source, not just docs). Always set it. For `state: absent`, omitting
`backup_id` removes the vmid from **every** job it's currently in. The
module also refuses to remove the last vmid in a job — use `job`'s
`state: absent` on the whole job instead if you want to empty/delete it.

### run

```yaml
proxmox_backup_run_mode: "include"      # include | all | pool
proxmox_backup_run_storage: "pbs-main"
proxmox_backup_run_vmids: [100]          # required when mode: include
proxmox_backup_run_backup_mode: "stop"   # snapshot | suspend | stop
proxmox_backup_run_retention: "keep-daily=5,keep-last=14,keep-monthly=4,keep-weekly=4,keep-yearly=0"
proxmox_backup_run_wait: true
proxmox_backup_run_wait_timeout: 120
```

**Not idempotent** — every run of this section starts a new backup task,
exactly like clicking "Backup now" in the PVE GUI. Gate it behind an
explicit trigger condition in your playbook rather than leaving it in a
play that runs routinely.


Tags
----

| Tag | What it runs |
|-----|-------------|
| `proxmox_backup` | Entire role |
| `info` | Query jobs/membership |
| `job` | Create/update/delete scheduled jobs |
| `membership` | Toggle VM job membership |
| `run` | On-demand backup |


Example Playbook — create a weekly job and populate it
-------------------------------------------------------------

```yaml
- name: Set up weekly backups for the web tier
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_backup
      vars:
        proxmox_backup_api_host:         "pve2.example.com"
        proxmox_backup_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_backup_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_backup_do_job: true
        proxmox_backup_jobs:
          - id: backup-webtier
            comment: "Weekly full backup - web tier"
            schedule: "sun 02:00"
            storage: pbs-main
            vmid: "100,101"
            mode: snapshot
            prune_backups: "keep-last=7,keep-daily=7,keep-weekly=4"
```

Example Playbook — add a newly-provisioned VM to an existing job
------------------------------------------------------------------------

```yaml
- name: Add new VM to the weekly backup job
  hosts: localhost
  gather_facts: false
  roles:
    - role: mgcdrd.infrabase.proxmox_backup
      vars:
        proxmox_backup_api_host:         "pve2.example.com"
        proxmox_backup_api_token_id:     "{{ vault_proxmox_api_token_id }}"
        proxmox_backup_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
        proxmox_backup_do_membership: true
        proxmox_backup_membership:
          - vm_name: newhost02
            backup_id: backup-webtier
            state: present
```


Notes
-----

- **`delegate_to: localhost`**: every task talks to the PVE API, not the
  inventory host — run with `hosts: localhost`.
- **`no_log: true`** on the `job` section's `uri` tasks — the Authorization
  header carries the API token secret, so full request/response bodies are
  suppressed from Ansible output on those tasks.
- **No handlers**: `job`/`membership` are idempotent against PVE's own
  state; `run` is deliberately not (see above).
