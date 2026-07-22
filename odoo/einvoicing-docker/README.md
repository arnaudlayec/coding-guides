
Framavox topic: https://framavox.org/d/hUjmO3gZ/premi-re-release-v18-s-rieuse-

# Purpose
This folder contains the minimum content that must be copied in Odoo projects files to install the French einvoicing, for projects installed with Akretion tooling like `ak` and `docky`.

# Prequisites

# WARNING: specific case with Chorus (when invoicing public customers)
SUPER PDP will start supporting sending invoices to Chorus only on September 1st 2026. It does not support it at the moment. However, all companies must be registered in the public e-invoicing directory of the France before September 1st 2026.

For customers requiring to invoice public entities, there is a simple in-between solution:
1. **Only** install the onboarding module [l10n_fr_einvoicing_onboarding](https://github.com/akretion/fr-einvoicing/pull/29)
2. Onboard your customer's company(ies) in Super PDP

Compared to below tutorial, adapted prerequisites are:
- Odoo URL whitelisting: yes
- Uninstall incompatible module: not needed
- Secret: yes
- Docker: not needed
- Odoo modules: update `spec.yaml` but only for `l10n_fr_einvoicing_onboarding` on branch `akretion/fr-einvoicing 18-einvoicing_onboarding`
- Python library: only `pyfrctc` in `requirements.txt`
- `__manifest__.py`: only `l10n_fr_einvoicing_onboarding`


# Configuration

### URL whitelisting
Send your Odoo URL to Akretion team, like: https://my-company.akretion.com.
They will whitelist it in the Akretion account of Super PDP's portal.

### Uninstall incompatible module
The module following module **must** be uninstalled before installing `fr-einvoicing` ones: `account_einvoice_generate`. This must be done **before** installing `fr-einvoicing` modules, else they will fail to isntall.

1. Remove it from your `__manifest__.py`, as well as any modules using it in dependency such as:
    - account_invoice_facturx
    - l10n_fr_account_invoice_facturx
    - l10n_fr_chorus_facturx
2. Put these modules in `/scripts/module_to_uninstall.py`

### Secret
See: https://github.com/akretion/docky-odoo-template-shared/pull/64/changes
- `odoo.cfg.tmpl`: add `fr_ctc_superpdp_client_id=${SUPERPDP_CLIENT_ID}`
- `prod.secrets.docker-compose.yml`: add `SUPERPDP_CLIENT_ID`

### Docker
- `prod.docker-compose.yml`: to launch Saxon java server and to make Odoo depend of it
- `saxon-traefik.docker-compose.yml`: to expose Saxon server to the local network (traefik)

### Odoo modules
- `requirements.txt`: Python libraries for Odoo `fr-einvoicing` modules
- `spec.yaml`: list of Odoo modules and dependencies
- `__manifest__.py`: update Odoo manifest file

### CI
- `.gitlab-ci.yml`



# Onboarding in Super PDP from Odoo

Tutorial (only onboarding): https://docs.google.com/document/d/12NIvGn-M_tbhyneJqlIh6s7K2-FVfUZJ/edit
Video (all fr-einvoicing): https://www.youtube.com/watch?v=nOa_mjovVXQ
