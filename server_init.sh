#!/bin/bash

TOMCAT_PARENT="/data"

TOMCAT_DIR="tomcat"
TOMCAT="tomcat"

TOMCAT_HOME="${TOMCAT_PARENT}/${TOMCAT}" # tomcat路径
UPDATE_BASE="/opt/server_update/" # 升级包使用的目录
SCRIPT_HOME="/opt/server_init/" # 脚本路径

UPDATE="update" # 升级包文件名，不含后缀
VERSION="version-*" # 版本号文件名前缀，后面是具体的版本号
WEB="web"	# 存放war包
LIB="lib"	# 存放jar包
SQL="sql"	# 存放sql文件
SCRIPT="script" 	# 存放脚本文件
FONT="font" 	# 存放训练好的字库文件
CRAWLER="crawler"	# 存放爬虫源码
# 数据库信息
USER="root"  
PASSWORD="123456"

NAS_DIR="/opt/mynas/" # nas的挂载目录
FTP_DIR="/data/mynas/" # ftp的挂载目录
TURN_SERVER_SH="/usr/local/bin/psrvnode.sh"
TOMCAT_WEBAPPS="${TOMCAT_HOME}/webapps/"
TOMCAT_LIB="${TOMCAT_HOME}/lib/"
UPDATE_FILE="${UPDATE_BASE}${UPDATE}.zip" # 升级包地址，里面包含war和sql文件，sql文件名是数据库名
UPDATE_VER="${UPDATE_BASE}${VERSION}" # 升级文件的版本号
UPDATE_DIR_DIST="${UPDATE_BASE}dist" # 当前使用的升级包地址
LOG_DIR="/opt/server_init/logs/" # 日志目录
LOG_FILE="${LOG_DIR}server_init.log" # 执行日志
FONT_DIR="/usr/share/tesseract-ocr/4.00/tessdata/"	# 字库文件目录
CRAWLER_DIR="/home/dockershared/violet/" # 爬虫目录

function print(){
	echo $1 >> "${LOG_FILE}"
}

# 更新 tesseract
function update_tesseract(){
	var=`tesseract dirtesttessdata stdout -l dirtesttessdata`
	if [[ "$var"=~"/usr/share/tesseract-ocr/4.00/tessdata/" ]]; then
		print "发现tesseract服务,跳过安装，继续执行其他操作！"
	else
		print "开始重新安装tesseract服务"
		apt remove  tesseract-ocr
		add-apt-repository -y ppa:alex-p/tesseract-ocr
		apt update
		apt install tesseract-ocr -y
		apt install libtesseract-dev -y
		print "重新安装tesseract服务完成！"
	fi
}




function start_turnserver(){
	if [ ! -f "${TURN_SERVER_SH}" ]; then
		print "turnserver ${TURN_SERVER_SH} 不存在，不需启动"
	else
		nohub /usr/local/bin/psrvnode.sh &
		print "启动turnserver"
	fi
}

function start_tomcat(){
	export JAVA_HOME=/opt/jdk1.8.0_111
	export JRE_HOME=${JAVA_HOME}/jre
	export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
	export PATH=${JAVA_HOME}/bin:$PATH
	print "配置tomcat需要的环境变量成功！！！"

	${TOMCAT_HOME}/bin/startup.sh && print "启动tomcat成功！！！"
}

function start_mysql(){
	service mysql start && print "启动MySQL成功！！！"
}

# 挂载nas
function mount_nas(){
	if [[ -d ${FTP_DIR} ]]; then
		print "FTP finish"
		#statements
	else
		print "开始挂载nas，当前尝试挂载的目录为"${NAS_DIR}
        mount -t nfs -o nolock 192.168.1.5:/volume1/luapublic ${NAS_DIR}
        print "mount nas finish"
	fi
}
# 运行updata.sh脚本
function update_shell(){
	# 若脚本存在 运行后读取退出状态
	if [[ -f ${SCRIPT_HOME}update.sh ]]; then
		dos2unix ${SCRIPT_HOME}update.sh
		sh ${SCRIPT_HOME}update.sh
		if [[ $? -eq 0  ]]; then
			print "update.sh 运行成功！！！"
		else
			print "update.sh 运行失败！！！"
		fi
	else
		print "update.sh 不存在！！！"
	fi
}


function get_ver_new(){
	dir=${UPDATE_BASE}
	ver=""
	if [[ -d ${dir} ]]; then
		cd ${dir}

		for file in ./*
			do
			    if test -f ${file}
			    then
			    	name=${file##*/}
			    	pre=${name:0:8}
			        if [[ ${pre} == "version-" ]]; then
			        	ver=${name:8}
			        	break;
			        fi
			    fi
			done
	fi
	echo ${ver}
}

