password_policy
===============

Enforces CIS-aligned password quality, aging, lockout, and session timeout
policy across Debian and RedHat family systems. Manages:

- `/etc/security/pwquality.conf` — character class requirements and minimum length
- `/etc/login.defs` — password aging and umask
- `/etc/default/useradd` — inactive account lockout
- `/etc/profile` and `/etc/bash.bashrc` (Debian) / `/etc/bashrc` (RedHat) — TMOUT and umask
- `/etc/security/faillock.conf` + `/etc/security/pwhistory.conf` — **RedHat only**

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. Facts (`gather_facts: true`) are required for
OS-family branching.

`libpwquality` must be installed for `pwquality.conf` to take effect. It is
present by default on both Debian 12+ and Rocky 9+.


Role Variables
--------------

### pwquality (`password_policy_pwquality`)

List of key/value pairs written to `/etc/security/pwquality.conf`:

| Key | Default | Description |
|-----|---------|-------------|
| `lcredit` | `-1` | Minimum lowercase characters required |
| `ucredit` | `-1` | Minimum uppercase characters required |
| `dcredit` | `-1` | Minimum digit characters required |
| `ocredit` | `-1` | Minimum special characters required |
| `difok` | `8` | Characters that must differ from previous password |
| `minclass` | `4` | Minimum character classes required |
| `maxrepeat` | `3` | Maximum consecutive identical characters |
| `maxclassrepeat` | `4` | Maximum consecutive same-class characters |
| `minlen` | `15` | Minimum password length |

### login.defs (`password_policy_login_defs`)

List of key/value pairs written to `/etc/login.defs`:

| Key | Default | Description |
|-----|---------|-------------|
| `PASS_MAX_DAYS` | `60` | Maximum password age in days |
| `PASS_MIN_DAYS` | `7` | Minimum days between password changes |
| `PASS_MIN_LEN` | `15` | Minimum password length (backup enforcement) |
| `UMASK` | `027` | Default umask for new accounts |
| `FAIL_DELAY` | `4` | Seconds to delay on failed login |

### Other variables

| Variable | Default | Description |
|---|---|---|
| `password_policy_inactive_days` | `30` | Days after password expiry before account is locked (`/etc/default/useradd INACTIVE=`) |
| `password_policy_tmout` | `900` | Idle shell timeout in seconds (TMOUT in `/etc/profile`) |
| `password_policy_umask` | `027` | Umask for interactive shells |
| `password_policy_faillock_deny` | `3` | Failed login attempts before lockout (**RedHat only**) |
| `password_policy_faillock_unlock_time` | `900` | Lockout duration in seconds (**RedHat only**) |
| `password_policy_remember` | `5` | Number of previous passwords to reject (**RedHat only**) |


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Enforce password policy
  hosts: all
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.password_policy
```

Relaxed policy for lab/dev hosts:

```yaml
- name: Enforce password policy
  hosts: dev
  become: true
  gather_facts: true
  roles:
    - role: mgcdrd.infrabase.password_policy
      vars:
        password_policy_pwquality:
          - { key: minlen, value: "12" }
        password_policy_login_defs:
          - { key: PASS_MAX_DAYS, value: "365" }
          - { key: PASS_MIN_DAYS, value: "0" }
          - { key: PASS_MIN_LEN,  value: "12" }
          - { key: UMASK,         value: "022" }
          - { key: FAIL_DELAY,    value: "4" }
        password_policy_tmout: 0
```


Notes
-----

- `faillock.conf` and `pwhistory.conf` are RedHat-specific. On Debian,
  account lockout and password history require PAM configuration changes
  (`/etc/pam.d/`), which this role does not manage to avoid breaking
  authentication. Configure those via `pam-auth-update` or a site-specific
  PAM role.
- `login.defs` changes only affect **new** accounts. Existing account aging
  must be updated with `chage` if required — the role already does this for
  local accounts (UID 1000–65533): it applies `PASS_MAX_DAYS`/`PASS_MIN_DAYS`
  and resets any last-change date (shadow field 3) that's set in the future
  (CIS `accounts_password_last_change_is_in_past`, usually clock skew or a
  hand-provisioned account). IPA/LDAP accounts aren't in `/etc/shadow` so
  they're untouched.
- On RedHat, `/root/.local/bin` and `/root/bin` are created if missing — the
  stock `/root/.bashrc` prepends them to `PATH` unconditionally, and CIS
  `root_path_all_dirs` requires every `PATH` entry to be a real directory.
- `TMOUT=0` disables idle timeout. Set `password_policy_tmout: 0` to skip.
- The `replace` module is used for `login.defs` and shell rc files — lines that
  do not match the regexp are left unchanged. If your `login.defs` has a
  non-standard format, verify with `ansible --check` first.
