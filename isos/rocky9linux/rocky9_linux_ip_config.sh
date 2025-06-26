#查看ip addr地址信息
#查看网卡信息
nmcli con sho
#NAME    UUID                                  TYPE      DEVICE 
#ens160  c94038f8-4c84-3de4-968d-3e7db01f2258  ethernet  ens160 
#lo      dfd9fd02-e1eb-43f4-ad78-46f5f8e3d5ec  loopback  lo 
#ip addr

#老版本的network-scripts网络连接方式已经被替换了，采用NetworkManager新式网络连接方式
#修改为固定ip地址形式,ifcfg-网卡名称
#vim /etc/sysconfig/network-scripts/ifcfg-ens33
vi /etc/NetworkManager/system-connections/ens160.nmconnection
#重启网卡
#systemctl restart network
systemctl restart NetworkManager
ping www.baidu.com

#设置vpn代理
cat >> ~/.bash_profile <<-EOF
#http by host proxy 
export http_proxy=http://192.168.43.111:10809
export https_proxy=http://192.168.43.111:10809
export no_proxy="localhost, 127.0.0.1, ::1"
EOF

cat ~/.bash_profile

source ~/.bash_profile
echo $http_proxy
echo $https_proxy
echo $no_proxy