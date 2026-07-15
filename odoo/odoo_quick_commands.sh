
# Stop DEV or PROD
    # Stop dev
    sudo pkill odoo
    ps -e | grep odoo # just to check
    sudo kill -9 <pid> # if needed
    # Stop prod
    sudo systemctl stop odoo-prod

# SERVICES & LOGS
    # Restart services
    sudo systemctl restart odoo-dev
    sudo systemctl restart odoo-prod

    # Read logs
    tail -f /var/log/odoo/odoo-prod.log
    tail -f /var/log/odoo/odoo-dev.log


# GIT AUTHENTICATION `git_connect.sh`
    gitkey_file="gitlab_akretion"
    gitkey_file="ed25519_github_arnaud"
    eval "$(ssh-agent -s)" && ssh-add ~/.ssh/$gitkey_file

# DB DUMP: scripts to create staging db on-the-fly, from the server (PROD -> STAGING)
    nano dump_prod_to_staging.sh
    # Script `postgres`/`dump_prod_to_staging.sh`
        pg_dump $1 > dump_odoo_prod.sql
        dropdb $2 --force
        createdb --owner=odoo $2
        psql -d $2 -f dump_odoo_prod.sql
        rm dump_odoo_prod.sql

    # Script `odoo`/`dump_prod_to_staging.sh`
        odoover=o18
        customer=flavigny
        service_staging=odoo-staging
        staging_db=$odoover-$customer-staging
        prod_db=$odoover-$customer-prod
        # 0. Stop Dev
        sudo pkill odoo
        sudo service $service_staging stop
        # 1. DB
        sudo -S runuser -l postgres -c "./dump_prod_to_staging.sh $prod_db $staging_db"
        # 2. Fileshare
        cd /home/odoo/.local/share/Odoo/filestore/
        rm -rf $staging_db
        cp -r $prod_db $staging_db
        # 3. Neutralize
        source /home/odoo/$odoover/bin/activate
        odoo neutralize -d $staging_db
        # 4. Restart
        sudo service $service_staging start

    # login without SAML
    # /web/login?disable_autoredirect=1

    # If PROD can be stopped, 1 line:
    sudo su - postgres
    createdb --owner=odoo --template=odoo-prod odoo-staging
    cd ~/.local/share/Odoo/filestore/
    cp -r odoo-prod odoo-staging

    # Just postgres dump
    pg_dump odoo-prod > odoo-prod.sql


# DB DUMP & filestore: retrieve SERVER data to LOCAL, in SSH

    # -- CONTENT OF server file `./backup_to_local.sh`
        # clean previous backup
        backup_dir=~/backup_o16_aluval_dev
        rm -rf $backup_dir && mkdir $backup_dir
        # copy database & filestore
        sudo -S runuser -l postgres -c 'pg_dump odoo-dev' > $backup_dir/db_aluval_dev.sql
        sudo tar czf $backup_dir/fs_aluval_dev.tar.gz /home/odoo/.local/share/Odoo/filestore/odoo-dev
        # merge in a single file before scp
        tar czf backup_o16_aluval_dev.tar.gz $backup_dir

    # -- LOCAL COMMANDS
        # download from server & retrieve files locally -> it takes around 5min
        odoover=o16
        client=aluval
        dirname=backup_${odoover}_${client}_dev
        backup_dir=~/dev/odoo/$dirname
        rm -rf $backup_dir && mkdir $backup_dir
        # scp -P 20002 -o PubkeyAuthentication=no -r odoo@odoo.asj.com:$dirname $backup_dir/../
        scp -P 2232 -r arnaud@aluval:$dirname $backup_dir/../
        
        # database restore
        local_db=${odoover}-${client}
        sudo -S runuser -l postgres -c "dropdb $local_db --force"
        sudo -S runuser -l postgres -c "createdb --owner=arnaud $local_db"
        psql $local_db < ${backup_dir}/db_${client}_dev.sql
        
        # filestore restore
        filestore_dir=~/.local/share/Odoo/filestore/$local_db
        cd $backup_dir
        rm -rf $filestore_dir && mkdir $filestore_dir
        tar -xvf ${backup_dir}/fs_${client}_dev.tar.gz
        # sudo mv $backup_dir/home/odoo/.local/share/Odoo/filestore/o18-flavigny-staging $filestore_dir
        sudo mv $backup_dir/home/odoo/.local/share/Odoo/filestore/odoo-dev/* $filestore_dir
        # rm -rf $backup_dir

        # clean assets
        DELETE FROM ir_attachment WHERE res_model='ir.ui.view' AND name LIKE '%assets_%';
        UPDATE res_users SET password = 'admin' WHERE login = 'alayec@aluval.fr';
        DELETE FROM res_users_saml WHERE user_id = (SELECT id FROM res_users WHERE login = 'alayec@aluval.fr');
        http://localhost:8069/web/login?disable_autoredirect=1

# restore OCA database
    pg_restore -d oca-custom -1 20250915-neutralized.dump --no-owner

# reconciliate with PROD
    DELETE FROM ir_ui_view WHERE inherit_id IN (3783) OR id IN (3783);
    DELETE FROM ir_ui_view WHERE arch_db->>'fr_FR' LIKE '%fr_lcr_type%';
    
    DELETE FROM ir_attachment WHERE res_model='ir.ui.view' AND name like '%assets_%';

    clear; odoo -c aluval.conf -u account_invoice_import,account_invoice_import_simple_pdf,account_payment_order,account_banking_pain_base,carpentry_position_budget
