
### Document Purpose ###
# Provides blocks of code to copy/paste in Ubuntu shell to install a Odoo server
# Odoo v18


### Context ###
# Root user originally named "ubuntu" (like for OVH Ubuntu server)

# ============
# Chapters:

# I/ Going straight to proper Odoo app running (minimal state)
# 0 - OS basic components
# 1 - Odoo dependencies (Python & PostgreSQL)
# 2 - Prepare Odoo confs & logs
# 3 - Install & launch Odoo itself (code from github OCA)
# 4 - Setting reverse-proxy and HTTPs with ngxing and cerbot (Let's encrypt certificate)
# 5 - Create Odoo service (auto-launcher at server boot), for PROD and DEV

# II/ Optional components of Odoo
# 6 - GeoLite2-City.mmdb & GeoLite2-Country.mmdb
# 7 - Email server with Postfix (yet: discarded, passerel-mode to Microsoft 365)

# III/ Enhance performance, security & administration
# 8 - PostgreSQL : optimize performance & install pgadmin4 for administration
# 9 - Install Pgadmin4
# 10 - Server hardening (last but not least !!)
# 11 - Administration: Ubuntu accounts, SSH accesses for other developpers & github
# 12 - Connection to Odoo & configurations from web backend interface
# 13 - Printers in Odoo




# ========================================================================
# 0 - OS basic components
# ========================================================================

	# 0 : add SSH keys

	# 0.1 - Update Ubuntu server
		sudo apt update
		sudo apt upgrade -y

	# 0.2 - Install basic fonts
		sudo apt-get install -y gsfonts xfonts-base xfonts-75dpi fontconfig

	# 0.3 - Verify what languages are installed, and install the 3 main ones fr_FR, en_US, en_GB in UTF8
		# Docs : https://www.thomas-krenn.com/en/wiki/Configure_Locales_in_Ubuntu
		locale -a # print languages
		sudo locale-gen fr_FR.UTF-8 # add languages if needed
		sudo locale-gen en_US.UTF-8
		sudo locale-gen en_GB.UTF-8

		# (note:) Below conf allow LANG to affects date and number user format output while LC_MESSAGES keeps logs messages in English for instance
		printf "
		LANG=fr_FR.UTF-8
		LC_MESSAGES=POSIX
		" | sudo tee /etc/default/locale

	# 0.4 - Remove default "ubuntu" account (OVH)
		# Create new user "arnaud"
		sudo adduser arnaud && sudo adduser arnaud sudo && sudo su - arnaud
		# generate ssh key : https://phoenixnap.com/kb/generate-ssh-key-debian-10

		# Remove former user (/!\ test a direct SSH arnaud@erp.aluval.fr before doing so)
		sudo userdel -f ubuntu
		
		# if process from account to be deleted are in used, use:
		ps -e # list processes
		sudo KILL -9 <pid> # kill <pid> process

		# list all local users (and confirm "ubuntu" is absent)
		cut -d: -f1 /etc/passwd






# ========================================================================
# 1 - Odoo dependencies (Python & PostgreSQL)
# ========================================================================

	# 1.1 - Install Python
	sudo apt install -y python3-dev python3-pip python3-wheel python3-venv python3-virtualenv

	# 1.2 - Install PostgreSQL & Odoo databases
		# install PostgreSQL
		sudo apt install -y postgresql

		# set a password on "postgres" superuser
		# (*) New SSH shell: "postgres" account
		# (i) check .secrets file
		sudo su - postgres
		psql
		\password postgres
		\q
		
		# 3.3 - Create Postgre user for Odoo and respective database
		# (*) Still from "postgres" account
		# (note:) those are not SQL but binary-commands from postgres package
		# If needed to be RUN for another user, use impersonation: sudo su - postgres -c "command"
		dropdb o18-flavigny-prod -e
		dropdb o18-flavigny-staging -e
		createuser odoo
		createdb o18-flavigny-prod --owner=odoo -e
		createdb o18-flavigny-staging --owner=odoo -e
		psql
		\du
		\l
		\q
		exit
		
	# 1.3 - Packages of binary libraries not existing in pip
		sudo apt install -y build-essential libpq-dev libxslt-dev libzip-dev libldap2-dev libsasl2-dev libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libxml2-dev libxslt1-dev zlib1g-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev libxrender1 xmlsec1
		# for account_invoice_import_simple_pdf
		sudo apt install -y libmupdf-dev mupdf mupdf-tools poppler-utils

	# 1.4 - "wkhtmltopdf" from Odoo source /!\ not with apt-get, since it is not exactly the same package
		# As of 2026-01-21: stable version "0.12.6.1-3"
		# Indicated in: https://www.odoo.com/documentation/18.0/administration/on_premise/packages.html
		# See: https://wkhtmltopdf.org/
		# Choose the .deb file with  "ubuntu jammy" keywords

		# Check If existing other version of wkhtmltopdf is already installed and remove it if needed
		wkhtmltopdf --version
		sudo apt-get remove --purge wkhtmltopdf wkhtmltox odoo-wkhtmltopdf
		dpkg -l | grep wkhtml ; dpkg --purge wkhtmltox

		# download & install
		version="0.12.6.1-3"
		temp_file="/tmp/wkhtmltopdf-nightly-${version}.deb"
		rm $temp_file
		wget "https://github.com/wkhtmltopdf/packaging/releases/download/${version}/wkhtmltox_${version}.jammy_amd64.deb" -O $temp_file # download the correct file
		sudo dpkg -i $temp_file

		# in case of dependencies issues, solve them
		sudo apt-get -f install

		# verify if current version is installed,
		wkhtmltopdf --version


