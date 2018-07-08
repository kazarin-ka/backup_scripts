#!/bin/bash

vmDomainName=*имя виртуальной машины*
CurentDate=$(date +%Y-%m-%d)
kvmStore="*путь до хранилища файлов-дисков ВМ"
backupDir="*путь до хранилища резервных копий*"
BackupLog="*путь до хранилища логов*/$vmDomainName-backup.log"
Smbshare="*путь до smb шары*" # //ip/shared_folder
Smbuser="*имя пользователя smb шары*"
smbpassword="*пароль пользователя smb шары*"

echo "===================================================================" >> $BackupLog
echo "$CurentDate: Start $vmDomainName virtual machine backup!" >> $BackupLog

# выключаем машину
echo "$(date +%H-%M-%S): Shuting down VM $vmDomainName" >> $BackupLog
virsh shutdown $vmDomainName   >> $BackupLog
# считываем ее статус
vmStatus=$(virsh list --all | grep $vmDomainName | cut -d " " -f26,27)
# ждем пока машина завершит работу
while [   "$vmStatus" != "shut off" ]; do
        #echo "Wait shutting down $vmDomainName" >> $BackupLog
        sleep 1
        vmStatus=$(virsh list --all | grep $vmDomainName | cut -d " " -f26,27)
done
echo "$(date +%H-%M-%S): Done!" >> $BackupLog
# как только виртуалка потухла, начинаем дампить
echo "$(date +%H-%M-%S): Start dumping VM $vmDomainName" >> $BackupLog

# получаем список дисков в формате .qcow / .qcow2 (а только такие нам нужны)
vmDomainDisks=$(virsh domblklist $vmDomainName | grep .qcow | cut -d " " -f9)

# монтируем удаленную хранилку
/sbin/mount.cifs $Smbshare $backupDir -o user=$Smbuser ,password=$smbpassword,iocharset=utf8   >> $BackupLog
cd $backupDir

# копируем-архивируем диски по списку
for disk in $vmDomainDisks; do

        diskName=$(echo $disk | cut -d"/" -f4)
        echo "$(date +%H-%M-%S): Archiving $diskName" >> $BackupLog
        zip  $vmDomainName-[$diskName]-$(date +%Y-%m-%d).zip  $disk   >> $BackupLog
        echo "$(date +%H-%M-%S): Done!" >> $BackupLog

done

echo "$(date +%H-%M-%S): Dumping VM $vmDomainName Done!" >> $BackupLog

# делаем дамп конфига ( мало ли он менялся)
virsh dumpxml $vmDomainName > $backupDir/$vmDomainName_$CurentDate.xml

cd /home
umount $backupDir
# запускам виртуалку обратно
echo "$(date +%H-%M-%S): Starting VM $vmDomainName" >> $BackupLog
virsh start $vmDomainName   >> $BackupLog
echo "$(date +%H-%M-%S): Done!" >> $BackupLog
exit 0
