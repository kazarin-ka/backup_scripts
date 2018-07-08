#!/bin/bash
source ./config.cfg
#
#	печатем статус завершения команды - ok или fail и раскрашиваем
#		$1 - первый аргумент функции
print_status()
{
	if [ $1 -eq 0 ]; then
	    echo -n "${green}${toend}[OK]" 
	else
	    echo -n "${red}${toend}[fail]" 
	fi
	echo -n "${reset}" 
	echo
}
#
#	проверяем зависимости (наличие необходимых утилит)
#		mysqldump, sshpass, tar, gzip, scp, tee
check_dependencies() 
{
	echo -n "Check dependencies..." | tee -a $BP_LOG
	DEP=$(which mysqldump sshpass tar gzip scp tee| wc -l)

	if [$DEP -ne 5]; then
		print_status 1
		echo " * there is NOT all dependencies!" | tee -a $BP_LOG
		return 1
	fi
	print_status 0
	echo -e " * all dependencies ready!" | tee -a $BP_LOG
	return 0
}
#
#	проверяем что хватает места yf lbcrt
check_free_disk_space() 
{
	echo -n "Check free disk space..." | tee -a $BP_LOG
	FREE_SPACE=$(df -m $BP_DUMP_PUTH 2>>$BP_LOG |awk '{print $4}' | tail -n 1 ) 
	if [ $FREE_SPACE= -lt $MIN_SPACE ]; then
		print_status 1
		echo " * there is NO enought free disk space!" | tee -a $BP_LOG
		return 1
	fi
	print_status 0
	echo -e " * Free disk space - ok!" | tee -a $BP_LOG
	return 0
}
#
# проверяем, что сервис Mysql запущен иначе нет смысла к нему коннектится
check_run_sql()
{
	echo "Check mysql service is running..." | tee -a $BP_LOG
	# есть два варианта проверки.. в зависимости от того, установлен ли в системе systemd или нет.
	which systemd > /dev/null
	RET=$?
	if [ $RET -eq 0 ]; then
	    	echo -n " * there is SystemD service, checking.." | tee -a $BP_LOG
	    	systemctl is-active mysql.service
	    	RET=$?
				
	else
			echo -n " * there is NO SystemD, checking.." | tee -a $BP_LOG
			service mysql status | grep "start/running" 
			RET=$?		
	fi

	if [ $RET -eq 0 ]; then
		print_status 0
		echo " * service is runnig!" | tee -a $BP_LOG
		return 0

	else
		print_status 1
		# иначе завершаем работу т.к. нет смысла бекапить дальше, у нас уже проблемы
		echo " * no service is running" | tee -a $BP_LOG
		return 1

	fi
}
#
# проверяем, сто существует директория с файлами WP
check_wp_dir_exist()
{
	echo -n "Check wp catalog exist..." | tee -a $BP_LOG
	if [ ! -d $WP_FILE_DIR ]
	then
		print_status 1
		echo " * No directory $WP_FILE_DIR !" | tee -a $BP_LOG
		return 1

	else
		print_status 0
		return 0	
	fi
}
#
# обработчик ошибок для вызываемых функций
operation_result()
{
	# $1 - код возврата
	# $2 - название действия

	if [ ! $1 -eq 0 ]; then
		print_status 1
		echo " * $2 problem, finishing... See $BP_LOG for more information!" | tee -a $BP_LOG
		exit 1
	fi
	print_status 0
	echo " * $2 ready!" | tee -a $BP_LOG
	echo " " | tee -a $BP_LOG
}

main()
{
	if [ ! check_dependencies ] || [ ! check_free_disk_space ] || [ ! check_run_sql ]; then exit 1; fi

	# устанавливаем текущую дату
	BP_DATE=$(date +"%m-%d-%y")

	# делаем запись в логе
	echo "|=======================================================================================|" >> $BP_LOG
	echo "|          $BP_DATE Starting backup job [$BP_TASK_NAME] at  [$(date +%H:%M:%S)]               |" >> $BP_LOG
	echo "|=======================================================================================|" >> $BP_LOG

	# создаем каталог где временно будут храниться копии до формирования полного тарбола
	echo -n "[$(date +%H:%M:%S)] " >>$BP_LOG
	echo -n "Create temp directory $BP_DUMP_PUTH/$BP_TEMP_DIR..." | tee -a $BP_LOG
	mkdir -p $BP_DUMP_PUTH/$BP_TEMP_DIR
	operation_result $? "create temp directory"	
	
   	# делаем дамп базы
   	echo -n "[$(date +%H:%M:%S)] " >>$BP_LOG
   	echo -n "Dumping database $DB_NAME..." | tee -a $BP_LOG
	mysqldump -u $DB_USER -p$DB_PASSWD $DB_NAME 2>>$BP_LOG | gzip > $DB_DUMP_PUTH/$DB_DUMP_NAME.sql.gz 2>>$BP_LOG
	operation_result $? "mysqldump"	

	#	архивируем каталог wordrpess
	echo -n "[$(date +%H:%M:%S)] " >>$BP_LOG
	echo -n "archiving $WP_FILE_DIR catalog..." | tee -a $BP_LOG
	tar -czpf "$WP_BCKP_PUTH/$WP_BCKP_NAME.tar.gz" $WP_FILE_DIR 2>>$BP_LOG
	operation_result $? "archiving"	


	#	собираем все это в один тарбол
	echo -n "[$(date +%H:%M:%S)] " >>$BP_LOG
	echo -n "Prepearing  full tarboll..." | tee -a $BP_LOG
	cd $BP_DUMP_PUTH
	tar -cf $BP_DUMP_PUTH/$BP_TASK_NAME.$BP_DATE.tar $BP_TEMP_DIR 2>>$BP_LOG
	

	echo -n "[$(date +%H:%M:%S)] " >>$BP_LOG
	echo -n "Removing temp dir $BP_TEMP_DIR..." | tee -a $BP_LOG
	rm -rf $BP_TEMP_DIR 2>>$BP_LOG
	operation_result $? "removing temp dir"

	# TODO - заменить потом sshpass на работу по ключу
	# переносим архив на удаленный сервер по scp
	echo -n "[$(date +%H:%M:%S)] " >>$BP_LOG
	echo "Removing tarboll by scp to remote server..."
	sshpass -p $SCP_PSWD scp -P $SCP_PORT -o StrictHostKeyChecking=no $BP_DUMP_PUTH/$BP_TASK_NAME.$BP_DATE.tar $SCP_LOGIN@$SCP_IP:$SCP_PATH 2>>$BP_LOG
	operation_result $? "remove by scp"	


	echo -n "[$(date +%H:%M:%S)] " >>$BP_LOG
	echo "Backup job [$BP_TASK_NAME] successfully completed! " >> $BP_LOG
}

main "$@"