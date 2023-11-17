#!/bin/bash

# Socks5 Installation Script

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Set variables
PORT=9999
USER=caishen891
PASSWD=999999

# Install necessary packages
apt update && apt install -y lsof wget

# Check and set the Socks5 port
read -rp "Set the Socks5 port (default: 9999, press Enter to use default): " input_port
PORT=${input_port:-$PORT}

# Check if the port is available
lsof -i:"$PORT" | grep -i -q "listen"
if [ $? -eq 0 ]; then
    echo "Port $PORT is already in use. Please choose a different port."
    exit 1
fi

# Set Socks5 username and password
read -rp "Set the Socks5 username (default: caishen891, press Enter to use default): " input_user
USER=${input_user:-$USER}
read -rp "Set the Socks5 password (default: 999999, press Enter to use default): " input_passwd
PASSWD=${input_passwd:-$PASSWD}

# Download and install Socks5 binary
wget -O /usr/local/bin/socks --no-check-certificate https://github.com/ruheo/socks5/raw/main/socks
chmod +x /usr/local/bin/socks

# Create Socks5 systemd service
cat <<EOF > /etc/systemd/system/sockd.service
[Unit]
Description=Socks Service
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/socks run -config /etc/socks/config.yaml
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

# Create Socks5 configuration
mkdir -p /etc/socks
cat <<EOF > /etc/socks/config.yaml
{
    "log": {
        "loglevel": "warning"
    },
    "routing": {
        "domainStrategy": "AsIs"
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": "$PORT",
            "protocol": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "$USER",
                        "pass": "$PASSWD"
                    }
                ],
                "udp": true
            },
            "streamSettings": {
                "network": "tcp"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF

# Enable and start the Socks5 service
systemctl daemon-reload
systemctl enable sockd.service
systemctl start sockd.service

# Display connection information
IPv4=$(curl -4 ip.sb)
IPv6=$(curl -6 ip.sb)
echo -e "IPv4: $IPv4\nIPv6: $IPv6\nPort: $PORT\nUsername: $USER\nPassword: $PASSWD"

# Done
echo "Socks5 proxy installed and configured successfully."