function get_ver_old(){
	dir=${UPDATE_DIR_DIST}
	ver=""
	if [[ -d ${dir} ]]; then
		cd ${dir}

		for file in ./*
			do
			    if test -f ${file}
			    then
			    	name=${file##*/}
			    	pre=${name:0:8}
			        if [[ ${pre} == "version-" ]]; then
			        	ver=${name:8}
			        	break;
			        fi
			    fi
			done
	fi
	echo ${ver}
}

# 0-版本号不一致，升级，1-版本号一致，不需要升级
function check_version(){
	if [[ ! -d "${UPDATE_DIR_DIST}" ]]; then
		mkdir "${UPDATE_DIR_DIST}"
		print "现用版本文件夹不存在，直接升级！！！"
		echo 0
	else
		old_ver=$(get_ver_old)
		new_ver=$(get_ver_new)

		msg="升级包内版本号=${new_ver}，现用版本号=${old_ver}，"
		if [[ ${old_ver} != ${new_ver} ]];then
			print "${msg}需要升级！！！"
			echo 0
		else
			print "${msg}无需升级！！！"
			echo 1
		fi
	fi
}

# 1-解压成功，0-解压失败
function unzip_file(){
	if [ ! -f "${UPDATE_FILE}" ]; then
		print "升级文件${UPDATE_FILE}不存在"
		echo 0
	else
		if [[ ! -d "${UPDATE_DIR_DIST}" ]]; then
			mkdir "${UPDATE_DIR_DIST}"
		fi

		cd ${UPDATE_DIR_DIST}
		print "开始在${UPDATE_DIR_DIST}目录下解压${UPDATE_FILE}文件"
		rm -rf ${UPDATE}
		unzip ${UPDATE_FILE} && echo 1 || echo 0
	fi
}

