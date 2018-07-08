# Pack of different backup scripts

This pack includes different scripts for backuping. Created by my for myself

List of scripts: \
```
├── 1c.bat
├── file_backup.sh 
├── kvm-backup_script.sh
├── wordpress_backup
│   ├── config.cfg.example
│   └── wp_backup.sh
└── xtrabackup_install.sh 
```

## 1C

File "1c.bat" contains script, writed on windows cmd language.  
It is designed to backup 1C 8.2-8.3 databases, including file and sql versions.

**How to use it:**
1. fill in the required fields inside it
2. create task in Windows task scheduler

**What this script does:**
1. creating dump of 1c base, using built-in mechanism
2. archiving this dump, using 7zip tool
3. moving archive to remote smb share
4. deleting local copy

## File backup

Created for backuping any local filestorage to remote smb share. \
Backup steps:
1. mount share
2. check that share mounted successfuly
3. create and write test file
4. create backup using tar and calculate backup size
5. check archive after backup
6. create checksum of our backup
7. delete old backups
8. unmount smb share

during backup all tasks writing to log file and to you screen

How to use: ```bash *scriptname* task_name backup_source_dir mount_folder smb_share_destination smb_user smb_password```

Example:
```bash
root@wiki:~# bash /home/scripts/file_backup.sh wiki /var/www/dokuwiki /home/backup //backup-smb.mynet.local/wiki/data-backup user password
Starting backup of [/var/www/dokuwiki] folder to [//backup-smb.mynet.local/wiki/data-backup]
 * [Mount smb share] - Done!
 * [Test write access] - Done!
 * [Backup files] - Done!
 * [Test backup archive] - Done!
 * [Create checksum] - Done!
 * [Check and delete old backups] - Done!
 * [Unmount smb share] - Done!
07-08-18: backup job [wiki] done successfully. Total backup size: [13M]. 

```
**Note:** mount point for backup should be created manually!

## KVM backup scrip

This script was created for simple backup of KVM VMs (if you use "clean KVM" without porxmox 
or any other wrappers)

**How to use it:**
1. fill in the required fields in config.cfg
3. check scripts ```bash /etc/scripts/backup/kvm_backups.sh```
4. add to cron ```@weekly /etc/scripts/backup/kvm_backups.sh```

**What this script does:**
1. find and stop VM
2. wait until vm will be stopped
3. get list of all VM's disks
4. mount remote smb share
5. archive and copy all disks
6. create dump of VM's config and copy it too
7. un mount share
8. start VM back

## Wordpress backup

Script for wordpress based web site backup

**Note:** This script uses mysqldump tool - don't use it in hightload production. 
For personal blogs only!

**How to use it:**
1. Rename config.cfg.example to config.cfg
2. fill in the required fields in config.cfg
3. check scripts ```bash /etc/scripts/backup/backups.sh```
4. add to cron ```@weekly /etc/scripts/backup/backups.sh```

**Example:**
```bash
root@server:~$ bash /etc/scripts/backup/backups.sh
Create temp directory /tmp/backup/tmp_bcp...                                                                                                                                                                                           [OK]
 * create temp directory ready!
 
Dumping database wordpress...                                                                                                                                                                                                     [OK]
 * mysqldump ready!
 
archiving /var/www/wordpress catalog...                                                                                                                                                                                                [OK]
 * archiving ready!
 
Prepearing  full tarboll...Removing temp dir tmp_bcp...                                                                                                                                                                                [OK]
 * removing temp dir ready!
 
Removing tarboll by scp to remote server...
                                                                                                                                                                                                                                       [OK]
 * remove by scp ready!
 

```

## Xtrabakup install

tool for install and prepare percona xtrabackup tool to backup your mysql DB.

This script used scripts for xtrabackup from [DO wiki](https://www.digitalocean.com/community/tutorials/how-to-configure-mysql-backups-with-percona-xtrabackup-on-ubuntu-16-04)

**What this script does:**
1. installing all needed packets
2. creating backup user in mysql (with permissions) and check backup user in OS
3. creating configs, folders and encryption key
4. downloading and installing scripts
4. runnig first backup

How to use: ``` bash *scriptname* MYSQL_ROOT_PASWD MYSQL_BACKUP_PASWD OS_ADMIN_USER```

is in development...