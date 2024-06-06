#!/bin/bash
# 检测Telnet端口的Shell脚本
# linux系统检测可用,macos没有timeout命令
# #表示注释
# 192.168.0.1:8080
# 输入参数：IP地址:端口号
check_telnet(){
for ip_port in $(cat remotes.txt|grep -v '^#')
do
    CHECK_IP=$(echo $ip_port|awk -F: '{print $1}')
    CHECK_PORT=$(echo $ip_port|awk -F: '{print $2}')
    #echo "test $CHECK_IP $CHECK_PORT"
    #timeout 1s考虑到telnet连接不同的地址和端口号时长时间挂起问题
    xz=`timeout 1s telnet $CHECK_IP $CHECK_PORT |grep "Connected"|wc -l` #判断连通性命令
    if [ $xz -eq 0 ]; #输出结果
        then
                echo "服务器$CHECK_IP $CHECK_PORT连接失败" 
        else
                echo "服务器$CHECK_IP $CHECK_PORT连接成功" 
    fi
done
}
check_telnet >result.log
