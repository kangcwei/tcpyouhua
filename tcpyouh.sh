#!/bin/bash

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 请使用 root 权限运行此脚本"
  exit 1
fi

#set -e

echo "🛠️ 开始系统调优..."
echo "----------------------------------------"

# 设置文件描述符限制（避免重复写入）
echo "🔧 设置文件描述符限制..."
LIMITS_LINE="* soft nofile 655350"
if ! grep -qF "$LIMITS_LINE" /etc/security/limits.conf; then
  cat <<EOF >> /etc/security/limits.conf
* soft nofile 655350
* hard nofile 655350
EOF
  echo "✅ limits.conf 已更新"
else
  echo "ℹ️ limits.conf 已包含该配置，跳过"
fi

# 临时生效
ulimit -n 655350

# sysctl 优化（避免重复）
SYSCTL_MARK="# TCP优化参数"
if ! grep -qF "$SYSCTL_MARK" /etc/sysctl.conf; then
  echo "🔧 写入 sysctl 网络参数优化配置..."
  cat <<EOF >> /etc/sysctl.conf

$SYSCTL_MARK
fs.file-max = 1000000

net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144

net.core.somaxconn = 65535
net.core.netdev_max_backlog = 50000

net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_max_tw_buckets = 2000000

net.ipv4.ip_local_port_range = 10000 65535

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0

net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

  echo "✅ sysctl.conf 参数写入完成"
else
  echo "ℹ️ sysctl.conf 已包含 TCP 优化配置，跳过"
fi

# 应用 sysctl 参数
echo "🚀 应用 sysctl 配置..."
sysctl -p

# 添加定时重启任务（使用 systemctl reboot）
CRON_JOB="0 4 * * * /bin/systemctl reboot"
echo "🕓 设置每天 16:00 自动重启..."
if crontab -l | grep -F "$CRON_JOB" > /dev/null 2>&1; then
  echo "ℹ️ 定时任务已存在，无需重复添加"
else
  (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
  echo "✅ 定时重启任务已添加：每天 16:00"
fi

echo "----------------------------------------"
echo "✅ 所有系统调优完成"
echo "🔔 如需为某个 systemd 服务设置文件描述符限制，请添加到服务文件："
echo "[Service]"
echo "LimitNOFILE=655350"
echo
echo "然后执行:"
echo "systemctl daemon-reexec && systemctl daemon-reload && systemctl restart your_service"
echo
echo "🔁 建议重启系统或重新登录以完全生效"
