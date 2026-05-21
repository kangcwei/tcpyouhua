#!/bin/bash

# ==============================================================================
# 脚本名称: xray_tuning.sh
# 适用系统: Ubuntu 22.04+ (8核16G, 230个IP高并发专属优化)
# 运行权限: root
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0;3m' # 重置颜色

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}          Xray 多IP高并发系统内核一键优化脚本          ${NC}"
echo -e "${YELLOW}====================================================${NC}"

# 1. 权限检查
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：必须使用 root 权限或 sudo 运行此脚本！${NC}"
    exit 1
fi

# 2. 获取当前主力网卡名称
NIC=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' || ip -br link show | grep -v LO | awk 'NR==1{print $1}')
if [ -z "$NIC" ]; then
    echo -e "${YELLOW}警告：未能自动获取网卡名称，请稍后手动调整网卡队列。${NC}"
fi

echo -e "${GREEN}[1/5] 开始备份原始系统配置文件...${NC}"
DATE=$(date +%Y%m%d%H%M%S)
[ -f /etc/sysctl.conf ] && cp /etc/sysctl.conf /etc/sysctl.conf.bak-$DATE
[ -f /etc/security/limits.conf ] && cp /etc/security/limits.conf /etc/security/limits.conf.bak-$DATE
echo -e "${GREEN}备份完成。${NC}"

# 3. 写入 sysctl.conf 内核参数
echo -e "${GREEN}[2/5] 正在配置 Linux 内核网络参数 (/etc/sysctl.conf)...${NC}"

# 清理历史可能存在的冲突配置，防止重复写入
sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
sed -i '/net.netfilter.nf_conntrack/d' /etc/sysctl.conf
sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.rp_filter/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.default.rp_filter/d' /etc/sysctl.conf

cat >> /etc/sysctl.conf << 'EOF'

# --- Xray High Concurrency Tuning ---
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 15
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
# -------------------------------------
EOF

# 使内核参数立即生效
sysctl -p >/dev/null 2>&1
echo -e "${GREEN}内核参数应用成功，BBR 拥塞控制已开启。${NC}"

# 4. 写入 limits.conf 文件描述符
echo -e "${GREEN}[3/5] 正在配置系统文件描述符限制 (/etc/security/limits.conf)...${NC}"

sed -i '/nofile/d' /etc/security/limits.conf
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
echo -e "${GREEN}系统文件描述符修改成功 (1048576)。${NC}"

# 5. 配置 Systemd 全局及服务文件描述符上限
echo -e "${GREEN}[4/5] 正在配置 Systemd 全局服务限制...${NC}"

# 优化 Systemd 系统全局级别
sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNOFILE/d' /etc/systemd/user.conf
echo "DefaultLimitNOFILE=1048576" >> /etc/systemd/system.conf
echo "DefaultLimitNOFILE=1048576" >> /etc/systemd/user.conf

# 针对 xray.service 的专属动态覆盖配置
XRAY_SERVICE_DIR="/etc/systemd/system/xray.service.d"
mkdir -p "$XRAY_SERVICE_DIR"
cat > "$XRAY_SERVICE_DIR/override.conf" << 'EOF'
[Service]
LimitNOFILE=1048576
Environment=GOMAXPROCS=8
Environment=GOGC=200
EOF

systemctl daemon-reload
echo -e "${GREEN}Systemd 及 Xray 专属覆盖配置完成（多核、GC延迟优化已注入）。${NC}"

# 6. 调整网卡发送队列
if [ -not -z "$NIC" ]; then
    echo -e "${GREEN}[5/5] 正在优化网卡 ${NIC} 的发送队列长度 (txqueuelen)...${NC}"
    ifconfig $NIC txqueuelen 5000 2>/dev/null || ip link set dev $NIC txqueuelen 5000
    
    # 写入开机自启，防止重启失效
    if [ ! -f /etc/rc.local ]; then
        echo '#!/bin/bash' > /etc/rc.local
        chmod +x /etc/rc.local
    fi
    sed -i "/txqueuelen/d" /etc/rc.local
    sed -i '/exit 0/d' /etc/rc.local
    echo "ip link set dev $NIC txqueuelen 5000" >> /etc/rc.local
    echo "exit 0" >> /etc/rc.local
    echo -e "${GREEN}网卡队列已放大到 5000，并已配置开机自启。${NC}"
else
    echo -e "${YELLOW}[5/5] 跳过网卡队列优化（未发现物理网卡）。${NC}"
fi

echo -e "${YELLOW}====================================================${NC}"
echo -e "${GREEN}              🎉 所有优化策略配置完成！              ${NC}"
echo -e "${YELLOW}提示：${NC}"
echo -e "${YELLOW}1. 请执行 'systemctl restart xray' 重新加载Xray服务。${NC}"
echo -e "${YELLOW}2. 'limits.conf' 对当前终端不会立即生效，建议断开SSH重新连接或重启服务器。${NC}"
echo -e "${YELLOW}====================================================${NC}"
