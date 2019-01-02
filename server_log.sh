#!/bin/bash

USER="root"
PASSWORD="123456"
MYSQL_BACKUP_HOME="/opt/mynas/dataBackup"   # 数据库备份的目录
BACKUPPATH="/opt/mynas/logBackup/"   # 设备日志的备份路径
DATE=$(date +%Y%m%d)    # 当天日期
DAYFILE="/opt/mynas/configsave.txt" # 数据库备份的删除周期
DELETE_CYCLE=30 # 默认删除周期为30天
DELETE_DB_CYCLE=7 # 数据库备份只保留7天
LOG_DIR="/opt/server_init/logs/" # 日志目录
LOG_FILE="${LOG_DIR}server_log.log" # 执行日志
CONTROL_IMG_PATH="/data/webapps/control_img/" #图形日志的图片路径
DEVICEPACKAGE_PATH="/opt/mynas/DevicePackage/" #截图函数的图片保存路径
NGINXTEMPDIR="/opt/mynas/romStore/" # nginx配置文件临时目录
NGINXDIR="/usr/local/nginx/conf/" # nginx安装目录
NGINXCONF_ZIP="nginxconf.zip" # nginx升级包
NGINXFILE="nginx.conf" # nginx文件名
TOMCAT_LOG="/data/log/" #tomcat log日志
WANGZHUAN_IMG="/opt/mynas/wangzhuan/"

function print(){
	echo $1 >> "${LOG_FILE}"
}

# 1-解压成功，0-解压失败
function unzip_nginxfile(){
	cd ${NGINXTEMPDIR}
	if [ ! -f "${NGINXCONF_ZIP}" ]; then
		print "nginx升级文件${NGINXCONF_ZIP}不存在"
		echo 0
	else
		print "nginx升级文件${NGINXCONF_ZIP}存在,开始解压"
		rm -rf ${NGINXFILE}
		unzip ${NGINXCONF_ZIP}>/dev/null  && echo 1 || echo 0
	fi
}

function restart_nginx(){
	service nginx restart && print "重新启动nginx成功！！！"
}

# 获取nginx的状态，0-stop，1-启动成功，2-启动中
function get_status(){
	status=`service nginx status`
	starting="\* Starting Nginx Server..."
	start="\* Nginx Server... found running with processes"
	notRunning="\* Nginx Server... is NOT running"
	if [[ $status =~ $start ]]; then
		echo 1
	elif [[ $status =~ $starting ]]; then
		echo 2
	elif [[ $status =~ $notRunning ]]; then
		echo 0
	fi
}

# 校验nginx是否启动完成，0-启动失败，1-启动完成
function check_nginx(){
	retryTime=100
	failure=0
	while [[ ${failure} -lt $retryTime ]]; do
		status=$(get_status)
		if [[ $status -eq 2 ]]; then
			failure=`expr ${failure} + 1`
			print "nginx正在启动，2秒后重试"
			sleep 1s
		elif [[ $status -eq 0 ]]; then
			failure=`expr ${failure} + 1`
			print "nginx尚未启动，2秒后重试"
			sleep 2s
		else
			break
		fi
	done

	if [[ $(get_status) == 1 ]]; then
		print "nginx已启动"
		echo 1
	elif [[ $(get_status) == 2 ]]; then
		print "尝试${retryTime}秒后nginx仍在启动"
		echo 0
	else
		print "nginx未启动"
		echo 0
	fi
}

function update_nginx(){
	if [[ $(unzip_nginxfile) == 1 ]]; then
		cd ${NGINXDIR}
		# 删除原来旧的conf
		rm -rf ${NGINXDIR}${NGINXFILE}
		# 将新的conf复制过去
		cp -R ${NGINXTEMPDIR}${NGINXFILE} ${NGINXDIR}
		chmod -R 777 ${NGINXDIR}${NGINXFILE} 
		restart_nginx
		if [[ $(check_nginx) == 1 ]]; then
			print "升级nginx成功"
			# 升级成功后删除升级包
			rm -rf ${NGINXTEMPDIR}${NGINXCONF_ZIP}
			rm -rf ${NGINXTEMPDIR}${NGINXFILE}
		else
			print "升级nginx失败"
		fi
	else
		print "升级文件不存在,不升级nginx"
	fi
}

