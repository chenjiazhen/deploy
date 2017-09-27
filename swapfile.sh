#!/bin/bash

# check permission
if [ `id -u` != '0' ]; then
  echo 'Error: You must be root to run this script'
  exit 1
fi

# 获取要增加的2G的SWAP文件块
dd if=/dev/zero of=/swapfile bs=1k count=2048000
# 创建SWAP文件
mkswap /swapfile
# 激活SWAP文件 
swapon /swapfile
# 添加到fstab文件中让系统引导时自动启动  
echo "/var/swapfile swap swap defaults 0 0" >> /etc/fstab

echo 'Successful installation'