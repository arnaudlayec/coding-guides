
# =================== Introduction     ===================
    ### Requirements ###
    # a fresh Debian 12 LTS install, not hardened
    # wish to install NextCloud https://docs.nextcloud.com/server/latest/admin_manual/installation/system_requirements.html
    #--> Nextcloud Hub 10 (31.0.8 RC1)

    ### Hosting specifications ###
    # PulseHeberg.com
    # 2 vCPU, 2 Go RAM, 250GB SATA (RAID 10)
    # Lausanne, Switzerland
    # 193.168.144.229 (2a09:6384:4:229:193:168:144:229)
    # Debian 12 (Bookworm)



# =================== Server hardening ===================

	# Update
        sudo apt update && sudo apt upgrade
	
    # Install SSH keys for remote administration in ".ssh/authorized_keys" file of each Ubuntu session
		# Public key: on server-side
		# Private key: on client-side
		# https://phoenixnap.com/kb/generate-setup-ssh-key-ubuntu

		# on LINUX client:
		ssh-keygen
		cat nameofthekey.pub

		# on DEBIAN server:
		mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys # creates .ssh folder and special "authorized_keys" file
		chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys # applies relevant permissions
        nano ~/.ssh/authorized_keys

	# Prevention of accidentally human-mistake while shutting down or rebooting the machine
		sudo apt-get -y install molly-guard
		
    # ssh color
		# https://askubuntu.com/questions/310498/change-terminal-colour-based-on-ssh-session
		nano ~/.bashrc

		# set force_color to `True`
		# find `PS1` and replace by:
		PS1='${debian_chroot:+($debian_chroot)}\[\033[01;35m\]\u@\h\[\033[00m\]:\[\033[01;34m\] \w\[\033[01;37m\] > '

	# Brute-force protection (default configuration is already nice)
		# for more info: https://fr-wiki.ikoula.com/fr/Mettre_en_place_fail2ban_sur_Debian#Mise_en_place
		sudo apt-get -y install fail2ban

	# Disable root account (without removing it)
		# https://gist.github.com/lokhman/cc716d2e2d373dd696b2d9264c0287a3
		sudo passwd -l root

	# Ensure only root account has UID 0 with full permissions on system
		awk -F: '($3 == "0") {print}' /etc/passwd
		# should respond: root:x:0:0:root:/root:/bin/bash

	# Loading SSH hardened config
        ssh_config_file="/etc/ssh/sshd_config.d/ssh_hardening.conf"
		sudo rm $ssh_config_file
		sudo nano $ssh_config_file
        
            Port 55555
            PermitRootLogin no

            PubkeyAuthentication yes
            PasswordAuthentication no
            PermitEmptyPasswords no

            AllowUsers arnaud

        # Reload config
		sudo systemctl daemon-reload
		sudo systemctl restart ssh

	# Local firewall
		sudo ufw enable
		sudo ufw default deny incoming # /!\ use "deny" and never "reject"
		sudo ufw default allow outgoing
		sudo ufw allow 55555 # ssh

		sudo tail -f /var/log/ufw.log # log watching, if needed
		
		# List what services are listening on TCP or UDP sockets (from the machine, locally)
		sudo lsof -i -P -n | grep -v ESTABLISHED

	# sysctl.conf (IPv4 et v6, execshield, syn flood defense, turn on IP adress verification, prevent from IP spoofing)
		sudo rm /etc/sysctl.conf
		sudo nano /etc/sysctl.conf
		# copy file content "confs/ubuntu_hardening_sysctl.conf"
		
		# Apply new settings
		sudo sysctl -p

	# Set hostname in /etc/hostname and /etc/hosts
		# https://bookofzeus.com/harden-ubuntu/server-setup/set-hostname-and-host/
		sudo nano /etc/hostname
		sudo nano /etc/hosts

	# App Armor
		# Check if running well
		# https://help.ubuntu.com/community/AppArmor
		sudo aa-status