# ========================================================================
# 2 - Prepare Odoo confs & logs
# ========================================================================
	
	# 2.1 - Create user Odoo
		sudo adduser odoo
		# (note:) sudo adduser odoo --disabled-password # for testsonv only
	
	# 2.2 - Create Odoo confs in /etc/odoo and harden access
		sudo mkdir /etc/odoo
		
		sudo rm /etc/odoo/staging.conf
		sudo nano /etc/odoo/staging.conf
		sudo rm /etc/odoo/prod.conf
		sudo nano /etc/odoo/prod.conf
		
		# permissions
		sudo chown -R odoo /etc/odoo
		sudo chmod u=r,g=rw,o=r /etc/odoo/prod.conf
		sudo chmod u=r,g=rw,o=r /etc/odoo/staging.conf

	# 2.3.1 - Creation and hardening of log file too
		sudo mkdir /var/log/odoo
		sudo chown -R odoo /var/log/odoo
	
	# 2.3.2 - Configure logrotation (i) "confs/logrotate-odoo.conf"
		sudo apt-get install -y logrotate # if not already installed
		sudo nano /etc/logrotate.d/odoo
		sudo chown root:root /etc/logrotate.d/odoo



# ========================================================================
# 3 - Install & launch Odoo itself (code from github OCA)
# ========================================================================

	# (*) New SSH shell: "odoo" account
	sudo apt install git -y
	sudo su - odoo

	# 3.0 - Github
		# (*) Still on odoo account

		# creates .ssh folder
		mkdir -p ~/.ssh && chmod 700 ~/.ssh

		# create github key locally on the user's session
		gitkey_file="ed25519_github_arnaud"
		ssh-keygen -t ed25519 -C "arnaudlayec@gmail.com" -f ~/.ssh/$gitkey_file
		# -C: comment
		# f: output_keyfile

		# copy the public key to the github.com account > Settings > SSH keys
		cat ~/.ssh/$gitkey_file.pub

		# load the key in user session
		eval "$(ssh-agent -s)" && ssh-add ~/.ssh/$gitkey_file

		# test de la connexion
		ssh -T git@github.com

	# 3.1 - Install code from source to the folder ~/env
		cd ~
		odir="o18"
		git clone -b "18.0" --single-branch --depth=1 git@github.com:OCA/OCB $odir
		
		# (note): -b: remote branch
		# --depth==1: to only catch main changes to the code and not all small pushes
		# last "string": folder path

	# 3.2 - Creation of virtual env
		# /!\ before "pip"
		virtualenv $odir
		source ~/$odir/bin/activate # activation
		# now next shell lines should be pre-fixed with virtualenv name like (aaaa)

	# 3.3 - Odoo requirements installation inside virtualenv (pip)
		# (*) inside virtualenv
		
		# update pip
		python -m pip install -U pip
		
		# Officials requirements
		python -m pip install -r ~/$odir/requirements.txt
		
		# Dev requirements /!\ do not install on PROD
			# Watchdog: for automatic reload feature using
			# jingtrang: for better XML Validation (AssertionError), can also by used unitary from cmdline with pyjing
			# sudo apt install default-jre # java required for jingtrang
			python -m pip install --upgrade watchdog ipdb click-odoo # jingtrang
		
		# Other modules requirements (specific to client)
			# auth_saml
			# python -m pip install --upgrade pysaml2
		
		# OCA (server-backend / base_external_dbsource_...)
			# sudo apt-get install tdsodbc
			# python -m pip install --upgrade sqlalchemy pymssql
		# carpentry alternative to read .MDB
			# sudo apt-get install mdbtools
		# aluval (read xlsx file)
			# python -m pip install pandas

		# Community modules requirements (list from Alexis DE LATTRE)
			# OCA stuff
			python -m pip install --upgrade pre-commit oca-decorators openupgradelib odoo_test_helper flake8 cachetools
			# Not listed in the officiel requirements but required
			python -m pip install --upgrade pygments
			## Upgrade libs from odoo requirements.txt that are too old
			python -m pip install --upgrade python-stdnum ofxparse
			## Needed by commonly-used community modules
			python -m pip install --upgrade phonenumbers unidecode Pillow unicodecsv simplejson html2text openpyxl python-barcode
			python -m pip install --upgrade factur-x
			# Others
			python -m pip install --upgrade ovh regex dateparser pymupdf mock pyfrdas2 requests_oauthlib pycountry astor apispec pyquerystring cerberus parse-accept-language
		
		# Install "odoo" command in virtualenv
		python -m pip install -e ~/$odir/ # https://stackoverflow.com/questions/42609943/what-is-the-use-case-for-pip-install-e

	# 3.4 - Check if Odoo command is ok
		odoo --version
		
	# 3.5.2 - AK build: install OCA & custom modules
		python -m pip install git+https://github.com/akretion/ak
		rm ~/$odir/spec.yaml
		nano ~/$odir/spec.yaml
		ak build -c ~/$odir/spec.yaml

	# 3.5.7 - Update addons-path in confs file (if needed)
		# (*) from SUDOER shell window
		sudo su - arnaud
		
		sudo rm /etc/odoo/staging.conf
		sudo nano /etc/odoo/staging.conf
		sudo rm /etc/odoo/prod.conf
		sudo nano /etc/odoo/prod.conf
		
	# 3.6 From Odoo session, finish setup & launch the servers
		# Verify: 1/ the position because of relative addons paths for DEV 2/ Virtualenv is running
		cd ~/$odir/
		pip -V
		
		# initialize database
		source $odir/bin/activate
		odoo -c /etc/odoo/staging.conf -i base --load-language=fr_FR --stop-after-init
		odoo -c /etc/odoo/prod.conf -i base --load-language=fr_FR --stop-after-init

		# test server launch (CTRL+C between the 2)
		odoo -c /etc/odoo/staging.conf
		odoo -c /etc/odoo/prod.conf
	
	# 6.7 - Read the logs to check if everything is OK (from another ssh session)
		tail -f /var/log/prod
		tail -f /var/log/staging



