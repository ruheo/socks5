#!/usr/bin/env bash

#====================================================
#   System Request:Centos 7+ or Ubuntu 20.4+
#  
#   Dscription: Socks5 Installation
#   Version: 1.0
#   
#   
#====================================================

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
    cd "$(dirname "$0")" || exit
    pwd
)" || exit

#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
source '/etc/os-release'
#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
error="${Red}[错误]${Font}"
check_system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
        INS="yum"
#	$INS update -y
	yum remove firewalld -y ; yum install -y iptables-services ; iptables -F ; iptables -t filter -F ; systemctl enable iptables.service ; service iptables save ; systemctl start iptables.service

    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font}"
        INS="apt"
        $INS update -y
        ## 添加 apt源
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
        INS="apt"
        $INS update 
	systemctl disable ufw.service ; systemctl stop ufw.service
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font}"
        exit 1
    fi

	$INS -y install lsof wget curl
}


is_root() {
    if [ 0 == $UID ]; then
        echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
        sleep 3
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到使用 'sudo -i' 切换到root用户后重新执行脚本 ${Font}"
        exit 1
    fi
}

judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}

sic_optimization() {
    # 最大文件打开数
    sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
    echo '* soft nofile 65536' >>/etc/security/limits.conf
    echo '* hard nofile 65536' >>/etc/security/limits.conf

    # 关闭 Selinux
    if [[ "${ID}" == "centos" ]]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
    fi

}

port_set() {
        read -rp "请设置端口（默认:9999,直接按回车即可）:" port
        [[ -z ${port} ]] && port="9999"
}

port_exist_check() {
    if [[ 0 -eq $(lsof -i:"${port}" | grep -i -c "listen") ]]; then
        echo -e "${OK} ${GreenBG} $1 端口未被占用 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 检测到 ${port} 端口被占用，以下为 ${port} 端口占用信息 ${Font}"
        lsof -i:"${port}"
        echo -e "${OK} ${GreenBG} 3s 后将尝试自动 kill 占用进程 ${Font}"
        sleep 3
        lsof -i:"${port}" | awk '{print $2}' | grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill 完成，请继续操作 ${Font}"
        sleep 1
    fi
}

user_set() {
	read -rp  "请设置用户名。默认:caishen891,直接按回车即可）:" user
	[[ -z ${user} ]] && user="caishen891"
	read -rp "请设置密码。默认:999999,直接按回车即可）:" passwd
	[[ -z ${passwd} ]] && passwd="999999"
}

install_ss5() {

# Xray Installation
wget -O /usr/local/bin/socks --no-check-certificate https://github.com/ruheo/socks5/raw/main/socks 
chmod +x /usr/local/bin/socks

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

systemctl daemon-reload
systemctl enable sockd.service &> /dev/null
}

config_install() {
#Xray Configuration
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
            "port": "$port",
            "protocol": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "$user",
                        "pass": "$passwd"
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
systemctl start sockd.service
}

connect() {
	IPV4=$(curl -4 ip.sb)
	IPV6=$(curl -6 ip.sb)
	echo "IP: $IP"
	echo "端口：$port"
	echo "账户：$user"
	echo "密码：$passwd"
	echo "
IPv4: $IPV4
IPv6: $IPV6
端口：$port
账户：$user
密码：$passwd
" >/root/ss5.txt
}

is_root
check_system

install() {
	sic_optimization
	port_set
	port_exist_check
	user_set
	install_ss5
	config_install
	connect
	systemctl restart sockd.service
	judge "安装 ss5 "
}

del_ss5() {

	systemctl stop sockd.service
	rm -rf /usr/local/bin/socks
	rm -rf /etc/systemd/system/sockd.service
	systemctl daemon-reload
	rm -rf /etc/socks
	judge "删除 ss5 "
}

update_ss5() {
	port_set
        port_exist_check
        user_set
	rm -rf /etc/socks/config.yaml
	config_install
	systemctl restart sockd.service
	connect

}



menu() {
    echo -e "\t Socks5 一键安装脚本 "
    echo -e "\t"
    echo -e "\t---authored by Magic Lamp---"
    echo -e "\t"
    echo -e "\tSystem Request:Debian 9+/Ubuntu 20.04+/Centos 7+"
    echo -e "\t\n"

    echo -e "—————————————— 安装向导 ——————————————"
    echo -e "${Green}   ${Font}"

    echo -e "${Red}   ${Font}"

    echo -e "${Red}  ${Font}"
    echo -e "${Green}1.${Font}  安装Socks5"
    echo -e "${Green}2.${Font}  停止Socks5"
    echo -e "${Green}3.${Font}  删除Socks5"
    echo -e "${Green}8.${Font}  重设端口账户密码"
    echo -e "${Green}9.${Font}  退出 \n"

    echo -e "${Red}   ${Font}"
    
    echo -e "${Green}   ${Font}"
    read -rp "请输入数字1然后直接连续按四次回车即可：" menu_num
    case $menu_num in
    1)
        install
        ;;
    2)
        systemctl stop sockd.service
        judge "停止 ss5 "
        ;;
    3)
        del_ss5
        ;;
    8)
        update_ss5
        ;;
    9)
        exit 0
        ;;
    *)
	echo -e "${RedBG}请输入正确的数字${Font}"
        ;;
    esac

}


menu
