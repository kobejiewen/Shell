#!/bin/bash

control_log="/data/logs/control_core"
node_log="/data/logs/node_server"
tomcat_log="/data/tomcat/logs"

# 删除系统运行日志
find $control_log -type f -name "*.log.*" -mtime +20 -exec rm -f {} \;
echo "control日志删除完成！"

find $node_log -type f -name "*.log.*" -mtime +20 -exec rm -f {} \;
echo "node日志删除完成！"

find $tomcat_log -type f -name "*.log" -mtime +30 -exec rm -f {} \;
echo "tomcat日志删除完成！"

# 删除catalina.out日志
file_name="${tomcat_log}/catalina.out"
file_size="ls -l $file_name | awk '{ print $5 }'"
max_size=$((2*1024*1000000))
if [ "$file_size" > "$max_size" ]
then 
    echo "catalina.out文件需要删除！"
    rm -f $fime_name
    echo "catalina.out文件已删除！"
else
    echo "catalina.out文件不需要删除！"
fi