# ========================================================================
# 4 - Setting reverse-proxy and HTTPs with ngxing and cerbot (Let's encrypt certificate)
# ========================================================================

	# 4.1 - Install nginx & certbot (for deployment of Let's encrypt certificate)
	# (note:) nginx must be installed before certbot
		sudo apt-get -y install nginx

	# 4.2 - Request certificates
		# 4.2.1 - Letsencrypt
			sudo apt-get install certbot python3-certbot-nginx # install Certbot
			# sudo snap install --classic certbot # install Certbot with snapd (sudo apt-get install snapd)
			# sudo ln -s /snap/bin/certbot /usr/bin/certbot # ensures certbot command can be run
			
			sudo certbot certonly --nginx -d odoo.abbaye-flavigny.fr # just install a certificate
			sudo certbot certonly --nginx -d odoo-staging.abbaye-flavigny.fr
			sudo certbot certonly --nginx -d pgadmin4.abbaye-flavigny.fr
			sudo certbot certificates

			# export certificates
			sudo cat pathnametocertificate
			
			# test automatic renewal
			sudo certbot renew --dry-run
			# if need to revoke:
			sudo certbot revoke --cert-path /etc/letsencrypt/live/www.domain.fr/fullchain.pem --key-path /etc/letsencrypt/live/www.domain.fr/privkey.pem
			sudo certbot revoke --cert-path /etc/letsencrypt/live/pgadmin4.abbaye-flavigny.fr/fullchain.pem --key-path /etc/letsencrypt/live/pgadmin4.abbaye-flavigny.fr/privkey.pem

		# # *OR* 4.2.2 - Self-signed
		# 	sudo openssl req -x509 -nodes -days 18250 -newkey rsa:2048 -keyout /etc/ssl/private/odoo-selfsigned.key -out /etc/ssl/certs/odoo-selfsigned.crt

		# 	# create a strong Diffie-Hellman (DH) group, which is used in negotiating Perfect Forward Secrecy with clients
		# 	# https://en.wikipedia.org/wiki/Forward_secrecy
		# 	sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096

	# 4.3 Configure & launch nginx

		# 4.3.1 - Stop appache (if already running)
			curl http://localhost # check if :80 port is listening : failure expected, like "Couldn't connect"
			sudo systemctl disable apache2.service
			sudo service apache2 stop # if needed, because replaced by nginx
			sudo /etc/init.d/apache2 stop

		# 4.3.2 - Install, configure
			# remove default configuration
			sudo rm /etc/nginx/sites-enabled/default
			sudo rm /etc/nginx/sites-available/default

			nginx_conf_files=("odoo" "odoo-staging") # 2 confs files for 2 servers
			for file in ${nginx_conf_files[@]}; do
				sudo rm /etc/nginx/sites-available/$file
				sudo rm /etc/nginx/sites-enabled/$file
				
				sudo nano /etc/nginx/sites-available/$file # edit configuration
				sudo ln -s /etc/nginx/sites-available/$file /etc/nginx/sites-enabled/$file # creates symbolic link from dir "sites-available" to "sites-enabled" (best practise)
			done

			sudo nginx -t # verify nginx config
	
	# 4.3.3 - Restart
		sudo service nginx reload
		sudo nginx -s reload

		# if needed to stop:
		# sudo nginx -s stop


