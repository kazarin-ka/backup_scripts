#!/bin/bash
#
### Description: Script for static files backup.
### This version is Ubuntu server 16.04 compatible.
### Version: 0.1
### Written by: Kirill Kazarin, Russia, SPB, 06-2018 - kazarin.ka@yandex.ru
### Usage: bash *scriptname* task_name backup_source_dir mount_folder smb_share_destination smb_user smb_password
### Example: bash file_backup.sh wiki /home/data /home/backup //192.168.100.1/backup_test kirill Qwerty.123
#
TASK_NAME="$1"
SOURCE_DIR="$2"
MOUNT_DIR="$3"
SMB_SHARE="$4"
SMB_USER="$5"
SMB_PASSWD="$6"
LOG_FILE="backup.log"
BACKUP_DATE=$(date +"%m-%d-%y")
BACKUP_FILE="$MOUNT_DIR"/"$TASK_NAME"-backup-"$BACKUP_DATE".tar.gz
BACKUP_AGE=7 # delete files older that this value

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
  printf " * [%s] - Done!\n" "$2" | tee -a "$LOG_FILE"
}

## Check that script running with root privileges
if [ "$EUID" -ne 0 ]; then
  printf "Use root account for backup! \n"
  exit 1
fi

## Check that user don't forget about all arguments
if [ "$#" -ne 6 ]; then
    printf "Illegal number of parameters \nParameters: task_name, source_directory, mount_point, smb_share_addr, smb_user, smb_password!\n"
    exit 1
  else
    printf "Starting backup of [%s] folder to [%s]\n" "$SOURCE_DIR" "$SMB_SHARE" | tee -a "$LOG_FILE"
fi

## Check if a source (backup) directory does not exist
if [ ! -d "$SOURCE_DIR" ]
then
   printf "Directory [%s] DOES NOT exists!\n" "$SOURCE_DIR" | tee -a "$LOG_FILE"
   exit 1
fi


## Checking that cifs-utils package installed
DEP="$(which mount.cifs | wc -l)"
if [ "$DEP" -ne 1 ]; then
  printf " * cifs-utils package not installed!\n" | tee -a "$LOG_FILE"
  exit 1
fi

## Check that smb share already mounted. If not - mount it!
if [[ $(findmnt -M "$MOUNT_DIR") ]]; then
    printf " * [%s] already mounted, continue...\n" "$MOUNT_DIR" | tee -a "$LOG_FILE"
else
  ## Mount smb share for backup
  mount -t cifs "$SMB_SHARE" "$MOUNT_DIR" --verbose -o username="$SMB_USER",password="$SMB_PASSWD"&>> "$LOG_FILE"
  operation_result $? "Mount smb share"
fi

## Check that we can write into this folder and delete this file
echo "Test_1234567890_string." &>> "$LOG_FILE" > "$MOUNT_DIR"/test.txt \
  && rm "$MOUNT_DIR"/test.txt &>> "$LOG_FILE"
operation_result $? "Test write access"

## start backup process
tar -czf "$BACKUP_FILE" "$SOURCE_DIR" &>> "$LOG_FILE"
operation_result $? "Backup files"


BACKUP_SIZE="$(du -h $BACKUP_FILE | awk '{print $1}' )"

## check archive after backup
tar tzf "$BACKUP_FILE" &> /dev/nul
if [ ! "$?" -eq 0 ]; then
  printf " * [Test backup archive] - failed!\n" | tee -a "$LOG_FILE"

  ## Unmount smb share
  umount "$MOUNT_DIR"  &>> "$LOG_FILE"
  operation_result $? "Unmount smb share"

  exit 1

else
  printf " * [Test backup archive] - Done!\n" | tee -a "$LOG_FILE"

fi

## Create file shecksum for storage control
sha1sum  "$BACKUP_FILE" > "$BACKUP_FILE".sha1 | tee -a "$LOG_FILE"
operation_result $? "Create checksum"

## Delete old backups
find "$MOUNT_DIR" -mtime +"$BACKUP_AGE" -type f -delete  &>> "$LOG_FILE"
operation_result $? "Check and delete old backups"

## Unmount smb share
umount "$MOUNT_DIR"  &>> "$LOG_FILE"
operation_result $? "Unmount smb share"

## writes results in log
printf  "%s: backup job [%s] done successfully. Total backup size: [%s]. \n" "$BACKUP_DATE" "$TASK_NAME" "$BACKUP_SIZE" | tee -a "$LOG_FILE"

exit 0