# =================== Prerequisites ===================

    # https://docs.nextcloud.com/server/latest/admin_manual/installation/system_requirements.html

    # ===== Apache 2.4 with mod_php or php-fpm (recommended) =====
        # https://linuxcapable.com/how-to-install-apache-on-debian-linux/
        # Install
        sudo apt install apache2 -y
        apache2 --version
        systemctl status apache2

        # Sites config
        apache_conf_file="/etc/apache2/sites-available/nextcloud.conf"
        sudo rm $apache_conf_file
        sudo nano $apache_conf_file
            
            <VirtualHost *:80>
                DocumentRoot /var/www/nextcloud/
                ServerName nextcloud.arnaudlayec.fr
                ServerAlias *.arnaudlayec.fr
                ErrorLog ${APACHE_LOG_DIR}/error.log
                CustomLog ${APACHE_LOG_DIR}/access.log combined

                <Directory /var/www/nextcloud/>
                    Require all granted
                    AllowOverride All
                    Options FollowSymLinks MultiViews

                    <IfModule mod_dav.c>
                        Dav off
                    </IfModule>
                </Directory>
            </VirtualHost>

        # Activate the Appache HTTP Virtual Host
        sudo a2dissite 000-default.conf # disable the existing default server block file 000-default.conf
        sudo a2ensite nextcloud.conf # enable newly created virtual host file
        sudo apache2ctl configtest # dry run

        # Let's Encrypt Free SSL certificate
        #  Enforcing HTTPS 301 redirects (–redirect)
        #  Implementing the Strict-Transport-Security header (–hsts)
        #  Enabling OCSP Stapling (–staple-ocsp)

        sudo apt install python3-certbot-apache -y
        email="hey@arnaudlayec.fr"
        host="nextcloud.arnaudlayec.fr"
        sudo certbot --apache --agree-tos --redirect --hsts --staple-ocsp --email $email -d $host
        sudo certbot renew --dry-run # dry run of renewal (90 days)

        # For wildcare certificates : https://fr.linux-console.net/?p=21007
        sudo certbot certonly --agree-tos --email hey@arnaudlayec.fr --manual --preferred-challenges=dns -d arnaudlayec.fr -d *.arnaudlayec.fr
        sudo nano /etc/apache2/sites-available/nextcloud-le- # update cert path

        # Monitor performances, on http://193.168.144.229/server-status
        sudo a2enmod status
        apache_status_conf_file="/etc/apache2/mods-enabled/status.conf"
        sudo nano $apache_status_conf_file

            <Location /server-status>
                SetHandler server-status
                Require all granted # or `local`
            </Location>

        # Restart
        sudo systemctl restart apache2

        # Logs
        sudo tail -f /var/log/apache2/access.log
        sudo tail -f /var/log/apache2/error.log

    # ===== Maria DB 10.11 =====
        # # https://linuxgenie.net/how-to-install-mariadb-on-debian-12-bookworm-distribution/
        # # MariaDB version 10 is available for installation in the default Debian 12 repository
        # sudo apt install mariadb-server -y
        # sudo mariadb-secure-installation # default security script
        # sudo systemctl status mariadb
        
        # # Access MariaDB
        # sudo mariadb
        #     SELECT version();
        #     CREATE DATABASE nextcloud;
        #     CREATE USER 'nextcloud'@'localhost' IDENTIFIED WITH auth_socket;
    
    # ===== PostgreSQL =====
        sudo apt-get install -y postgresql

		sudo su - postgres
		psql
		\password postgres
		\q

		# Create `nextcloud` Postgres user and respective database
		dropdb nextcloud -e
		createuser nextcloud
		createdb nextcloud --owner=nextcloud -e
		psql
        \password nextcloud

        # (note:) Use a trick for configs precedence: replace default conf file by a "router" file which manage precedence of configurations
        # The route file include 1st the renamed "postgresql_default.conf" and THEN the "postgresql_custom.conf"
        # Thus, all default confs are kept somwhere (default file is just renamed) AND custom configs applies in controled precedence
        postgresql_dir=/etc/postgresql/15/main
        sudo mv $postgresql_dir/postgresql.conf $postgresql_dir/postgresql_default.conf
        printf "
        include 'postgresql_default.conf'
        include 'postgresql_custom.conf'" | sudo tee $postgresql_dir/postgresql.conf
        
        # (i) copy the content of "confs/postgresql_custom.conf"
        sudo nano $postgresql_dir/postgresql_custom.conf
        
        # restart service to apply configs
        sudo service postgresql restart

    # ===== PHP Runtime 8.3 (recommended) =====
        # Ensure php8.4 is not here
        https://www.php.cn/faq/504364.html
        sudo apt-get purge php*
        sudo a2dismod php*
        sudo apt-get autoremove

        # https://fr.linux-console.net/?p=31554
        # Add PPA referential for PHP, because Debian repository cannot by default contains last PHP version
        sudo apt update
        sudo apt install software-properties-common lsb-release apt-transport-https ca-certificates -y
        sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg # import package's GPP key
        sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' # activate *Sury* referential
        
        sudo apt update # check Sury is enabled
        sudo apt list -a php # list available PHP version

        sudo apt install -y php8.3
        php -v

        # PHP modules
            sudo apt install -y libapache2-mod-php8.3 # to work with apache
            
            # required
            sudo apt-get install -y php8.3-xml php8.3-curl php8.3-GD php8.3-mbstring php8.3-zip php8.3-mysql php8.3-pgsql
            # php8.3-json php8.3-libxml php8.3-openssl php8.3-session php8.3-zlib
            # optional
            sudo apt-get install -y php8.3-intl php8.3-apcu php8.3-imagick php8.3-fileinfo php8.3-bz2 php8.3-bcmath php8.3-gmp
            # sudo apt-get install -y redis-server php-redis # caching
        
        sudo systemctl restart apache2
    

