
/!\ NON TESTÉ (2026-07-15)

Framavox topic: https://framavox.org/d/hUjmO3gZ/premi-re-release-v18-s-rieuse-

# Docker
- `prod.docker-compose.yml`: to launch Saxon java server, and so Odoo container depends of it
- `saxon-traefik.docker-compose.yml`: to expose Saxon server to the local network

# Odoo modules
- `requirements.txt`: Python libraries for Odoo `fr-einvoicing` modules
- `spec.yaml`: list of Odoo modules and dependencies
- `__manifest__.py`: update Odoo manifest file

Warning: the 2 modules `account_einvoice_generate` and `l10n_fr_chorus_facturx` must be un-installed.
This disables Chorus invoicing, which is incompatible with fr-einvoicing.

# In Odoo settings (via the user-interface)


# CI
- `.gitlab-ci.yml`
