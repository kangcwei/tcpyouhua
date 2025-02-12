#!/bin/bash

# 更新并安装 wget
yum install wget -y

# 创建代理目录并进入
mkdir -p /usr/local/proxy
cd /usr/local/proxy

# 下载并解压 NPS 客户端
wget https://github.com/ehang-io/nps/releases/download/v0.26.9/linux_amd64_client.tar.gz
tar xvf linux_amd64_client.tar.gz
rm -f linux_amd64_client.tar.gz

# 移动并重命名文件
mv npc proxy
mv conf/npc.conf conf/proxy.conf

# 创建 start.sh 脚本
cat > /usr/local/proxy/start.sh <<EOF
#!/bin/bash
nohup /usr/local/proxy/proxy -config /usr/local/proxy/conf/proxy.conf -debug=false >/dev/null 2>&1 &
EOF

# 授权执行权限
chmod +x /usr/local/proxy/start.sh

# 创建 systemd 服务文件
cat > /etc/systemd/system/proxy.service <<EOF
[Unit]
Description=proxy
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/proxy/start.sh
Restart=always
RestartSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# 配置 proxy.conf 文件
cat > /usr/local/proxy/conf/proxy.conf <<EOF
[common]
server_addr=202.81.232.133:8024
conn_type=kcp
vkey=kangcw123qwehk
auto_reconnection=true
max_conn=300
flow_limit=1000
rate_limit=1000
crypt=true
compress=true
disconnect_timeout=1
EOF

# 启动并设置服务开机自启
systemctl daemon-reload
systemctl start proxy
systemctl enable proxy

# 输出安装成功消息
echo "Proxy service has been successfully installed and started."
