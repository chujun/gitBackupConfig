# 用户名与密码root root,chujun chujun
# yum 下载地址调整为阿里云镜像地址，默认的centos镜像不能再使用了，install会提示安装错误
#curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

#cat /etc/yum.repos.d/CentOS-Base.repo

sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.aliyun.com/rockylinux|g' \
    -i.bak \
    /etc/yum.repos.d/[Rr]ocky*.repo

cat /etc/yum.repos.d/[Rr]ocky*.repo    
#更新镜像缓存列表
yum clean all
yum makecache
yum -y update
#这儿就可以正常使用yum install命令了
# 安装必要软件,后续还可以再补充
#Rocky Linux 8/9 已改用 chrony 作为默认时间同步服务，官方仓库不再提供 ntp 包，建议chrony替换
yum install telnet vim wget java-1.8.0-openjdk httpd-tools git nc tree tcpdump -y

# 启动并设置开机自启
sudo systemctl enable --now chronyd

# 验证状态
chronyc tracking  # 查看时间源状态
timedatectl       # 检查时间同步状态
#查看时间和时区信息
timedatectl




# docker镜像地址加速
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
      "https://mirror.aliyuncs.com",
      "https://hub-mirror.c.163.com"
  ]
}
EOF

dnf install -y yum-utils
# 2. 添加阿里云 Docker 仓库
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 3. 替换仓库中的下载地址为阿里云镜像（避免官方源速度慢）
cat /etc/yum.repos.d/docker-ce.repo
sed -i 's#download.docker.com#mirrors.aliyun.com/docker-ce#g' /etc/yum.repos.d/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io


## 官网下载方式: 安装docker，目前这个官网下载脚本暂时不支持rocky linux服务器
#export DOWNLOAD_URL="http://mirrors.163.com/docker-ce"
#curl -fsSL https://get.docker.com/ | sh
##检查docker安装情况
docker -v
# 启动docker
systemctl start docker
systemctl status docker

#安装docker-compose
###这儿可能会有网络访问慢问题，github.com地址
curl -SL https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
#docker-compose安装检查
docker-compose -v