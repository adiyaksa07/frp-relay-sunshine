#!/bin/bash

apply_kernel_optimizations() {
    sed -i '/^net\.\(ipv4\|core\)\..*\(mem\|tcp\|backlog\|congestion\|qdisc\|fastopen\|mtu\|keepalive\)/d' /etc/sysctl.conf

    cat >> /etc/sysctl.conf <<EOF
net.core.rmem_max = 8388608        
net.core.wmem_max = 8388608       
net.core.rmem_default = 524288     
net.core.wmem_default = 524288
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 8000 
net.ipv4.tcp_rmem = 4096 262144 8388608  
net.ipv4.tcp_wmem = 4096 16384 8388608
net.ipv4.tcp_mtu_probing = 1      
net.ipv4.tcp_sack = 1             
net.ipv4.tcp_dsack = 1            
net.ipv4.tcp_fack = 1             
net.core.default_qdisc = cake     
#net.core.default_qdisc = fq_codel 
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 32768 
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 5       
EOF

    sysctl -p
}

setup_qos_aws() {
    command -v tc &> /dev/null || sudo apt-get update -y && sudo apt-get install -y iproute2 || return 11~ command -v tc &> /dev/null || sudo apt-get update -y && sudo apt-get install -y iproute2 || return 11~ command -v tc &> /dev/null || sudo apt-get update -y && sudo apt-get install -y iproute2 || return 11~ command -v tc &> /dev/null || sudo apt-get update -y && sudo apt-get install -y iproute2 || return 1

    local interface=$(ip -o -4 route show to default | awk '{print $5}' | head -1)

    [ -z "$interface" ] && {
        echo "无法确定网络接口!"
        return 1
    }

    command -v tc &> /dev/null || sudo apt-get update -y && sudo apt-get install -y iproute2 || return 1

    sudo tc qdisc del dev $interface root 2>/dev/null

    sudo tc qdisc add dev $interface root handle 1: htb r2q 100 default 10 || {
        echo "创建qdisc失败!"
        return 1
    }

    instance_type=$(curl -s http://169.254.169.254/latest/meta-data/instance-type || echo "unknown")
    case $instance_type in
        "t2.micro") rate_kbps=100000; burst_kb=100;;
        "t3.medium") rate_kbps=500000; burst_kb=500;;
        *) rate_kbps=1000000; burst_kb=1000;;
    esac

    sudo tc class add dev $interface parent 1: classid 1:1 htb rate ${rate_kbps}kbit burst ${burst_kb}k || {
        echo "无法创建主类!"
        return 1
    }

    frp_rate_kbps=$((rate_kbps / 2))
    frp_burst_kb=$((burst_kb / 2))

    sudo tc class add dev $interface parent 1:1 classid 1:10 htb rate ${frp_rate_kbps}kbit burst ${frp_burst_kb}k prio 1 || {
        echo "无法创建FRP类!"
        return 1
    }

    for port in 7000 7001 7002; do
        sudo tc filter add dev $interface protocol ip parent 1: prio 1 u32 match ip dport $port 0xffff flowid 1:10 ||
        echo "端口$port优先级设置失败"
    done

    sudo tc qdisc add dev $interface parent 1:10 sfq perturb 10 2>/dev/null

    echo -e "\n当前QoS配置:"
    sudo tc -s qdisc show dev $interface
    echo -e "\n类详细信息:"
    sudo tc class show dev $interface
    echo -e "\n过滤器统计:"
    sudo tc filter show dev $interface
}

setup_sunshine_tweaks() {
    echo -e "\n应用Sunshine云游戏专用优化..."
    
    if ! command -v irqbalance &> /dev/null; then
        echo "安装irqbalance..."
        apt-get update && apt-get install -y irqbalance
    fi
    systemctl enable --now irqbalance
    echo "IRQ平衡已启用"

    if ! command -v cpufreq-set &> /dev/null; then
        echo "安装cpufrequtils..."
        apt-get update && apt-get install -y cpufrequtils
    fi
    
    echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
    systemctl restart cpufrequtils
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" | tee $cpu >/dev/null
    done
    
    echo "CPU governor设置为performance模式"
}

[ "$(id -u)" -ne 0 ] && {
    echo "请使用root或sudo运行!"
    exit 1
}

set_mtu_size() { 
    local MTU_SIZE=1500
    local MAIN_IFACE=$(ip -o -4 route show default | awk '{print $5}')

    echo "[AWS] 正在设置 MTU 为 $MTU_SIZE (主接口: $MAIN_IFACE)..."

    if [ -z "$MAIN_IFACE" ]; then
        echo "错误: 未找到默认网络接口!"
        return 1
    fi

    if sudo ip link set dev $MAIN_IFACE mtu $MTU_SIZE; then
        echo "成功: $MAIN_IFACE MTU 临时设置为 $MTU_SIZE"


        if [ -d /etc/netplan ]; then
            echo "持久化配置到 /etc/netplan..."
            sudo bash -c "cat > /etc/netplan/99-mtu.yaml" <<EOF
network:
  version: 2
  ethernets:
    $MAIN_IFACE:
      mtu: $MTU_SIZE
EOF
            sudo netplan apply
            echo "MTU 设置已持久化。"
        fi
    else
        echo "错误: 无法设置 MTU! 请检查实例是否支持 ENA 和 Jumbo Frame。"
        echo "提示: AWS 实例类型必须是带有 'n' 的型号（如 c5n.4xlarge）。"
    fi
}

apply_kernel_optimizations
setup_qos_aws
setup_sunshine_tweaks
#using default mtu size
#set_mtu_size

echo -e "\n优化完成! 当前配置:"
sysctl -a | grep -e rmem -e wmem -e tcp_ -e somaxconn | grep -v default

echo -e "\n建议重启系统以使所有优化生效"
