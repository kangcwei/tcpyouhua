#!/bin/bash

# 脚本开始

echo "开始优化TCP设置..."

# 增加文件描述符限制
echo "设置文件描述符限制..."
cat <<EOF >> /etc/security/limits.conf
* soft nofile 655350
* hard nofile 655350
EOF

# 临时应用文件描述符限制
ulimit -n 655350

# 调整内核TCP参数
echo "应用sysctl优化..."
cat <<EOF >> /etc/sysctl.conf

# TCP优化参数
fs.file-max = 1000000

# 调整 TCP 缓冲区大小
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144

# 连接队列优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 50000

# TCP 连接优化
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_max_tw_buckets = 2000000

# 端口范围
net.ipv4.ip_local_port_range = 10000 65535

# 其他 TCP 相关优化
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0


# 启用TCP BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

# 应用新的sysctl配置
sysctl -p

echo "TCP优化完成！"

# 脚本结束
