ssl_scripting
=============

Deploys a helper script for generating self-signed certificates and a
`dhparam.pem` file. Intended as a bootstrapping utility where a trusted CA
(e.g. `acme_sh`) is not yet available or not appropriate.

The role writes `make_new_ssl.sh` from a template, then generates a dummy
self-signed cert (`ssl-dummy.key` / `ssl-dummy.crt`) and a Diffie-Hellman
parameter file (`dhparam.pem`) on first run. Subsequent runs are idempotent —
existing files are not regenerated.

Tested on: Debian 12/13, Rocky Linux 9/10


Requirements
------------

`become: true` is required. `gather_facts` is not required.

`openssl` must be installed on the target host.


Role Variables
--------------

All variables are nested under the `ssl_scripting` dict:

| Variable | Default | Description |
|---|---|---|
| `ssl_scripting.base_dir` | `/root/ssl_gen` | Directory where the script and generated files are placed |
| `ssl_scripting.def_bits` | `2048` | Key size for generated certs and `dhparam.pem` |
| `ssl_scripting.def_md` | `sha256` | Message digest written into the helper script |
| `ssl_scripting.country` | `US` | Country code written into the helper script |
| `ssl_scripting.state` | `XX` | State/province written into the helper script |
| `ssl_scripting.locale` | `YY` | Locality written into the helper script |
| `ssl_scripting.org` | `ZZ` | Organization written into the helper script |
| `ssl_scripting.orgunit` | `AA` | Organizational unit written into the helper script |
| `ssl_scripting.email` | `admins@acme.com` | Email address written into the helper script |


Dependencies
------------

None.


Example Playbook
----------------

```yaml
- name: Deploy SSL scripting utility
  hosts: all
  become: true
  roles:
    - role: mgcdrd.infrabase.ssl_scripting
      vars:
        ssl_scripting:
          base_dir: /root/ssl_gen
          def_bits: 4096
          country: US
          state: CA
          locale: SanFrancisco
          org: Acme Corp
          orgunit: IT
          email: admin@acme.com
```


Notes
-----

- `dhparam.pem` generation can take several minutes at 4096 bits. For most
  internal use cases `2048` is sufficient.
- The dummy cert is valid for 365 days and is self-signed — it exists only to
  give services a valid cert placeholder before real certs are issued.
- For production TLS, use `mgcdrd.infrabase.acme_sh` instead.
