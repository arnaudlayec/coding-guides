

Odoo v18 requirements
=====================

OS :
- Debian 12 in preference
- also possible: Ubuntu **server** LTS 24.04.2 (Noble Numbat)

Dimensionnement minimaliste (pour 2 utilisateurs concurrents, avec de la marge) :
- 2 CPU
- 4 Go RAM
- 50 Go SSD
=> Exemple : offre "STD-4" de PulseHeberge (6€/mois)

Prérequis réseau :
- Accès SSH depuis Internet (entrant vers le serveur) *ou bien* souscription à l'offre VPN d'Alexis
- Accès à Internet depuis le serveur (sortant du serveur vers Internet), notamment pour le téléchargement de package (pip, ...) et de code source (Odoo, modules, ...)

Binaires principaux (que j'installe - non exclusif):
- python >= 3.10
- postgresql >= 12.0
- wkhtmltopdf 0.12.6 https://github.com/wkhtmltopdf/packaging/releases/tag/0.12.6.1-3
