#固定5秒运行收集一次
INTERVAL=5
PERFIX=$INTERVAL-sec-status
RUNFILE=/tmp/benchmarks/mysql/running
mysql -e 'SHOW GLOBAL VARIABLES' >> mysql-variables
while test -e $RUNFILE; do
	file=$(date +%F_%I)
	sleep=$(date +%s.%N | awk "{print $INTERVAL - (\$1 % $INTERVAL)}")
	#不直接用sleep 5
	echo $sleep
	sleep $sleep
	ts="$(date +"TS %s.%N %F %T")"
	loadavg="$(uptime)"
	echo "$ts $loadavg">>$PERFIX-${file}-status
	mysql -e 'SHOW GLOBAL STATUS'>> $PERFIX-${file}-status &
	echo "$ts $loadavg">>$PERFIX-${file}-innodbstatus
	mysql -e 'SHOW ENGINE INNODB STATUS\G'>>$PERFIX-${file}-innodbstatus &
	echo "$ts $loadavg">>$PERFIX-${file}-processlist
	mysql -e 'SHOW FULL PROCESSLIST\G'>>$PERFIX-${file}-processlist &
	echo $ts
done
echo Exiting because $RUNFILE does not exist.