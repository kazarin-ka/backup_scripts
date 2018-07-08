# Pack of different backup scripts

This pack includes different scripts for backuping. Created by my for myself

List of scripts:
├── file_backup.sh \
└── xtrabackup_install.sh \

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
```
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

## Xtrabakup install

tool for install and prepare percona xtrabackup tool to backup your mysql DB.

This script used scripts for xtrabackup from [DO wiki](https://www.digitalocean.com/community/tutorials/how-to-configure-mysql-backups-with-percona-xtrabackup-on-ubuntu-16-04)

what this script does:
1. installing all needed packets
2. creating backup user in mysql (with permissions) and check backup user in OS
3. creating configs, folders and encryption key
4. downloading and installing scripts
4. runnig first backup

How to use: ``` bash *scriptname* MYSQL_ROOT_PASWD MYSQL_BACKUP_PASWD OS_ADMIN_USER```

is in development...