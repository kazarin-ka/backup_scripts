#!/bin/bash
#
### Description: Script for installing and configuring backup via percona xtrabackup tool
### This version is Ubuntu server 16.04 compatible.
### Version: 0.1
### Written by: Kirill Kazarin, Russia, SPB, 06-2018 - kazarin.ka@yandex.ru
### Usage: bash *scriptname* MYSQL_ROOT_PASWD MYSQL_BACKUP_PASWD OS_ADMIN_USER
#

MYSQL_ROOT_PASWD="$1"
MYSQL_ROOT_USER="root"
MYSQL_BACKUP_PASWD="$2"
OS_ADMIN_USER="$3"
RELEASE="$(lsb_release -c | awk '{print $2}')"
LOG_FILE="install.log"

## check result of operation
operation_result()
{
  # arguments:
  #   $1 - return code
  #   $2 - action name

  if [ ! "$1" -eq 0 ]; then
    printf " * There was a problem during [%s] \nSee [%s] for more information!\n" "$2" "$LOG_FILE"
    printf  "%s: backup job %s failed.\n" "$BACKUP_DATE" "$TASK_NAME" >> "$LOG_FILE"
    exit 1
  fi
  printf " * [%s] - Done!\n" "$2"
}

## Check that script running with root privileges
if [ "$EUID" -ne 0 ]; then
  printf "Use root account for backup! \n"
  exit 1
fi

## Check that script running with root privileges
if [ "$OS_ADMIN_USER" == "root" ]; then
  printf "Admin user for OS shouldn't be root! \n"
  exit 1
fi

## TODO: add arguments list
## Check that user don't forget about all arguments
if [ "$#" -ne 3 ]; then
    printf "Illegal number of parameters \nParameters: MYSQL_ROOT_PASWD MYSQL_BACKUP_PASWD OS_ADMIN_USER \n"
    exit 1
  else
    printf "Starting installation...\n"
fi


## Downloading Percona deb package
wget https://repo.percona.com/apt/percona-release_0.1-6."$RELEASE"_all.deb -O /tmp/percona.deb  &>> "$LOG_FILE"
operation_result $? "Download package"

## Installing percona xtrabackup tool
dpkg -i /tmp/percona.deb  &>> "$LOG_FILE" \
  && apt-get update  &>> "$LOG_FILE" \
  && apt-get install -y percona-xtrabackup-24 qpress  &>> "$LOG_FILE"
operation_result $? "Install xtrabackup tool"

## Create backup user into MySQL
mysql --user="$MYSQL_ROOT_USER" \
  --password="$MYSQL_ROOT_PASWD" \
  --execute="CREATE USER 'backup'@'localhost' IDENTIFIED BY $MYSQL_BACKUP_PASWD;"  &>> "$LOG_FILE"
operation_result $? "Create user in Mysql"

## grant permissions for new backup mysql user
mysql --user="$MYSQL_ROOT_USER" \
  --password="$MYSQL_ROOT_PASWD" \
  --execute="GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT, CREATE TABLESPACE, PROCESS, SUPER, CREATE, INSERT, SELECT ON *.* TO 'backup'@'localhost';"  &>> "$LOG_FILE"
operation_result $? "Grant permissions"

## apply permissions for new backup mysql user
mysql --user="$MYSQL_ROOT_USER" \
  --password="$MYSQL_ROOT_PASWD" \
  --execute="FLUSH PRIVILEGES;"  &>> "$LOG_FILE"
operation_result $? "Apply permissions"

## check that backup users already exist in system
CHECK_USER="$(grep backup /etc/passwd /etc/group | wc -l)"
if [ "$CHECK_USER" -ne 2 ]; then
  printf " * Backup user doesn't exist in system\n" | tee -a "$LOG_FILE"
  exit 1
fi

## add users into some groups
usermod -aG mysql backup &>> "$LOG_FILE" \
  && usermod -aG backup "$OS_ADMIN_USER" &>> "$LOG_FILE" \
  &&  usermod -aG backup root &>> "$LOG_FILE"
operation_result $? "Add users to groups"

## grand access to mysql data dir directory for mysql group
find /var/lib/mysql -type d -exec chmod 750 {} \; &>> "$LOG_FILE"
operation_result $? "Grant access to data dir"

cat << EOF > /etc/mysql/backup.cnf &>> "$LOG_FILE"
[client]
user=backup
password=$MYSQL_BACKUP_PASWD
EOF

## set access mode for conf file
chown backup /etc/mysql/backup.cnf &>> "$LOG_FILE" \
  && chmod 600 /etc/mysql/backup.cnf &>> "$LOG_FILE"
operation_result $? "Set access mode to conf"

## prepare backup folder
mkdir -p /backups/mysql &>> "$LOG_FILE" \
  && chown backup:mysql /backups/mysql &>> "$LOG_FILE"
operation_result $? "Prepare backup folder"

## Create an Encryption Key to Secure the Backup Files
printf '%s' "$(openssl rand -base64 24)"  | tee /backups/mysql/encryption_key && echo
operation_result $? "Create an Encryption Key"

chown backup:backup /backups/mysql/encryption_key &>> "$LOG_FILE" \
  && chmod 600 /backups/mysql/encryption_key &>> "$LOG_FILE"
operation_result $? "Set secure mode for key"

## Creating the Backup and Restore Scripts
wget https://raw.githubusercontent.com/do-community/ubuntu-1604-mysql-backup/master/backup-mysql.sh \
  - O /usr/local/bin/backup-mysql.sh &>> "$LOG_FILE" \
  && chmod +x /usr/local/bin/backup-mysql.sh
operation_result $? "Prepare backup script"

wget https://raw.githubusercontent.com/do-community/ubuntu-1604-mysql-backup/master/extract-mysql.sh \
  - O /usr/local/bin/extract-mysql.sh &>> "$LOG_FILE" \
  && chmod +x /usr/local/bin/extract-mysql.sh
operation_result $? "Prepare extract script"

wget https://raw.githubusercontent.com/do-community/ubuntu-1604-mysql-backup/master/prepare-mysql.sh \
  - O /usr/local/bin/prepare-mysql.sh &>> "$LOG_FILE" \
  && chmod +x /usr/local/bin/prepare-mysql.sh
operation_result $? "Prepare script for backup preparation"

## run first and test backup task
sudo -u backup  /usr/local/bin/backup-mysql.sh | tee -a "$LOG_FILE"
operation_result $? "First backup"

printf "Xtrabackup tool [ed and configured! Please save and store nex information\n"
printf "Encryption Key: "
cat /backups/mysql/encryption_key

exit 0