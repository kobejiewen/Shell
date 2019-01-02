#!/bin/bash
#DATE:Mon Oct  8 14:06:35 2018
#功能:修改平台域名
## 使用方式
##ssh root@ip -p 1022
##sh edit_subdomain.sh


#dnspod data
DNSPOD=/opt/server_init/dnspod_cnf.ini
SUB=''

#mysql data
HOSTNAME="localhost"
PORT="3306"
USERNAME="root"
PASSWORD="lua12378900"

CONTROLDB="control_core"
CONTROLTABLE="config"
WECHATDB="wechat_business"
WECHATTABLE="config"
VIODB="violet"
VIOTABLE="configure"
SERVERDB="server_guide"
SERVERTABLE="config"

#input dnspod
function Input(){
  read -p "input sub_domain: " sub1
  read -p "input sub_domain again:" sub2
  if [[ "$sub1" = "$sub2" ]]; then
  	 SUB=${sub1}
  else
    echo "两次输入域名不一致，脚本退出"
    exit 0
  fi  
}

#edit dnspod 
function Edit(){
  echo "修改域名为${1}"
  sed -i '5 d' $DNSPOD
  sed -i "N;4asub_domain = ${1}"   $DNSPOD 
  Editdns=`cat $DNSPOD |grep sub_domain`
  echo "域名修改完成: ${Editdns}"
}

# start dnspod
function Start(){
  echo "重启dnspod"
  supervisorctl restart dnspod 
}

#mysql  dns
function Mysql(){
 echo “数据库更新完成后自动重启...”
 sleep 1
 echo "更新control数据库"
 update_control="update ${CONTROLTABLE} set value1='${1}' where key1 ='serverCode'" 
 mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${CONTROLDB} -e  "${update_control}"
 
 echo "更新wechat数据库"
 update_wechat="update ${WECHATTABLE} set value1='${1}' where key1= 'root_code'"
 mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${WECHATDB} -e  "${update_wechat}"

 echo "更新violet数据库"
 update_violet="update ${VIOTABLE}  set value1='${1}' where name1= 'NODE_CODE'"
 mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${VIODB} -e  "${update_violet}"

 echo "更新server_guide数据库"
 update_server="update ${SERVERTABLE} set value1='${1}' where name = 'server_code'"
 mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${SERVERDB} -e  "${update_server}" 
}

function run(){
	Input;
	Edit $SUB;
	Start;
	Mysql $SUB;
}
run;
