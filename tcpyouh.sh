#!/bin/bash

# 脚本开始
set -e

echo "🛠️ 开始系统调优..."
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
echo
echo "🔔 如需为某个 systemd 服务设置文件描述符限制，请在服务文件中添加："
echo "[Service]"
echo "LimitNOFILE=655350"
echo
echo "然后执行:"
echo "systemctl daemon-reexec && systemctl daemon-reload && systemctl restart your_service"
echo

echo "✅ 系统调优完成，请重启系统或重新登录以确保所有设置生效。"

echo "TCP优化完成！"

# 脚本结束
# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本"
  exit 1
fi

# 添加定时任务到 root 的 crontab
CRON_JOB="0 16 * * * /sbin/shutdown -r now"

# 判断任务是否已经存在
crontab -l | grep -F "$CRON_JOB" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "定时重启任务已存在，无需重复添加。"
else
  (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
  echo "已成功添加定时重启任务：每天 16:00 重启系统"
fi
