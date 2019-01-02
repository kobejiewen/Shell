# 重置服务器
#!/bin/bash
TOMCAT_HOME='/data/tomcat'	# tomcat目录
LOG_HOME='/data/logs'	# tomcat日志目录
NAS_HOME='/opt/mynas'	# nas目录
LOG_DIR="/opt/server_init/reset_logs/" # 日志目录
LOG_FILE="${LOG_DIR}reset_server.log" # 执行日志


# 数据库配置
USERNAME='root'
PASSWORD='lua12378900'

function print(){
	echo $1 >> "${LOG_FILE}"
}

# 清除tomcat下的项目
function clear_tomcat(){
    apps_dir=${TOMCAT_HOME}/webapps
    guide_dir=${TOMCAT_HOME}/webapps1
    if [[ -d ${apps_dir} ]]; then
        print "发现webapps目录，准备删除所有项目！！！"
        cd ${apps_dir} && pkill -9 java && rm -rf * && print "删除完成！！！"
    else
        print "未发现webapps目录，跳过删除Tomcat，继续执行其他任务！！！"
    fi
    if [[ -d ${guide_dir} ]]; then
        print "发现webapps1目录，准备删除所有项目！！！"
        cd ${guide_dir} && pkill -9 java && rm -rf * && print "删除完成！！！"
    else
        print "未发现webapps1目录，跳过删除向导，继续执行其他任务！！！"
    fi
}

# 清除nas下面的用户文件
function clear_nas(){
    print "开始清理nas"
    if [[ -d ${NAS_HOME} ]]; then
        for file in ${NAS_HOME}/*
        do
            rm -rf $file & print "${file} 清理完成！！！"
        done
        print "nas清除完成"
    else
        print "nas不存在，跳过删除"
    fi
}

function clear_other(){
    rm -rf /opt/server_update
    print "server_update 清理完成！"
    mv /opt/server_init/dnspod_cnf.ini /opt/server_init/dnspod_cnf.ini.bak
    print "dnspod配置文件修改完成！"
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

# 清除数据库中的表
function clear_db(){
    checkMysql=$(get_status)
	if [[ $checkMysql -eq 1 ]]; then
	    tables=$(mysql -u${USERNAME} -p${PASSWORD} --default-character-set=utf8 $1 -e 'show tables')
        print "开始清除 $1 数据库"
        for t in $tables
        do
            mysql -u${USERNAME} -p${PASSWORD} --default-character-set=utf8 $1 -e "drop table $t"
            mysql -u${USERNAME} -p${PASSWORD} --default-character-set=utf8 $1 -e "drop view $t"
            print "清除 $1.$t 成功！"
        done
        print "数据库清除成功！！！"
	else
		print "mysql状态异常！！！"
	fi
}

function run(){
	log_time=`date '+%Y-%m-%d %H:%M:%S'`
	print "execute time : ${log_time}"
    #clear_tomcat
    #clear_nas
    #clear_other
    clear_db control_core
    clear_db wechat_business
    clear_db data_center
    clear_db server_guide
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
