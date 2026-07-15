
Framavox topic: https://framavox.org/d/hUjmO3gZ/premi-re-release-v18-s-rieuse-



# Purpose
This folder contains the minimum content that must be copied in Odoo projects files to install the French einvoicing, for projects installed with Akretion tooling like `ak` and `docky`.



# Warning
Former modules managing Chorus invoicing are incompatible with `fr-einvoicing`. The 2 following modules must be uninstalled before installing `fr-einvoicing` ones:
- `account_einvoice_generate`
- `l10n_fr_chorus_facturx`

If you really need to keep Chorus module, see the branch [18.0-tmp_hack_chorus](https://github.com/akretion/fr-einvoicing/tree/18.0-tmp_hack_chorus) and the Framavox topic.



# Configurations

### Docker
- `prod.docker-compose.yml`: to launch Saxon java server and to make Odoo depend of it
- `saxon-traefik.docker-compose.yml`: to expose Saxon server to the local network (traefik)

### Odoo modules
- `requirements.txt`: Python libraries for Odoo `fr-einvoicing` modules
- `spec.yaml`: list of Odoo modules and dependencies
- `__manifest__.py`: update Odoo manifest file

### CI
- `.gitlab-ci.yml`



# Final test

In a web browser, append `/en16931/FACTUR-X_EXTENDED_codedb.xml` to your Odoo's URL and browse to the page.
Example: http://test.localhost/en16931/FACTUR-X_EXTENDED_codedb.xml.
If you see the .xml content: this is a success!
