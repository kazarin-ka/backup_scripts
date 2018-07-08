@echo off
rem разрешаем переопределять переменные
setlocal

rem задаем набор параметров скрипта
set log= *путь к папке где будем хранить логи*
set taskname= *имя задания*
set backup=*временная папка для хранения выгрузки*
set base=*путь к базе в файловой версии и имя базы в серверной версии*
rem в серверной версии имя базы задается в формате "имя сервера"\"имя базы""
set archive=*путь к временной папке для архива*\%taskname%_%date%.7z
set BackupServer=*путь к шаре, куда переместить архив в конце задания*
set Backupuser=*пользователь бекапа*
set BackupPassword = *пароль пользователя

rem логирование
echo #==================================================================# >> "%log%\backup-%taskname%.log"		
echo Запуск задания [%taskname%]... >> "%log%\backup-%taskname%.log"
echo Имя базы 1C: %base% >> "%log%\backup-%taskname%.log"
echo Дата/время: %date%/%time% >> "%log%\backup-%taskname%.log"

echo %time% Создание дампа 1C... >> "%log%\backup-%taskname%.log"
rem формат команды для файловой базы
"C:\Program Files (x86)\1cv8\common\1cestart.exe" DESIGNER /F "%base%" /DisableStartupMessages  /N %Backupuser% /P %BackupPassword% /DumpIB "%backup%\%taskname%_%date%.dt"  /OUT "%log%\backup-%taskname%.log" -NoTruncate
rem формат команды для серверной sql базы
rem "C:\Program Files (x86)\1cv8\common\1cestart.exe" DESIGNER /S "%base%" /DisableStartupMessages  /N %Backupuser% /P %BackupPassword% /DumpIB "%backup%\%taskname%_%date%.dt"  /OUT "%log%\backup-%taskname%.log" -NoTruncate

echo %time% жду завершения 1С... >> "%log%\backup-%taskname%.log"
rem ждем пока не завершится 1с-ка
:loop
	ping -n 1 127.0.0.1 >nul
	tasklist /FI "IMAGENAME eq 1cv8.exe" /V /NH | findstr /i %username% >nul&& goto loop
	
echo %time% Создание дампа 1C Завершено! >> "%log%\backup-%taskname%.log"

rem переходим в каталог архиватора
cd "C:\Program Files\7-Zip"
rem запускаем сжатие нашего архива с базой
echo %time%: Архивируем дамп 1C... >> "%log%\backup-%taskname%.log"
7z.exe a -t7z %archive% -mx3 "%backup%\%taskname%_%date%.dt" >> "%log%\backup-%taskname%.log"
rem обработка ошибок - если не прошла архивация дампа
rem 7zip возвращает 0 в случае успеха
if errorlevel 0 goto  continue
	echo %time%:  Ошибка архивирования! >> "%log%\backup-%taskname%.log"
	exit 1
:continue
echo %time%: Архивация дампа 1С завершена! >> "%log%\backup-%taskname%.log"

rem переносим архив на файл-сервер на диск с бекапами
echo %time%: Переносим архив на сервер резервных копий... >> "%log%\backup-%taskname%.log"
move  %archive% %BackupServer%
rem обработка ошибок - если не смог переместить
if not errorlevel 1 goto  continue2
	echo %time%: moving archive on backup server error! >> "%log%\backup-%taskname%.log"
	exit 1

:continue2
echo %time%: Перемещение на сервер завершено! >> "%log%\backup-%taskname%.log"
echo %time%: путь к архиву:[%BackupServer%]  >> "%log%\backup-%taskname%.log"

echo %time%: Удаляем дамп 1С  >> "%log%\backup-%taskname%.log"
erase "%backup%\%taskname%_%date%.dt"
echo %time%: Задание [%taskname%] успешно завершено! >> "%log%\backup-%taskname%.log"

endlocal
exit 0