# ========================================================================
# 5 - Create Odoo service (auto-launcher at server boot), for PROD and DEV
# ========================================================================

	# (note:) Example of systemd file: https://github.com/odoo/odoo/blob/18.0/debian/odoo.service

	sudo rm /lib/systemd/system/odoo-staging.service
	sudo nano /lib/systemd/system/odoo-staging.service
	sudo rm /lib/systemd/system/odoo-prod.service
	sudo nano /lib/systemd/system/odoo-prod.service
	# (i) copy/paste the confs file "systemd-service-odoo-[prod/dev].conf"

	# harden service file
	sudo chown root:root /lib/systemd/system/odoo-staging.service
	sudo chown root:root /lib/systemd/system/odoo-prod.service

	# register & start the services
	sudo systemctl enable odoo-staging.service
	sudo systemctl enable odoo-prod.service
	sudo systemctl start odoo-staging
	sudo systemctl start odoo-prod

	# check the service status
	sudo systemctl status odoo-staging
	sudo systemctl status odoo-prod

	# to stop the service (if needed)
	sudo systemctl stop odoo-staging
	sudo systemctl stop odoo-prod
	# to restart the service (if needed)
	sudo systemctl restart odoo-staging
	sudo systemctl restart odoo-prod

	# :) :) :) :) :) :) :) :) :) :) :) :) :) 
	# ODOO IS READY !
	https://erp.aluval.fr
	https://erp-dev.aluval.fr




# ========================================================================
# 6 - GeoLite2-City.mmdb & GeoLite2-Country.mmdb
# ========================================================================
	# (i) Check the secrets
		maxmind_user="aaaaaaaaa" # arnaud ID
		maxmind_key="aaaaaaaaaa"
	
	# 6.1 - Prepare download
		cd ~
		mkdir "Downloads" && cd "Downloads"
		URL_GeoLite2_City="https://download.maxmind.com/geoip/databases/GeoLite2-City/download?suffix=tar.gz"
		URL_GeoLite2_Country="https://download.maxmind.com/geoip/databases/GeoLite2-Country/download?suffix=tar.gz"
	
	# 6.2 - download & update "$date" var
		# (note:) to list content of an archive: tar -tf archive.tar.gz
		wget --content-disposition --user=$maxmind_user --password=$maxmind_key $URL_GeoLite2_City
		wget --content-disposition --user=$maxmind_user --password=$maxmind_key $URL_GeoLite2_Country
	
		ls
		date="20240510" # /!\ TO UPDATE
	
	# 6.3 - Unzip, move, clear
	# Unzip
		tar -xvf "GeoLite2-City_$date.tar.gz" --wildcards '*.mmdb'
		tar -xvf "GeoLite2-Country_$date.tar.gz" --wildcards '*.mmdb'
	
	# Move
	# (note:) for Odoo, .mmdb GeoIP files must be stored in default location /usr/share/GeoIP/
		sudo mkdir /usr/share/GeoIP/
		sudo mv ~/Downloads/GeoLite2-City_$date/GeoLite2-City.mmdb /usr/share/GeoIP/GeoLite2-City.mmdb
		sudo mv ~/Downloads/GeoLite2-Country_$date/GeoLite2-Country.mmdb /usr/share/GeoIP/GeoLite2-Country.mmdb
		ls /usr/share/GeoIP/
	
	# Clear
		rm -rf ~/Downloads/Geo*




# ========================================================================
# 7 - Email server with Postfix (for now: discarded, passerel-mode to Microsoft 365)
# ========================================================================
	# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-as-a-send-only-smtp-server-on-ubuntu-22-04

	# Aligning server hostname to mail server hostname
	hostname aluval.fr

	# 7.1 - Install postfix
		sudo apt install libsasl2-modules postfix mailutils
		# choose "2. Config 'Site Internet'" when asked
		# FQDN : aluval.fr
		# ** If configuration wizard does not appear: sudo dpkg-reconfigure postfix
	
	# 7.2 Configure Postfix
		sudo cp /etc/postfix/main.cf /etc/postfix/main.cf_backup
		sudo nano /etc/postfix/main.cf
		sudo nano /etc/postfix/sasl_passwd

		# restart
		sudo systemctl restart postfix

	# 7.3 Test
		echo "Body email" | mail -s "Sub line" arnaudlayec@gmail.com
	
 https://www.odoo.com/documentation/18.0/administration/on_premise/email_gateway.html


