#!/bin/bash

# 脚本开始

echo "开始优化TCP设置..."

# 增加文件描述符限制
echo "设置文件描述符限制..."
cat <<EOF >> /etc/security/limits.conf
* soft nofile 65535
* hard nofile 65535
EOF

# 临时应用文件描述符限制
ulimit -n 65535

# 调整内核TCP参数
echo "应用sysctl优化..."
cat <<EOF >> /etc/sysctl.conf

# TCP优化参数
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_timestamps = 0

# 启用TCP BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

# 应用新的sysctl配置
sysctl -p

echo "TCP优化完成！"

# 脚本结束
