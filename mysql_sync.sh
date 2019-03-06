# !/bin/bash  
# Author    : 
# create_ts : 
# program   : Incremental transfer table records between MySQL servers
# crontab   : 
#  
#  
# source db server config list  
host_src=127.0.0.1
port_src=3306
user_src=root
pswd_src=12378900
dbas_src=lbs
# target db server config list
host_tar=xxx.com
port_tar=23306
user_tar=root
pswd_tar=12378900
dbas_tar=lbs
#
cach_dump=/opt/    # cache directory config
# 
LOG_FILE="/opt/station_sync.log"
Log_time=`date '+%Y-%m-%d %H:%M:%S'`
# 
# define execute sql function
function print(){
	echo $1 >> "${LOG_FILE}"
}

print "execute time : ${Log_time}"

function sqlrun_src(){
mysql -h${host_src} -P${port_src} -u${user_src} -p${pswd_src} <<EOF
$1
EOF
}

function sqlrun_tar(){
mysql -h${host_tar} -P${port_tar}	-u${user_tar} -p${pswd_tar} <<EOF
$1
EOF
}
#  
#  
# do synchronize
tar_run="SELECT MAX(id) AS id FROM ${dbas_tar}.station2;"
if id_ori=$(sqlrun_tar "${tar_run}") && id=${id_ori#id}
	then print  "…………Get Max id ${id}…………"
else exit && print  "…………Get Max id Failed…………"
fi
# 
src_run="SELECT * FROM ${dbas_src}.station2 WHERE id > ${id};"
if sqlrun_src "${src_run}" > ${cach_dump}station2.txt
	then print "…………Write station2 data OK…………"
else exit && print  "…………Write station2 data Failed…………"
fi
# 
if sed -i '1, $s/NULL/\\N/g' ${cach_dump}station2.txt && /usr/bin/mysqlimport -h${host_tar} -P${port_tar} -u${user_tar} -p${pswd_tar} --ignore-lines=1 --local ${dbas_tar} ${cach_dump}station2.txt
		then print  "…………Import station2 data OK…………"
else exit && print  "…………Write station2 data Failed…………"
fi
# 
#   
# clear cache
if
	cd ${cach_dump} && rm -f station2.txt
		then print  "……rm -f station2.txt ok……"
else exit && print  "……rm -f station2.txt Failed……"
fi
# 
#