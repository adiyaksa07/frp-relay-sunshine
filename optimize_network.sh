#!/bin/bash

# =============================================
# 脚本功能: Linux内核网络优化及AWS QoS配置
# 主要功能:
#   1. 调整TCP/IP内核参数提升网络性能
#   2. 根据AWS实例类型配置服务质量(QoS)
#   3. 为FRP服务预留专用带宽
# 适用环境: 
#   - AWS EC2实例
#   - 需要优化FRP性能的环境
# 使用方法: 
#   sudo ./optimize_network.sh
# 注意事项:
#   - 需要root权限执行
#   - 会覆盖现有sysctl和tc配置
# =============================================

apply_kernel_optimizations() {
    # 删除旧设置避免重复
    for param in rmem_max wmem_max tcp_rmem tcp_wmem tcp_window_scaling tcp_sack \
                 tcp_low_latency tcp_fin_timeout tcp_tw_reuse somaxconn \
                 tcp_congestion_control default_qdisc tcp_fastopen \
                 netdev_max_backlog tcp_max_syn_backlog tcp_syncookies \
                 ip_local_port_range
    do
        sed -i "/^net\.ipv4\.$param/d" /etc/sysctl.conf
        sed -i "/^net\.core\.$param/d" /etc/sysctl.conf
    done

    cat >> /etc/sysctl.conf <<EOF
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.ipv4.tcp_rmem=4096 87380 4194304
net.ipv4.tcp_wmem=4096 16384 4194304
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_tw_reuse=1
net.core.somaxconn=65535
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq_codel
tcp_mtu_probing=1
net.ipv4.tcp_fastopen=3
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_syncookies=1
net.ipv4.ip_local_port_range=1024 65535
tcp_slow_start_after_idle=0
EOF

    sysctl -p
}

setup_qos_aws() {
    local interface=$(ip -o -4 route show to default | awk '{print $5}' | head -1)

    [ -z "$interface" ] && {
        echo "无法确定网络接口!"
        return 1
    }

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

apply_kernel_optimizations
setup_qos_aws
setup_sunshine_tweaks

echo -e "\n优化完成! 当前配置:"
sysctl -a | grep -e rmem -e wmem -e tcp_ -e somaxconn | grep -v default

echo -e "\n建议重启系统以使所有优化生效"