Suivre https://www.linuxbabe.com/mail-server/setting-up-dkim-and-spf
commencer à la partie "Setting up DKIM"
remplacer "default" par "odoo"
remplacer 2048 par 1024

Mettre à jour la DNS :
- SPF
- DKIM : odoo._domainkey.nuska.fr
- DMARC
- reverse DNS du serveur odoo  (chez OVH, si on veut que la reverse soit nuska.fr, il faut qu une requête DNS sur nuska.fr pointe sur odoo => mettre odoo.nuska.fr en reverse ?)

Vérifier la DNS :
dig odoo._domainkey.nuska.fr TXT
dig _dmarc.nuska.fr TXT
vérifier la reverse



# ======================================
# 8 - PostgreSQL : optimize performance
# ======================================

	# (*) From "SUDOER" session

	# (note:) Use a trick for configs precedence: replace default conf file by a "router" file which manage precedence of configurations
	# The route file include 1st the renamed "postgresql_default.conf" and THEN the "postgresql_custom.conf"
	# Thus, all default confs are kept somwhere (default file is just renamed) AND custom configs applies in controled precedence
	postgresql_dir=/etc/postgresql/16/main
	sudo mv $postgresql_dir/postgresql.conf $postgresql_dir/postgresql_default.conf
	printf "
	include 'postgresql_default.conf'
	include 'postgresql_custom.conf'" | sudo tee $postgresql_dir/postgresql.conf
	
	# (i) copy the content of "confs/postgresql_custom.conf"
	sudo nano $postgresql_dir/postgresql_custom.conf
	
	# restart service to apply configs
	sudo service postgresql restart
	
	# check if ok (should be empty):
	sudo su - postgres -c psql
	select sourcefile, name,sourceline,error from pg_file_settings where error is not null;
	\q





# ========================================================================
# 9 - Install Pgadmin4
# ========================================================================

	# https://www.pgadmin.org/download/pgadmin-4-apt/
	# step1 : https://www.digitalocean.com/community/tutorials/how-to-configure-nginx-as-a-reverse-proxy-on-ubuntu-22-04 
	# step2 : https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-pgadmin-4-in-server-mode-on-ubuntu-22-04

	# 9.1 - Depdencies & confs files (in sudo)
	# 9.1.2 - Install pgadmin4 prerequisites
		sudo apt install -y libgmp3-dev libpq-dev

	# 9.1.3 - create pgadmin4 user (don't switch to it yet)
		sudo adduser pgadmin4

	# 9.1.4 - create directories where pgAdmin will store its sessions data, storage data, and logs
		sudo mkdir -p /var/lib/pgadmin4/sessions
		sudo mkdir /var/lib/pgadmin4/storage
		sudo mkdir /var/lib/pgadmin4/azure
		sudo mkdir /var/log/pgadmin4

	# 9.1.5 - harden ownership
		sudo chown -R pgadmin4:pgadmin4 /var/lib/pgadmin4
		sudo chown -R pgadmin4:pgadmin4 /var/log/pgadmin4
		
	# 9.2 - Install the sources & launch
		# curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
		# sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update'
		# sudo apt install pgadmin4-web 
		# sudo apt-get gunicorn
		
	# 9.2.1 Switch to pgadmin4 account
		# (*) User switch to pgadmin4
		sudo su - pgadmin4

	# 9.2.2 - creation & activation of python virtual-env (from ~ path)
		virtualenv env
		source env/bin/activate
		cd ~/env/

	# 9.2.3 - install pgadmin4 & gunicorn
		python -m pip install -U pip # update pip
		python -m pip install pgadmin4 gunicorn

	# 9.2.4 - Configure pgadmin4
	# (notes:) tabs matters here because it's Python
printf "
LOG_FILE = '/var/log/pgadmin4/pgadmin4.log'
SQLITE_PATH = '/var/lib/pgadmin4/pgadmin4.db'
SESSION_DB_PATH = '/var/lib/pgadmin4/sessions'
STORAGE_DIR = '/var/lib/pgadmin4/storage'
AZURE_CREDENTIAL_CACHE_DIR = '/var/lib/pgadmin4/azure'
SERVER_MODE = True
" | tee  ~/env/lib/python3.12/site-packages/pgadmin4/config_local.py

	# 9.2.5 - Run pgAdmin setup script to set login credentials:
		# (note:) we need Nginx to be up to be able to test
		python ~/env/lib/python3.12/site-packages/pgadmin4/setup.py setup-db
		
		# test publishing via gunicorn in cmd-line and CTRL+C