# sql导入
function do_import(){
	file=$1

	raw=$(basename ${file} .sql)
	db=${raw#*_}
	print "导入数据库，使用的数据库是${db}"

	succes="${file}导入成功！！！"
	error="${file}导入失败"
	mysql -u${USER} -p${PASSWORD} --default-character-set=utf8 ${db} < ${file} && print ${succes} || print ${error} 
}

# 获取MySQL的状态，0-stop，1-启动成功，2-启动中
function get_status(){
	status=`service mysql status`
	starting="mysql start/running, process"
	postStart="mysql start/post-start"

	if [[ $status =~ $starting ]]; then
		echo 1
	elif [[ $status =~ $postStart ]]; then
		echo 2
	else
		echo 0
	fi
}

# 校验MySQL是否启动完成，0-启动失败，1-启动完成
function check_mysql(){
	retryTime=100
	failure=0
	while [[ ${failure} -lt $retryTime ]]; do
		status=$(get_status)
		if [[ $status -eq 2 ]]; then
			failure=`expr ${failure} + 1`
			print "mysql正在启动，2秒后重试"
			sleep 1s
		elif [[ $status -eq 0 ]]; then
			failure=`expr ${failure} + 1`
			print "mysql尚未启动，2秒后重试"
			sleep 2s
		else
			break
		fi
	done

	if [[ $(get_status) == 1 ]]; then
		print "MySQL启动成功"
		echo 1
	elif [[ $(get_status) == 2 ]]; then
		print "尝试${retryTime}秒后MySQL仍在启动"
		echo 0
	else
		print "MySQL启动失败"
		echo 0
	fi
}

# 升级数据库
function update_sql(){
	sql_dir="${UPDATE_DIR_DIST}/${UPDATE}/${SQL}"

	checkMysql=$(check_mysql)

	if [[ $checkMysql -eq 1 ]]; then
		if [[ -d ${sql_dir} ]]; then
			cd ${sql_dir}

			for file in ./*
			do
			    if test -f ${file}
			    then
			    	name=${file##*/}
			        if [[ ${name##*.} == "sql" ]]; then
			        	print "发现sql文件:${name}"
			        	do_import ${sql_dir}/${name}
			        fi
			    fi
			done
		fi
		echo 1
	else
		echo 0
	fi
}

# 给两个tomcat添加执行权限
function addX(){
	path=$1

	cd $path
	chmod u+x *.sh
}

function unzip_tomcat(){
	file=$1
	cd $TOMCAT_PARENT
	tar -xzf $file && rm -f $file && print "${file}解压成功"
}

# 升级tomcat
function update_tomcat(){
	tomcat_dir="${UPDATE_DIR_DIST}/${UPDATE}/${TOMCAT_DIR}"
	# 判断是否需要升级tomcat
	if [[ -d ${tomcat_dir} ]]; then
		if [ "`ls -A $tomcat_dir`" = "" ]; then
			print "tomcat升级文件夹为空"
		else
			cd ${tomcat_dir}
			if [[ -f ${TOMCAT}.tar.gz ]]; then
				# 删除原来旧的tomcat
				rm -rf ${TOMCAT_HOME} && print "tomcat删除成功！"
				# 将新的tomcat复制过去
				cp -R ${TOMCAT}.tar.gz ${TOMCAT_PARENT} && unzip_tomcat ${TOMCAT}.tar.gz && addX ${TOMCAT_HOME}/bin/ && print "升级tomcat成功！！！"	
			fi
		fi
	else
		print "tomcat升级文件夹不存在"
	fi
}

function update_script(){
	script_dir="${UPDATE_DIR_DIST}/${UPDATE}/${SCRIPT}"

	if [[ -d ${script_dir} ]]; then
		if [ "`ls -A $script_dir`" = "" ]; then
			print "脚本文件夹为空"
		else
			cd ${script_dir}
			cp -r * ${SCRIPT_HOME} && print "升级script包成功！！！"
		fi

		cd ${SCRIPT_HOME}
		chmod -R 777 * && print "脚本赋权限成功！！！"
	else
		print "脚本文件夹不存在"
	fi
}

# 升级lib
function update_lib(){
	lib_dir="${UPDATE_DIR_DIST}/${UPDATE}/${LIB}"

	if [[ -d ${lib_dir} ]]; then
		if [ "`ls -A $lib_dir`" = "" ]; then
			print "lib文件夹为空"
		else
			cd ${lib_dir}
			cp *.jar ${TOMCAT_LIB} && print "升级lib包成功！！！"
		fi
	else
		print "lib文件夹不存在"
	fi
}

# 升级字库
function update_font(){
	font_dir="${UPDATE_DIR_DIST}/${UPDATE}/${FONT}"
	if [[ -d ${font_dir} ]]; then
		if [ "`ls -A $font_dir`" = ""  ]; then
			print "font文件夹为空"
		else
			cd ${font_dir}
			cp -r *.traineddata ${FONT_DIR} && print "升级font成功！！！"
		fi
	else
		print "font文件夹不存在"
	fi
}

# 升级爬虫
function update_crawler(){
	crawler_dir="${UPDATE_DIR_DIST}/${UPDATE}/${CRAWLER}"
	if [[ -d ${crawler_dir} ]]; then
		if [ "`ls -A $crawler_dir`" = ""  ]; then
			print "font文件夹为空"
		else
			cd ${crawler_dir}
			cp -r * ${CRAWLER_DIR} && print "升级爬虫成功！！！"
		fi
	else
		print "爬虫文件夹不存在"
	fi
}

# 执行升级tomcat中的war包
function do_update_war(){
	file=$1
	project=$(basename ${file} .war)

	print "删除${project}项目"

	cd ${TOMCAT_WEBAPPS}
	rm -rf ${project}
	cp ${file} ${TOMCAT_WEBAPPS} && print "${project}项目升级成功！！！"
}
# 升级tomcat中的war包
function update_war(){
	web_dir="${UPDATE_DIR_DIST}/${UPDATE}/${WEB}"

	if [[ -d ${web_dir} ]]; then
		cd ${web_dir}
		# cp *.war ${TOMCAT_WEBAPPS} && print "升级war包成功！！！"
		
		cnt=`ls . | wc -l`

		if [[ $cnt == 0 ]]; then
			print "web文件夹中没有war包"
		else
			for file in ./*
			do
			 	name=${file##*/}
			 	do_update_war ${web_dir}/${name}
			done
		fi
	else
		print "web文件夹不存在"
	fi
}

function update_ver(){
	cd ${UPDATE_DIR_DIST}
	rm -rf ${VERSION} && cp ${UPDATE_VER} ${UPDATE_DIR_DIST} && print "升级版本文件成功！！！"
}

function do_update(){
	
	# update_tomcat
	update_script
	update_shell
	sqlStatus=$(update_sql)
	if [[ $sqlStatus -eq 1 ]]; then
		update_lib
		update_war
		update_ver
		update_font
		update_crawler
		echo 1
	else
		print "MySQL服务启动异常"
		echo 0
	fi
}

# 更新部署
function update(){
	if [[ $(check_version) == 1 ]]; then
		echo 1
	else
		if [[ $(unzip_file) == 0 ]]; then
			print "解压失败"
			echo 0
		else
			print "解压${UPDATE}.zip文件成功！！！"
			echo $(do_update)
		fi
	fi
}

function run(){
	log_time=`date '+%Y-%m-%d %H:%M:%S'`
	print "execute time : ${log_time}"
    	mount_nas
	start_turnserver
	update_tesseract
	start_mysql
	if [[ $(update) == 1 ]]; then
		pkill -9 java
		start_tomcat
	else
		print "升级失败"
	fi
        
	print "-----------------------------------------------------------------------"
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
