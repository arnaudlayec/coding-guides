
# IBJB

Context: existing Enterprise project (of OCI), re-installed on a fresh new Akretion project.

### Local (upload to target)

```bash
cd /dev/odoo/17.0/ibjb

tsh scp ./data/shared/dump.sql app@ibjb:~/data/ibjb/shared
tsh scp -r ./data/filestore/ibjb app@ibjb:~/data/ibjb/filestore
```

### Remote : do the restore


###### DB

```bash
tsh ssh app@ibjb
cd ibjb
docky kill; docky run

dropdb ibjb
createdb ibjb
psql -d ibjb -f /data/odoo/shared/dump.sql
psql -d ibjb -ac "UPDATE res_users SET password='admin' WHERE login='admin_odoo_ibjb@oci.fr';"
# CTRL+D

docky pull; docky up; docky logs
```

### Odoo
1. Login with `admin_odoo_ibjb@oci.fr`
2. Install module `ibjb`
2. Reset password
3. Create Akretion users
4. Test OAuth OIDC



# ALUVAL & Flavigny

Context: existing Arnaud's projects, customers being self-hosted like on OVH or OnPremise servers.
Migrated to Akretion hosting & project.


### 1. Download & upload DB

```bash
cd /dev/odoo/16.0/aluval
./backup/onpremise/orchestrator_db.sh
tsh scp db_aluval_prod_2026_10_xx.dump app@aluval:data/shared/
```

### 2. Download & upload filestore

###### 2.1. Remote

Need to change permissions without altering the former ones

```bash
ssh aluval
sudo cp ~/data/filestore/aluval ~/backups/filestore/db -r
sudo chown arnaud:arnaud backups -R
```

###### 2.2. Local

Compressing PDF and images is not very efficient (only 10% to 30% gain)
Use `zstd` instead of `gzip`: a equivalente rate, faster and use all core with `-T0`

```bash
# Download, streaming tar in ssh so there is no intermediate file on the server
ssh arnaud@aluval "tar -C ~/backups/filestore/aluval -cf - . | zstd -T0 -3" \
  > ./data/aluval_filestore.tar.zst

# Verify the archive
zstd -dc ./data/aluval_filestore.tar.zst | tar -tf - | wc -l

# Optional: uncompress locally the archive (to launch en environment)
mkdir -p ./data/filestore/db && zstd -dc ./data/aluval_filestore.tar.zst | tar -C ./data/filestore/db -xf -

# Upload the same file (useless to uncompress/recompress in local)
tsh ssh app@aluval "mkdir -p ~/data/filestore/aluval && zstd -dc | tar -C ~/data/filestore/aluval -xf -" \
  < ./data/aluval_filestore.tar.zst
```

###### 2.3. At move-to-PROD's night

Rsync to copy only the delta

```bash
# Download
rsync -az --info=progress2 arnaud@aluval:~/backups/filestore/aluval/ ./data/filestore/db/

# Upload via Teleport
rsync -az --info=progress2 -e "tsh ssh" ./data/filestore/db/ app@aluval:~/data/filestore/aluval/
```

###### 2.4. List file difference

```bash
cd ~/dev/odoo/16.0/aluval/data/filestore/db

# Local: relative path + size
find . -type f -printf '%P\t%s\n' | sort > /tmp/fs_local.txt

# Remote: same listing
tsh ssh app@aluval "cd ~/data/aluval/filestore/aluval && find . -type f -printf '%P\t%s\n'" \
  | sort > /tmp/fs_remote.txt

# Files that are absent remotely OR have a different size
comm -23 /tmp/fs_local.txt /tmp/fs_remote.txt | cut -f1 > /tmp/fs_missing.txt

wc -l /tmp/fs_missing.txt   # check before transferring
```

### 3. Remote: do the restore

###### Docker image & DB
On Gitlab: `publish`

```bash
tsh ssh app@aluval
cd aluval
docky kill; docky run

dropdb aluval
createdb aluval
pg_restore -j 8 -U aluval -d aluval /data/odoo/shared/db_xxxxxx --no-owner --no-acl --clean --if-exists --verbose
# CTRL+D

docky pull; docky up; docky logs
```

### 5. Odoo
1. Login with `alayec@aluval.fr`
2. Tests :
    - data
    - email gateway (in/out)
    - PDF
    - bank synch
    - budget upload (Orgadata)
    - performance

### 6. DNS switch

- For ALUVAL: from OVH portal
- For Flavigny : nothing, just asj.akretion.com
