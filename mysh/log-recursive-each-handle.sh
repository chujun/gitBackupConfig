#!/usr/bin/env bash
# $1: filename
# $2: sed pre filter str
# $3: sed post filter str
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
preStr=$2
postStr=$3


#cat ${filename}|sed "s/^.*key=(tradeInOrderNo://g"|sed 's/),pageQuery={.*$//g'|sort -n|uniq -c|sort -n

test $2 && pre_str=$2 || pre_str='^.*key=(tradeInOrderNo:'
test $3 && post_str=$3 ||post_str='),pageQuery={.*$'

cat ${filename}|sed "s/$pre_str//g"|sed "s/$post_str//g"|sort -n|uniq -c|sort -n

echo "$pre_str,$post_str"