#!/usr/bin/env bash
# sort AbstractRecursivePageJobHandler ,query page interface info

filename=$1
if [[ ${filename} == '' ]];then
	echo 'must input file name;'
	exit 0	
fi
if [[ ! -e ${filename} ]];then
	echo "$filename not exist."
	exit 0
fi
if [[ ! -f ${filename} ]];then
	echo "$filename is not file"
	exit 0
fi
echo "start to handle $filename,$#"

columns=('$9','$10','$1','$2')
if [[ $# -gt 1 ]];then
	# 进行一次变量的迁移
	echo 'a'
	shift
	columns=$@
fi
echo "show columns info: $columns"
# TODO:cj 后续考虑动态传参数
cat ${filename}|sed 's/^.*bodyParam":"{//g'|sed 's/}","extraParam".*$//g'|sed 's/[\\"]//g'|awk -F , '{print $9,$10,$1,$2}'|sort