printf "virtualenv env
source env/bin/activate
cd /home/pgadmin4/env/
gunicorn --bind unix:/tmp/pgadmin4.sock --workers=1 --threads=25 --chdir /home/pgadmin4/env/lib/python3.12/site-packages/pgadmin4 pgAdmin4:app
" | tee /home/pgadmin4/pgadmin4_start.sh
		chmod +x ~/pgadmin4_start.sh
		
		# Start with the shortcut pgadmin4_start.sh
		/home/pgadmin4/pgadmin4_start.sh
	
	# /!\ Can't work (issue in pgadmin4 ?)
	# Last try with conf in "confs/systemd-service-pgadmin4"
	# 9.3 - create scheduled task at boot with systemctl to start pgadmin4 with unicorn

	# 9.3.1 - (*) Switch account to a SUDOER
		sudo su - arnaud
		
	# 9.3.2 - Configure & start systemctl task
		sudo rm /lib/systemd/system/pgadmin4.service
		sudo nano /lib/systemd/system/pgadmin4.service
		# (i) copy/paste from file "confs/systemd-service-pgadmin4.conf"

		sudo chown root:root /lib/systemd/system/pgadmin4.service # harden service file
		sudo systemctl enable pgadmin4.service # register the service
		sudo systemctl start pgadmin4 # start the new service
		sudo systemctl status pgadmin4 # check the service status
		
		# to stop (if needed)
		sudo systemctl stop pgadmin4
		# to restart (if needed)
		sudo systemctl restart pgadmin4 




