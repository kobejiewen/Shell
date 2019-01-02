#!/bin/bash
# description:自动化监控raid备份情况


DEV="/dev/md0" # 监控的raid分区
LOG_DIR="/opt/logs/" # 日志目录
LOG_FILE="${LOG_DIR}raidMonitor.log" # 执行日志

function init(){
	# 创建日志目录
	if [[ ! -d ${LOG_DIR} ]]; then  
		mkdir "${LOG_DIR}"
	fi

	# 创建日志文件
	if [[ ! -f "${LOG_FILE}" ]]; then
		touch "${LOG_FILE}"
	fi
}
init


function print(){
	echo $1 >> "${LOG_FILE}"
}

LocalmacAddr=`/sbin/ifconfig | awk '/eth0/{print $NF}'`
function getMacAddr(){
	macAddr=`/sbin/ifconfig | awk '/eth0/{print $NF}'`
	res="\"mac\":\"${macAddr}\","
	echo $res
}

# 获取命令中的key:value值
function getKV(){
	file=$1
	str=
	while read LINE
	do
		key=`echo $LINE | awk -F ' : ' '{print $1}'`
		val=`echo $LINE | awk -F ' : ' '{print $2}'`

		if [[ $key == "Raid Level" ]]; then
			str+="\"raid_level\":\"${val}\","
		elif [[ $key == "Raid Devices" ]]; then
			str+="\"raid_devices\":${val},"
		elif [[ $key == "Total Devices" ]]; then
			str+="\"total_devices\":${val},"
		fi
	done < $file

	echo $str
}

function getList(){
	file=$1
	flag=0
	str=
	while read LINE
	do
		tp=`echo $LINE | awk -F ' ' '{print $1}'`
		if [[ $tp == "Number" ]]; then
			flag=1
			continue
		fi

		if [[ $flag == 1 ]]; then
			line=`echo $LINE | awk '{for(i=1;i<=3;i++){$i=""};print $0}'`
			str+="${line};"
		fi
	done < $file

	res="\"detail\":\"${str}\""
	echo $res
}

function getDf(){
	disk=$1
	str=`df -h | grep ${disk}`
	dfSize=`echo $str | awk '{print $2}'`
	dfUsed=`echo $str | awk '{print $3}'`

	res="\"size\":\"${dfSize}\",\"used\":\"${dfUsed}\","

	echo $res
}

function statistics(){
	disk=$1
	raidInfo="/tmp/raidInfo.txt"

	if [[ -f "${raidInfo}" ]]; then
		rm -rf ${raidInfo}
	fi

	/sbin/mdadm -D ${disk} > ${raidInfo}

	param=$(getKV ${raidInfo})
	dfInfo=$(getDf ${disk})
	res=$(getList ${raidInfo})
	data=${param}${res}

	echo $data
}

function buildMsg(){
	disk=$1

	data="{$(getMacAddr)$(getDf ${disk})$(statistics ${disk})}"
	echo $data
}

function main(){
	print "-----------------------------------------------------------------------" 
	log_time=`date '+%Y-%m-%d %H:%M:%S'`
	print "execute time : ${log_time}"

	data=$(buildMsg $DEV)

	print "获取的监控数据：${data}"
	uri="http://xxxx.com:88/raid-monitor/api/raidInfo/report"
	wget --output-document=/dev/null "$uri?data=${data}"
	
	## 上报给control
	wget --output-document=/dev/null "http://192.168.1.26:88/control/cgi/server"\!"setServerMac.action?mac=${LocalmacAddr}"
	print "上报MAC地址到control：${LocalmacAddr}"
}

# buildMsg $DEV
main