# 定期删除30天之前的DevicePackage目录下的图片
function delete_DevicePackage_img(){
	find ${DEVICEPACKAGE_PATH} -mtime +30 -name "*.*" -exec rm -Rf {} \;
	print "删除30天之前的DevicePackage下图片"
}

# 定期删除30天之前的图形日志的图片
function delete_control_img(){
    for deviceDir in $(ls ${CONTROL_IMG_PATH})
        do
            find ${CONTROL_IMG_PATH}${deviceDir} -mtime +30 -name "*.*" -exec rm -Rf {} \;
            for smallDir in $(ls ${CONTROL_IMG_PATH}${deviceDir})
                do
                    find ${CONTROL_IMG_PATH}${deviceDir}${smallDir} -mtime +30 -name "*.*" -exec rm -Rf {} \;
				done
        done
	print "删除30天之前的图形日志control_img的图片"
}

# 上报磁盘使用量
function log_DiskSapce(){
	df -h | grep -E "mynas|data" | awk '{print $3 "=" $6}' > /opt/mynas/diskSpace.txt
	print "上报磁盘使用量成功,记录在/opt/mynas/diskSpace.txt"
	df -h | grep -E "mynas|data" | awk '{print $2 "=" $3 "=" $4 "=" $6}' > /opt/mynas/diskSpaceNew.txt
	print "上报data、nas磁盘3个信息成功,记录在/opt/mynas/diskSpaceNew.txt"
}