# ===================================================================
# 11 - Server hardening
# ========================================================================

	# 11.0 - Install SSH keys for remote administration in ".ssh/authorized_keys" file of each Ubuntu session
		# Public key: on server-side
		# Private key: on client-side
		# https://phoenixnap.com/kb/generate-setup-ssh-key-ubuntu

		# LINUX:
			# ssh-keygen
			# cat key.pub
		# WINDOWS:
			# Generate bi-keys on windows client-side environment:
			# In cmd:
				# ssh-keygen
			# In elevated powershell:
				# Start-Service ssh-agent
				# Set-Service ssh-agent -StartupType Automatic
			# Back to user-cmd:
				# ssh-add c:/Users/You/.ssh/name_of_chosen_ssh_key

		# Add SSH public keys to each Ubuntu accounts (in authorized_keys sessions' file)

		# (*) Switch accounts: "arnaud", "akretion", and "developers"
		sudo su - "dev"
		ssh_key_private="aaaaaaaaaaaa"

		# creates .ssh folder and special "authorized_keys" file
		mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys
		
		# applies relevant permissions
		chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
		
		# writes public key
		echo $ssh_key_private > ~/.ssh/authorized_keys
		
		# print file content to verify
		cat ~/.ssh/authorized_keys
	
	# 11.1 - Automatic updates (patching) with unattended-upgrades
		# https://www.linuxtricks.fr/wiki/wiki.php?id_contents=2674
		# https://www.cyberciti.biz/faq/set-up-automatic-unattended-updates-for-ubuntu-20-04/

		# 11.1.1 - Install if not already installed
		sudo apt install -y unattended-upgrades update-notifier-common

		# 11.1.2 - Configure
			# Guided initial config (user-interface)
			sudo dpkg-reconfigure -plow unattended-upgrades
			
			# Set custom configurations (to copy from "confs/unattended-upgrade.ini" helper file)
			# we create a new file starting with "99" so its configurations overwrites the ones in the folder (especially 20auto-upgrades and 50unattended-upgrades)
			sudo nano /etc/apt/apt.conf.d/99unattended-upgrades-custom
			# copy/paste content from ubuntu_unattended_upgrade.conf

			# set email ID
			printf "email_address=arnaudlayec@gmail.com" | sudo tee /etc/apt/listchanges.conf

		# 11.1.3 - Turn on
		sudo unattended-upgrades enable

		# 11.1.4 - Confirm it is running well
		sudo unattended-upgrades --dry-run -d

	# 11.2 - Prevention of accidentally human-mistake while shutting down or rebooting the machine
		# 11.2.1 - restart protection
		sudo apt-get -y install molly-guard
		
		# 11.2.2 - ssh color
		# https://askubuntu.com/questions/310498/change-terminal-colour-based-on-ssh-session
		nano ~/.bashrc

		# set force_color to `True`
		# find `PS1` and replace by:
		PS1='${debian_chroot:+($debian_chroot)}\[\033[01;35m\]\u@\h\[\033[00m\]:\[\033[01;34m\] \w\[\033[01;37m\] > '


	# 11.3 - Brute-force protection (default configuration is already nice)
		# for more info: https://fr-wiki.ikoula.com/fr/Mettre_en_place_fail2ban_sur_Debian#Mise_en_place
		sudo apt-get -y install fail2ban

	# 11.4.1 - Disable root account (without removing it)
		# https://gist.github.com/lokhman/cc716d2e2d373dd696b2d9264c0287a3
		sudo passwd -l root

	# 11.4.2 - Ensure only root account has UID 0 with full permissions on system
		awk -F: '($3 == "0") {print}' /etc/passwd
		# should respond: root:x:0:0:root:/root:/bin/bash

	# 11.5.1 - Loading SSH hardened config
		sudo rm /etc/ssh/sshd_config.d/ssh_hardening.conf
		sudo nano /etc/ssh/sshd_config.d/ssh_hardening.conf
		# see file "confs/ubuntu_hardening_ssh_pam.conf" to copy/paste
		sudo systemctl daemon-reload
		sudo systemctl restart ssh.socket

	# 11.5.2 - Adding MFA to SSH
		# https://www.linuxbabe.com/ubuntu/two-factor-authentication-ssh-key-ubuntu
		# https://serverfault.com/questions/966516/linux-pam-ssh-key-2fa-google-authenticator-password-specify-auth-requir
		# Configure Two-Factor auth for SSH
		sudo apt install -y libpam-google-authenticator
		google-authenticator # run to create a secret key in home directory of the curent user
		
		# Make MFA optional (needed because of shared accounts like "akretion" and "developers")
		sudo nano /etc/pam.d/sshd
		# Add this line after @include common-auth (/!\ with tabs and not spaces between the string parts)
		"auth   required   pam_google_authenticator.so	nullok"
		
		sudo service ssh restart

	# 11.5.3 - Changing SSH port
		# sudo mkdir -p /etc/systemd/system/ssh.socket.d
		# printf "
		# [Socket]
		# ListenStream=
		# ListenStream=2232
		# " | sudo tee /etc/systemd/system/ssh.socket.d/listen.conf
		
		# sudo systemctl daemon-reload
		# sudo systemctl restart ssh.socket

	# 11.6 - Local firewall
		sudo ufw enable
		sudo ufw default deny incoming # /!\ use "deny" and never "reject"
		sudo ufw default allow outgoing
		sudo ufw allow 2232 # ssh
		# sudo ufw allow smtp # if postfix is installed. Recommended: move 25 port to another, like 465, 587, or 2525
		sudo ufw allow http
		sudo ufw allow https
		sudo ufw reload
		sudo ufw status

		sudo tail -f /var/log/ufw.log # log watching, if needed
		
		# List what services are listening on TCP or UDP sockets (from the machine, locally)
		sudo lsof -i -P -n | grep -v ESTABLISHED

		# List services exposed to the Internet
		sudo apt-get install nmap
		sudo nmap -v -sV -p- erp.aluval.fr
		
		
	# /!\ === at this point a new ssh session BY KEEPING EXISTING ONE should be establish on ssh@erp.aluval.fr -p 2232
	# if OK, the 1st one should be shutted off (port 22)
	ssh arnaud@erp.aluval.fr -p 2232
	
	# ===========

	# 11.7 - sysctl.conf (IPv4 et v6, execshield, syn flood defense, turn on IP adress verification, prevent from IP spoofing)
		sudo rm /etc/sysctl.conf
		sudo nano /etc/sysctl.conf
		# copy file content "confs/ubuntu_hardening_sysctl.conf"
		
		# Apply new settings
		sudo sysctl -p

	# 11.8 - Disable IRQ Balance (to make sure no hardware interruption in threads)
		sudo apt-get remove irqbalance -y

	# 11.9 - Prevent against shared memory attack
		# https://bookofzeus.com/harden-ubuntu/server-setup/secure-shared-memory/
		sudo nano /etc/fstab

		# add:
"
# secure shared memory
tmpfs     /run/shm    tmpfs	defaults,noexec,nosuid	0	0
"

		# appply the changes:
		sudo mount -a

	# 11.10 - Set hostname in /etc/hostname and /etc/hosts
		# https://bookofzeus.com/harden-ubuntu/server-setup/set-hostname-and-host/
		sudo nano /etc/hostname
		sudo nano /etc/hosts

	# 11.11 - Security limits (e.g. number of processes)
		# https://bookofzeus.com/harden-ubuntu/server-setup/set-security-limits/
		sudo nano /etc/security/limits.conf
		# add this line (high value because can impact performances)
"
odoo	hard	nproc	300
"

	# 11.12 - App Armor
		# Check if running well
		# https://help.ubuntu.com/community/AppArmor
		sudo aa-status


	# going further :
	# - better check CIS recommendations: https://ubuntu.com/engage/a-guide-to-infrastructure-hardening
	# - test the security posture of a web server : https://www.ssllabs.com/ssltest/
	# - IPS (Intrusion Prevention System)
	# - web application firewall : https://infosec.mozilla.org/guidelines/web_security