# ================== Source install & config ==================

    # Github
        # generate github key
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        keyname="github_arnaud"
        ssh-keygen -t ed25519 -C "arnaudlayec@gmail.com" -f ~/.ssh/$keyname
        cat ~/.ssh/$keyname.pub
        # copy public key on github account

        # authenticate on the server to github
        filename="github_authenticate.sh"
        touch $filename
        chmod +x $filename
        nano $filename
            gitkey_file="github_arnaud"
            eval "$(ssh-agent -s)" && ssh-add ~/.ssh/$gitkey_file
            ssh -T git@github.com
        ./github_authenticate.sh

    # Sources copy
    nextcloud_dir="/var/www/nextcloud"
    sudo apt-get install git -y
    git clone git@github.com:nextcloud/server -b stable31 --single-branch --depth=1 nextcloud
    sudo mv nextcloud $nextcloud_dir

    # Nextcloud config
    # sudo cp $nextcloud_dir/config/config.sample.php $nextcloud_dir/config/config.php
    sudo nano $nextcloud_dir/config/config.php
        <?php

        $CONFIG = [
            'instanceid' => 'arnaudlayec.fr-20250808',
            'passwordsalt' => '8PjnIO53KLUcMcO1W56MqmKl7Aq9K7r1NMODoBCxd432pQGi9H',
            'secret' => 'aDU52477Rg420Rd7Ox9wH2T7IZ6JVTyYr7LtNJ08li5pzUoow7',
            'trusted_domains' =>
            [
                'arnaudlayec.fr'
            ],
            'datadirectory' => '/var/www/nextcloud/data',
            'dbtype' => 'pgsql',
            'dbhost' => 'localhost',
            'dbname' => 'nextcloud',
            'default_language' => 'fr',
            'default_locale' => 'fr_FR',
            'default_phone_region' => 'FR',
            'default_timezone' => 'Europe/Paris',

            'knowledgebase.embedded' => true,

            'overwrite.cli.url' => 'https://nextcloud.arnaudlayec.fr/',
            'htaccess.RewriteBase' => '/'
        ];

        ?>

    # chmod
    sudo chown -R www-data:www-data $nextcloud_dir # set ownership, recursive
    sudo chmod -R 755 $nextcloud_dir # 755 expected
    ls -l /var/www/ # check the permissions
    
    # PHP INI
        php --ini
        sudo nano /etc/php/8.3/cli/php.ini
        sudo nano /etc/php/8.3/apache2/php.ini

        # 1. Ensure `pcntl_signal` and `pcntl_signal_dispatch` are not disabled by the disable_functions option
        # 2.
        upload_max_filesize 16G
        post_max_size 16G
        max_execution_time 3600
        max_input_time 3600
        memory_limit 512M
        opcache
    
    # Apache module
        # Rewrite
        sudo a2enmod rewrite # mod_rewrite (mandatory)
        sudo a2enmod env

        # recommended:
        sudo a2enmod headers
        sudo a2enmod dir
        sudo a2enmod mime

        # Enable SSL
        sudo a2enmod ssl
        sudo a2ensite default-ssl

        # Apply
        sudo systemctl restart apache2
    
    # Init
        # init submodule
        cd $nextcloud_dir/3rdparty
        sudo -E -u www-data git submodule update --init

        # update .htaccess file
        sudo -E -u www-data php /var/www/nextcloud/occ maintenance:update:htaccess
    
# ================== Email server ==================

    Nextcloud email caramel
    https://123qwe.com/

    sudo apt-get install -y postfix postfix-pgsql dovecot-imapd dovecot-pgsql dovecot-lmtpd dovecot-sieve dovecot-managesieved rspamd postgresql apache2 python3-certbot-apache
    systemctl stop apache2 postfix dovecot postgresql

    sudo nano /etc/postfix/main.cf

# ================== Nextcloud apps config ==================
    
    # Admin > Vue d'ensemble > Recommendations de sécurité

    # Antivirus ClamAV
    sudo apt-get install -y clamav clamav-daemon

    # review the ClamAV doc & settings, like verbose logging until everything ok
    sudo nano /etc/clamav/fleshclam.conf
    sudo nano /etc/clamav/clamd.conf
    
    sudo systemctl enable clamav-daemon
    sudo systemctl start clamav-daemon

    App download : *Antivirus for files*
    Settings > Security > Antivirus for files > Mode = processus (socket)

    Test file :
    X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