# 先获取删除周期
function get_DeleteCycle(){
	if [[ -f "${DAYFILE}" ]]; then
		cat $DAYFILE | while read LINE
		do 
			dayval=${LINE#*=}
			if [ $dayval -gt 0 ]  
			then 
				DELETE_CYCLE=$dayval
				print "${DAYFILE}存在,获取删除周期为${dayval}"
			else
				DELETE_CYCLE=30
				print "${DAYFILE}存在,但是值为null，默认删除周期为30天"
			fi
		done	
	else
		DELETE_CYCLE=30
		print "${DAYFILE}不存在,默认删除周期为30天"
	fi
}

# 初始化数据库的备份目录
function init_DataBackup_Dir(){
	if [[ ! -d "${MYSQL_BACKUP_HOME}" ]]; then
		mkdir "${MYSQL_BACKUP_HOME}"
		print "${MYSQL_BACKUP_HOME}不存在,创建备份目录"
	else
		print "${MYSQL_BACKUP_HOME}备份目录已存在"
	fi
	chmod -R 777 "${MYSQL_BACKUP_HOME}"
}

# 备份数据库
function backup_DataBase(){
	cd ${MYSQL_BACKUP_HOME}
    mysqldump -u${USER} -p${PASSWORD} $1 | gzip > $1${DATE}.sql.gz
    print "备份 $1 数据库完成"
}

# 删除过期的数据库备份
function delete_BackupDataBase(){
    for file in $(ls ${MYSQL_BACKUP_HOME})
		do
            fileDate=${file:0-15:8}
            # 将获得的日期转为的时间戳格式
            startDate=$(date -d ${fileDate} +%s)
            endDate=$(date -d ${DATE} +%s)
            # 计算两个时间戳的差值除于每天86400s即为天数差
            stampDiff=$((${endDate}-${startDate}))
            dayDiff=$((${stampDiff}/86400)) 
            if [ ${dayDiff} -gt ${DELETE_DB_CYCLE} ]
            then
                rm -f ${MYSQL_BACKUP_HOME}/${file}
                print "删除30天之前的数据库备份成功"
            fi
        done
}

# 定期删除mysql binary logs
function delete_BinaryLog(){
      lastMonth=$(date +%Y%m%d --date '30 days ago')
      cd /root
      mysql -u${USER} -p${PASSWORD} -e "purge binary logs before '${lastMonth}';"
	  print "删除30天之前的二进制日志成功"
}

# 定期删除control_core数据库的log表记录
function delete_ControlLog(){
	mysql -u${USER} -p${PASSWORD} -e "use control_core; DELETE FROM log WHERE id<= (SELECT max(id) from(SELECT id FROM log ORDER BY id asc LIMIT 8000000)as a)"
	  print "删除control_core数据库的log表多于800万条的数据成功"
}

# 初始化板子日志的备份文件目录
function init_DeviceLogBackup_Dir(){
	if [[ ! -d "${BACKUPPATH}" ]];
	then
		mkdir "${BACKUPPATH}"
		chmod -R 777 "${BACKUPPATH}"
		print "${BACKUPPATH}不存在，创建目录成功"
	else
		print "${BACKUPPATH}已存在"
	fi
}

# 备份设备的日志
function backup_DeviceLogs(){
	if [[ -f "${IPFILE}" ]]; then
		print "${IPFILE}存在,开始备份设备的日志"
		# 安装adb工具
		apt-get install android-tools-adb 
		cat $IPFILE | while read LINE
		do 
			key=${LINE%=*}	# 设备pid
			val=${LINE#*=}	# 设备ip
			FD=${key//:/}   # 无冒号的pid      
			# 根据pid创建对应文件夹
			if [[ ! -d "${BACKUPPATH}${FD}" ]];
			then        
				mkdir "${BACKUPPATH}${FD}"
			fi
			# 检测设备是否在线
			ping -c 1 $val 
			if [ $? -eq 0 ] 
			then
				print "设备在线："$val
				adb kill-server
				adb connect $val
				sleep 1s
				adb pull /sdcard/AndroLua/log ${BACKUPPATH}${FD}/
				# 判断是否成功导出日志
				if [ $? -eq 0 ] 
				then
					sleep 1s
					adb disconnect
					print "日志备份完成:"$val 
				else 
					print "日志备份失败:"$val
				fi
			else
				print "设备离线,无法备份"$val
			fi
		done 	
	else
		print "${IPFILE}不存在,设备日志无法进行备份"
	fi  
}

# 删除过期的板子日志
function delete_BackupDeviceLogs(){
	for pidFile in $(ls ${BACKUPPATH})
		do
			for txtfile in $(ls ${BACKUPPATH}${pidFile})
				do
					fileDate=${txtfile:0:8}
					# 将获得的日期转为的时间戳格式
					startDate=$(date -d ${fileDate} +%s)
					endDate=$(date -d ${DATE} +%s)
					# 计算两个时间戳的差值除于每天86400s即为天数差
					stampDiff=$((${endDate}-${startDate}))
					dayDiff=$((${stampDiff}/86400)) 
					if [ ${dayDiff} -gt ${DELETE_CYCLE} ]
					then
						rm -f ${BACKUPPATH}${pidFile}/$txtfile
						if [ $? -eq 0 ]
						then
							print "删除${pidFile}的过期日志${txtfile}完成"
						fi
					fi
				done
		done
}
#删除tomcat 日志
function delete_TomcatLog(){
  if [[ -f "$TOMCAT_LOG" ]]; then
	  find /data/logs/* -name "*.log*" -mtime +5 -exec rm -rf {} \;
  fi
}

#删除网赚截图
function delete_Wangzhuan(){
  if [[ -f "$WANGZHUAN_IMG" ]]; then
	  find /opt/mynas/wangzhuan/* -name "*.bmp" -mtime +3 -exec rm -rf {} \;
  fi
}
function run(){
	print "---------------------------------------------------------------------脚本开始"
	log_time=`date '+%Y-%m-%d %H:%M:%S'`
	print "执行时间 : ${log_time}"
	update_nginx
	log_DiskSapce
	get_DeleteCycle	
	init_DataBackup_Dir
	# 备份数据库
	backup_DataBase control_core
	backup_DataBase data_center
	backup_DataBase wechat_business
	delete_BackupDataBase
	delete_BinaryLog
	delete_ControlLog
	delete_control_img
	delete_DevicePackage_img
	init_DeviceLogBackup_Dir
	backup_DeviceLogs
	delete_BackupDeviceLogs
	delete_TomcatLog
	delete_Wangzhuan
	print "---------------------------------------------------------------------脚本结束"
}

if [[ ! -d ${LOG_DIR} ]]; then  
	mkdir "${LOG_DIR}"
fi

if [[ -f "${LOG_FILE}" ]]; then
	rm -f ${LOG_FILE}
fi

if [[ ! -f "${LOG_FILE}" ]]; then
	touch "${LOG_FILE}"
fi

run