# ========================================================================
# 12 - Connection to Odoo & configurations from web backend interface
# ========================================================================
	
	# Creation & git init of addons-aluval/
	odir="o18"
	cd ~/$odir/addons-aluval
	git init

	# Clone Aluval Odoo modules
	git pull git@github.com-arnaud:arnaudlayec/aluval

	# Install the environment
	# (*) from sudoer
	sudo systemctl stop odoo-staging
	tail -f /var/log/odoo-staging
	$odir/odoo-bin -c /etc/odoo/staging.conf -i aluval_base --stop-after-init
	
	sudo systemctl stop odoo-prod
	tail -f /var/log/odoo-prod
	$odir/odoo-bin -c /etc/odoo/prod.conf -i aluval_base --stop-after-init
	

	# Manual config
	1. "admin" account: rename, set stronger password, set MFA
	2. ir.config_parameter
		Global Settings
			- instal fr_FR, and set default language
			- company infos settings and contact's company
			- report layout (striped)
			- Digest: disable
			- auth_signup.reset_password to 'False' **OR** password policy: 180 days
			- web_window_title
		Default user (internal, public, portal):
			- partners: timezone, lang, country
			- users: notification_type, default action
		System Settings
			- disable ribbon on PROD (ribbon.name to "False")
			- web_m2x_options.create to False
	3. Intégrations
		SAML Providers
			Certificates (public & private)
		Email
			- Inbound gateway(s)
			- Outbound gateway()
			- System Settings (1): mail.default.from_filter, mail.default.from, mail.catchall.domain
			- System Settings (2): mail.catchall.alias, mail.bounce.alias
		Calendar sync -> outlook client ID & secret
		Plugin de messagerie -> activer ou non
	5. data
		Import users, contact, department, department_head, ...
		Sequence : project.code
	
	# Remove unwanted app from Settings > Apps
	 . iap
	 . partner_autocomplete


	# Accounting
		Compta :
		* Créer IBAN et BIC du partenaire de la société
		* Passer sur chaque page de config de la compta
		* Supprimer les taxes inutiles (le faire au préalable sur position fiscale):
			- TVA à l'encaissement
			- 2,1% à la vente
			- 2,1% immobilisation
			- 8,5% ?
		* Positions fiscales :
		* Domestique - France : décocher "VAT required"
		* Intra-EU B2B : vérifier que "VAT required" et "Intrastat" sont cochés

		* Personnaliser les noms et code des journaux
		* Supprimer le journal de stock (éditer la ir.property property_stock_journal au préalable) et le journal de TVA encaissement
		* Lier les journaux de banque aux IBANs
		* Séquences de facture
		* Créer les groupes de compte
		* créer le modes de paiement => mettre un mode de paiement par défaut sur client et fournisseur ?



# ========================================================================
# 13 - Printers in Odoo
# ========================================================================

# Si utilisation du module OCA base_report_to_printer, qui utilise CUPS :
sudo apt install libcups2-dev


sudo apt-get install cups
si HP : sudo apt-get install hplip
sudo adduser odoo lpadmin
BIG FAT WARNING : pour qu'il tienne compte du adduser, il faut faire :
sudo killall cupsd (un restart ne suffit pas !!!)
se connecter via localhost sur 631 pour administration (tunnel ssh)
Editer /etc/cups/cupsd.conf

http://192.9.202.243:631/
(ne PAS mettre d'alias, sinon on a "bad request"


Dans odoo :

Configuration : Mettre à jour les imprimantes => il créé les imprimantes

Sinon, en ligne de commande :

lpadmin -p printer-name -v device-uri -m model -L location -E

ATTENTION, le -E doit bien être à la fin

Exemple pour un zebra réseau en "raw queue" (pas d'option -m) :
lpadmin -p zebra-soa -v socket://scentys-z1-pprktbzcng.dynamic-m.com:9100 -L "Scentys SOA" -E

lpoptions -p hp-magasin -o PageSize=A4

Pour voir l'état des imprimantes :
lpstat -p
printer zebra-soa now printing zebra-soa-1.  enabled since ven. 18 déc. 2015 18:23:34 CET
    The printer is not responding.

Pour voir les options d'une imprimante : lpoptions -p zebra-soa

Pour voir la queue d'impression :
lpstat -o akretion-zebra-eth
akretion-zebra-eth-120  alexis            3072   ven. 18 déc. 2015 18:34:24 CET

=> j'ai 1 job ID 120

Pour supprimer un job de la queue :
lprm <job-id>
pour les annuler tous : lprm -


Dans Odoo

Ajouter le user dans le bon groupe
Paramètres dans les préf user
Paramètre sur le rapport : 2ème onglet : impression + sélectionner imprimante : quand on appelle ce rapport, ça balance direct à l'imprimante





# ========================================================================
# 99 - Installations & configuartions left aside for now (as of Alexis DE LATTRE instructions)
# ========================================================================

sudo apt install wait-for-it node-less gsfonts git vim python3-git libxmlsec1-dev libev-dev 
