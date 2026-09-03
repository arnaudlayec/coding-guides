
# Procédure d'installation de Wireguard sur un serveur Odoo ou un ordinateur client
# seul le A) est à réaliser
# les § B) et C) sont des indications

# ==== A) Etapes côté client (serveur Odoo ou ordinateur de l'administrateur) ====
	# 1. Prérequis
	#   - Serveur Odoo installé, Debian 24.04 LTS
	#   - Avoir un accès SSH au serveur depuis un client sur le même réseau interne
	#   - Avoir un accès root ou sudo sur le serveur
	#   - Le serveur Odoo doit avoir accès à Internet
	#     Si filtrage Internet sortant, doivent être au moins autorisés :
	#	   * les distributions Debian (pour les mises à jour du serveur et `apt-get install wireguard`)
	#	   * l'hôte miluni.fr sur le port 50234 (pour le VPN)
	
	# 2. Se connecter au serveur en SSH, depuis un poste client sur le même réseau
	# si -p n'est pas précisé, le port par défaut est 22
	ssh <user sudo>@<IP du serveur> -p <port ssh>

	# 3. Installer le client Wireguard
	sudo apt-get install wireguard -y

	# 4. Déposer le fichier de configuration dans le dossier /etc/wireguard
		# (a) Solution rapide **depuis le serveur**, créer un fichier vierge et coller le contenu
		cd /etc/wireguard
		sudo nano wg0.conf
		# puis copier le contenu du fichier de conf

		# (b) Solution **depuis le client**: copier le fichier de conf depuis le client vers le serveur en ssh
		# (!!!) la commande ci-dessous n'est qu'un exemple, au format 
		# (!!!) scp -P <port> -r <source> <user sudo>@<IP du serveur>:<destination>
		# (!!!) il faut remplacer le port, le chemin, le user et l'hôte par les bonnes valeurs
		scp -P 22 -r /chemin/vers/le/fichier/en/local/wg0.conf user@1.1.1.1:/etc/wireguard/ 

	# 5. [Depuis le serveur] Sécuriser les permissions
	sudo chmod 600 /etc/wireguard/wg0.conf

	# 6. Tester manuellement la connexion
	sudo wg-quick up wg0
	sudo wg # affiche les informations de debug, on doit voir des bytes échangés
	ping 10.4.99.20 # IP de Arnaud
	sudo wg-quick down wg0 # arrête le VPN

	# 7. Configurer le démarrage du VPN au boot
	#    explications: la syntaxe `wg-quick@<nom-du-fichier>` va chercher
	#    le fichier de configuration dans /etc/wireguard/<nom-du-fichier>.conf
	#    Il faut donc indiquer le nom du fichier sans le “.conf” après le @
	sudo systemctl enable wg-quick@wg0.conf
	sudo systemctl daemon-reload
	sudo systemctl status wg-quick@wg0 # vérifier que le service est *inscrit*
	# Tester le service VPN
	sudo systemctl start wg-quick@wg0.conf
	sudo systemctl status wg-quick@wg0.conf # vérifier que le service est *actif*
	sudo wg # vérifier la connexion (échange de bytes)
	# On éteint
	sudo systemctl stop wg-quick@wg0.conf
	sudo systemctl status wg-quick@wg0 # vérifier que le service est *éteint*
	sudo wg # vérifier que la connexion est éteinte (pas d'échange de bytes)

	# 8. Vérifier que le VPN démarre au boot
	# (!!!) Attention : on va redémarrer le serveur
	sudo reboot
	sudo systemctl status wg-quick@wg0
	sudo wg

	# (9. *Troubleshooting* Supprimer le service)
	sudo systemctl stop wg-quick@wg0.conf
	sudo systemctl disable wg-quick@wg0.conf
	sudo rm -i /etc/systemd/system/wg-quick@wg0*
	sudo systemctl daemon-reload
	sudo systemctl reset-failed


# ==== B) Example d'un fichier de configuration ====
	# ===== CLIENT VPN ===========
	[Interface]
	# Adresse IP du client à l'intérieur du VPN (IP fixe NAT'tée vue par les autres utilisateurs du VPN)
	Address = a.a.a.a/32
	# Clef privée du client (secret par client => ne pas communiquer ni ne sauvegarder
	#  ailleurs que sur le PC client ou serveur Odoo qui l'utilise)
	PrivateKey = aaaa=
	#DNS = 192.168.120.254
	MTU = 1340

	# ==== SERVEUR VPN ==========
	[Peer]
	# Clef publique du du serveur
	PublicKey = e/aaaaa=
	# Adresse et port du serveur
	Endpoint = host.fr:8000
	# Range d'adresses IP qui doivent être routées à travers le VPN
	# Il faut à la fois mettre le réseau du VPN ET le réseau distant
	AllowedIPs = 10.4.99.0/24
	# keepalive pour maintenir la connexion si le client se trouve derrière un NAT
	PersistentKeepalive = 25


# ==== C) Etapes côté serveur relais (**brouillon**) ====
	# 1. Générer une paire de clef
	wg genkey > private.key
	wg pubkey < private.key > public.key
	sudo mkdir -p /etc/wireguard
	
	# 2. Créer le fichier de configuration
	umask 600
	vi /etc/wireguard/wg0.conf
	# copier le contenu du fichier de conf

	# 3. Connexion au serveur 
	ssh ...
