#!/usr/bin/env bash

history命令在脚本里面执行不成功解决方案 https://blog.csdn.net/weixin_44316575/article/details/89817537
#history | awk '{CMD[$2]++;count++;} END { for (a in CMD )print CMD[ a ]" " CMD[ a ]/count*100 "% " a }' | grep -v "./" | column -c3 -s " " -t |sort -nr | nl | head -n10