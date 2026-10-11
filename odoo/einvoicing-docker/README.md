
Framavox topic: https://framavox.org/d/hUjmO3gZ/premi-re-release-v18-s-rieuse-

# Purpose
This folder contains the minimum content that must be copied in Odoo projects files to install the French einvoicing, for projects installed with Akretion tooling like `ak` and `docky`.

# Light onboarding

For customers only requiring to subscribe to the France directory with Akretion billing without receiving invoices in Odoo, there is a simple solution:
1. **Only** install the onboarding module [l10n_fr_einvoicing_onboarding](https://github.com/akretion/fr-einvoicing/pull/29)
2. Onboard your customer's company(ies) in Super PDP
3. If needed later, install all other modules and prerequisites. The customer will need to follow again the onboarding process just to get the Super PDP token again.

# Chorus invoicing : SPECIFIC CASE (B2G : invoicing to government entities)
SUPER PDP does not support sending invoices to Chorus yet. We except it will do in a stable way in 2026.

Install `l10n_fr_chorus_en16931`, which replaces `l10n_fr_chorus_facturx`. It allows Chorusinvoices to be automatically sent, with a dependency of the module `account_invoice_en16931` instead of the legacy `account_invoice_facturx` (for FacturX generation).
(!) PLEASE LOOK AT THE README.md of `l10n_fr_chorus_en16931` for install procedure.

Blog post: https://framavox.org/d/o3A1hZFn/connecteur-chorus-pro-et-nouveaux-modules-einvoicing

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
- `answers.sh`: add `declare -x SUPERPDP_CLIENT_ID="${SUPERPDP_CLIENT_ID:-}"`
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


# Adapatation for v16.0



### Uninstall

- account_einvoice_generate
