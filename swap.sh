#!/bin/bash

# 设置虚拟内存文件的路径
swapfile="/swapfile"

# 设置虚拟内存大小，单位为 MB
swapsize=2048

# 创建虚拟内存文件
sudo fallocate -l ${swapsize}M ${swapfile}

# 设置权限
sudo chmod 600 ${swapfile}

# 将文件格式化为交换空间
sudo mkswap ${swapfile}

# 启用交换空间
sudo swapon ${swapfile}

# 添加到 /etc/fstab 以在系统启动时自动启用交换空间
echo "${swapfile} none swap sw 0 0" | sudo tee -a /etc/fstab
