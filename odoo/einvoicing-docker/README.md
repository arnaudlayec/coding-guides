
Framavox topic: https://framavox.org/d/hUjmO3gZ/premi-re-release-v18-s-rieuse-

# Purpose
This folder contains the minimum content that must be copied in Odoo projects files to install the French einvoicing, for projects installed with Akretion tooling like `ak` and `docky`.


# Prequisites
Ask Akretion team to allow the customer's Odoo URL in Super PDP's portal of Akretion.

# Warning with Chorus

Former modules managing Chorus invoicing are incompatible with `fr-einvoicing`.
The 2 following modules must be uninstalled before installing `fr-einvoicing` ones:
- `account_einvoice_generate`
- `l10n_fr_chorus_facturx`

###### How to continue invoicing to public customer via Chorus?
SUPER PDP will start supporting sending invoices to Chorus on September 1st 2026. It does not support it at the moment.
If you need to keep invoicing to public customer via Chorus:
- factur-x generation on invoices for the public sector are already disabled. This is done by the `patch` on `fr-einvoicing` (see `spec.yaml`)
- you can deposit them manually on the web portal of Chorus Pro and go through the OCR


# Configurations

### Environment
Add:
- `fr_ctc_superpdp_client_id=${SUPERPDP_CLIENT_ID}` in `odoo.cfg.tmpl` if not already here
- `SUPERPDP_CLIENT_ID` in `prod.secrets.docker-compose.yml`
For more info, see https://github.com/akretion/docky-odoo-template-shared/pull/64/changes

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
