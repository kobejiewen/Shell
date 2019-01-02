#!/bin/bash
#VER=0
function get_version(){
	if [[ ! $1 ]]; then
		VER=0
	else
		VER=$1
	fi
}
#8.9更新init文件
function update_init(){
	if [ $(echo "${VER} < 8.9"|bc) -eq 1 ]; then
		cd /opt/mynas/init
		wget http://121.201.6.183:1088/init/sync.tar.gz -O sync.tar.gz
		wget http://121.201.6.183:1088/init/users.tar.gz -O users.tar.gz
		wget http://121.201.6.183:1088/init/databases.tar.gz -O databases.tar.gz
		wget http://121.201.6.183:1088/init/sync.tar.gz.md5 -O sync.tar.gz.md5
		wget http://121.201.6.183:1088/init/users.tar.gz.md5 -O users.tar.gz.md5
		wget http://121.201.6.183:1088/init/databases.tar.gz.md5 -O databases.tar.gz.md5
		chmod 777 *
	else
		#部分平台 MD5文件未下发，确认全平台md5文件都存在后 删除else部分
		cd /opt/mynas/init
		wget http://121.201.6.183:1088/init/sync.tar.gz -O sync.tar.gz
		wget http://121.201.6.183:1088/init/users.tar.gz -O users.tar.gz
		wget http://121.201.6.183:1088/init/databases.tar.gz -O databases.tar.gz
		wget http://121.201.6.183:1088/init/sync.tar.gz.md5 -O sync.tar.gz.md5
		wget http://121.201.6.183:1088/init/users.tar.gz.md5 -O users.tar.gz.md5
		wget http://121.201.6.183:1088/init/databases.tar.gz.md5 -O databases.tar.gz.md5
		chmod 777 *
	fi
}
#9.02 同步jar
function run_jar(){
	if [  $(echo "${VER} < 9.02"|bc) -eq 1 ]; then
		export JAVA_HOME=/opt/jdk1.8.0_111
		export JRE_HOME=${JAVA_HOME}/jre
		export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
		export PATH=${JAVA_HOME}/bin:$PATH
		java -jar /opt/server_init/db_sync.jar wechat_business data_center
	fi
}
function run(){
	get_version $1
	update_init
	run_jar
}

run $1
