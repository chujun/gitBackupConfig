
cat >> network-test.sh << 'testEOF'

#!/bin/bash
# 网络连通性综合测试脚本
# 功能：测试 ping 连通性、HTTP/HTTPS 访问、DNS 解析、路由跟踪等
# 作者：元宝
# 版本：2.0
# 日期：2026-03-06

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置参数
PING_COUNT=4
PING_TIMEOUT=2
CURL_TIMEOUT=10
TEST_IP="10.1.32.61"
LOG_FILE="/tmp/network_test_$(date +%Y%m%d_%H%M%S).log"

# 测试目标列表
declare -a PING_TARGETS=(
    "10.1.32.61"
    "8.8.8.8"
    "1.1.1.1"
    "114.114.114.114"
)

declare -a HTTP_TARGETS=(
    "http://www.baidu.com"
    "http://www.google.com"
    "https://www.google.com"
    "https://github.com"
    "https://www.qq.com"
    "https://www.taobao.com"
    "https://mirrors.aliyun.com"
)

# 日志函数
log_info() {
    local msg="$1"
    echo -e "${GREEN}[INFO]${NC} $msg" | tee -a "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    echo -e "${YELLOW}[WARN]${NC} $msg" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[ERROR]${NC} $msg" | tee -a "$LOG_FILE"
}

log_debug() {
    local msg="$1"
    echo -e "${CYAN}[DEBUG]${NC} $msg" | tee -a "$LOG_FILE"
}

log_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓ ${test_name}: ${message}${NC}" | tee -a "$LOG_FILE"
    elif [ "$result" = "FAIL" ]; then
        echo -e "${RED}✗ ${test_name}: ${message}${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}⚠ ${test_name}: ${message}${NC}" | tee -a "$LOG_FILE"
    fi
}

# 打印横幅
print_banner() {
    clear
    echo -e "${BLUE}"
    echo "==============================================="
    echo "    网络连通性综合测试脚本 v2.0"
    echo "==============================================="
    echo -e "${NC}"
    echo "开始时间: $(date)"
    echo "日志文件: $LOG_FILE"
    echo ""
}

# 检查命令是否存在
check_commands() {
    local commands=("ping" "curl" "dig" "nslookup" "traceroute" "mtr" "ip" "ifconfig")
    local missing=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "以下命令未安装: ${missing[*]}"
        log_info "尝试安装缺失的命令..."
        
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y iputils-ping curl dnsutils traceroute mtr iproute2 net-tools
        elif command -v yum &> /dev/null; then
            sudo yum install -y iputils curl bind-utils traceroute mtr iproute net-tools
        else
            log_error "无法自动安装依赖，请手动安装"
        fi
    fi
    
    # 检查curl是否支持SSL
    if curl --version | grep -i "ssl" > /dev/null; then
        log_info "Curl支持SSL/TLS"
    else
        log_warn "Curl可能不支持SSL/TLS，HTTPS测试可能失败"
    fi
}

# 获取系统信息
get_system_info() {
    log_info "收集系统信息..."
    echo "=== 系统信息 ===" >> "$LOG_FILE"
    uname -a >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    echo "=== 系统时间 ===" >> "$LOG_FILE"
    date >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    echo "=== 网络接口 ===" >> "$LOG_FILE"
    if command -v ip &> /dev/null; then
        ip addr show >> "$LOG_FILE"
    elif command -v ifconfig &> /dev/null; then
        ifconfig -a >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
    
    echo "=== 路由表 ===" >> "$LOG_FILE"
    if command -v ip &> /dev/null; then
        ip route show >> "$LOG_FILE"
    elif command -v route &> /dev/null; then
        route -n >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
    
    echo "=== DNS配置 ===" >> "$LOG_FILE"
    if [ -f /etc/resolv.conf ]; then
        cat /etc/resolv.conf >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
}

# DNS解析测试
test_dns() {
    log_info "开始DNS解析测试..."
    local domains=("www.baidu.com" "www.google.com" "github.com" "www.qq.com")
    
    for domain in "${domains[@]}"; do
        log_info "测试域名解析: $domain"
        
        # 使用dig测试
        if command -v dig &> /dev/null; then
            log_debug "使用dig解析: $domain"
            if dig +short "$domain" A 2>/dev/null | head -5; then
                log_result "DNS解析(dig)" "PASS" "$domain 解析成功"
            else
                log_result "DNS解析(dig)" "FAIL" "$domain 解析失败"
            fi
        fi
        
        # 使用nslookup测试
        if command -v nslookup &> /dev/null; then
            log_debug "使用nslookup解析: $domain"
            if nslookup "$domain" 2>/dev/null | grep -i "address" | head -2; then
                log_result "DNS解析(nslookup)" "PASS" "$domain 解析成功"
            else
                log_result "DNS解析(nslookup)" "FAIL" "$domain 解析失败"
            fi
        fi
        
        echo ""
    done
}

# ICMP Ping测试
test_ping() {
    log_info "开始Ping连通性测试..."
    
    for target in "${PING_TARGETS[@]}"; do
        log_info "测试Ping: $target"
        
        if ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$target" 2>&1 | tee -a "$LOG_FILE"; then
            # 提取统计信息
            local stats=$(ping -c "$PING_COUNT" -W "$PING_TIMEOUT" "$target" 2>/dev/null | tail -2)
            log_result "Ping测试" "PASS" "$target 连通正常"
            echo -e "${CYAN}统计信息:${NC}"
            echo "$stats"
        else
            log_result "Ping测试" "FAIL" "$target 无法连通"
        fi
        
        echo ""
    done
}

# HTTP/HTTPS访问测试
test_http() {
    log_info "开始HTTP/HTTPS访问测试..."
    
    for url in "${HTTP_TARGETS[@]}"; do
        log_info "测试访问: $url"
        
        # 提取域名用于显示
        local domain=$(echo "$url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
        
        # 普通curl测试
        if curl -s -f --max-time "$CURL_TIMEOUT" -I "$url" 2>&1 | head -1 | tee -a "$LOG_FILE"; then
            local status_code=$(curl -s -f --max-time "$CURL_TIMEOUT" -w "%{http_code}" -o /dev/null "$url")
            log_result "HTTP访问" "PASS" "$url 访问成功 (状态码: $status_code)"
            
            # 显示响应头信息
            echo -e "${CYAN}响应头:${NC}"
            curl -s -f --max-time "$CURL_TIMEOUT" -I "$url" 2>&1 | head -10
        else
            log_result "HTTP访问" "FAIL" "$url 访问失败"
            
            # 尝试获取更多错误信息
            local error_output=$(curl -s --max-time "$CURL_TIMEOUT" -w "%{http_code} %{time_total}s" -o /dev/null "$url" 2>&1)
            echo -e "${YELLOW}错误详情: $error_output${NC}"
        fi
        
        echo ""
    done
}

# 详细HTTPS测试
test_https_detailed() {
    log_info "开始详细HTTPS测试..."
    
    local https_targets=("https://www.google.com" "https://github.com")
    
    for url in "${https_targets[@]}"; do
        log_info "详细测试HTTPS: $url"
        
        echo -e "${CYAN}执行: curl -vvvk --max-time $CURL_TIMEOUT $url${NC}"
        
        # 创建临时文件存储输出
        local temp_file=$(mktemp)
        
        # 执行详细curl测试
        if curl -vvvk --max-time "$CURL_TIMEOUT" "$url" 2>&1 | tee "$temp_file" | grep -E "(SSL|Connected|HTTP|expire)" | head -20; then
            log_result "HTTPS详细测试" "PASS" "$url SSL握手成功"
            
            # 提取SSL证书信息
            if grep -q "SSL certificate" "$temp_file"; then
                echo -e "${CYAN}SSL证书信息:${NC}"
                grep -A5 "SSL certificate" "$temp_file"
            fi
            
            # 提取连接信息
            if grep -q "Connected to" "$temp_file"; then
                echo -e "${CYAN}连接信息:${NC}"
                grep -A2 "Connected to" "$temp_file"
            fi
        else
            log_result "HTTPS详细测试" "FAIL" "$url SSL握手失败"
            
            # 显示错误详情
            echo -e "${YELLOW}错误详情:${NC}"
            tail -20 "$temp_file"
        fi
        
        # 清理临时文件
        rm -f "$temp_file"
        echo ""
    done
}

# 路由跟踪测试
test_traceroute() {
    log_info "开始路由跟踪测试..."
    
    local trace_targets=("8.8.8.8" "www.baidu.com")
    
    for target in "${trace_targets[@]}"; do
        log_info "路由跟踪: $target"
        
        # 使用traceroute
        if command -v traceroute &> /dev/null; then
            echo -e "${CYAN}使用traceroute:${NC}"
            if traceroute -n -m 15 -w 1 "$target" 2>&1 | head -20 | tee -a "$LOG_FILE"; then
                log_result "路由跟踪(traceroute)" "PASS" "$target 路由跟踪完成"
            else
                log_result "路由跟踪(traceroute)" "FAIL" "$target 路由跟踪失败"
            fi
        fi
        
        # 使用mtr（更高级）
        if command -v mtr &> /dev/null; then
            echo -e "${CYAN}使用mtr:${NC}"
            if mtr -n -c 10 -r "$target" 2>&1 | tee -a "$LOG_FILE"; then
                log_result "路由跟踪(mtr)" "PASS" "$target 路由质量测试完成"
            else
                log_result "路由跟踪(mtr)" "FAIL" "$target 路由质量测试失败"
            fi
        fi
        
        echo ""
    done
}

# 网络性能测试
test_network_performance() {
    log_info "开始网络性能测试..."
    
    # 测试到指定IP的延迟和丢包率
    local perf_target="10.1.32.61"
    
    if ping -c 10 -i 0.2 -W 1 "$perf_target" 2>&1 | tee -a "$LOG_FILE"; then
        # 提取性能数据
        local stats=$(ping -c 10 -i 0.2 -W 1 "$perf_target" 2>/dev/null | tail -2)
        log_result "网络性能" "PASS" "$perf_target 性能测试完成"
        echo -e "${CYAN}性能统计:${NC}"
        echo "$stats"
        
        # 计算平均延迟
        local avg_ping=$(echo "$stats" | grep -o "min/avg/max/[^ ]*" | cut -d'/' -f4)
        echo -e "${CYAN}平均延迟: ${avg_ping}ms${NC}"
    else
        log_result "网络性能" "FAIL" "$perf_target 性能测试失败"
    fi
    
    echo ""
}

# 端口连通性测试
test_port_connectivity() {
    log_info "开始端口连通性测试..."
    
    # 常见端口测试
    declare -A ports=(
        ["www.baidu.com"]="80 443"
        ["github.com"]="443 22"
        ["8.8.8.8"]="53"
    )
    
    for host in "${!ports[@]}"; do
        for port in ${ports[$host]}; do
            log_info "测试端口: $host:$port"
            
            if timeout 3 bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
                log_result "端口测试" "PASS" "$host:$port 可连接"
            else
                # 尝试使用nc
                if command -v nc &> /dev/null; then
                    if nc -z -w 3 "$host" "$port" 2>/dev/null; then
                        log_result "端口测试" "PASS" "$host:$port 可连接(nc)"
                    else
                        log_result "端口测试" "FAIL" "$host:$port 不可连接"
                    fi
                else
                    log_result "端口测试" "FAIL" "$host:$port 不可连接(无nc)"
                fi
            fi
        done
    done
    
    echo ""
}

# 生成测试报告
generate_report() {
    log_info "生成测试报告..."
    
    local report_file="/tmp/network_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "========================================="
        echo "       网络连通性测试报告"
        echo "========================================="
        echo "生成时间: $(date)"
        echo "主机名: $(hostname)"
        echo "IP地址: $(hostname -I 2>/dev/null || ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)"
        echo "日志文件: $LOG_FILE"
        echo "========================================="
        echo ""
        
        echo "=== 测试摘要 ==="
        echo "1. DNS解析测试: 完成"
        echo "2. Ping连通性测试: 完成"
        echo "3. HTTP/HTTPS访问测试: 完成"
        echo "4. 详细HTTPS测试: 完成"
        echo "5. 路由跟踪测试: 完成"
        echo "6. 网络性能测试: 完成"
        echo "7. 端口连通性测试: 完成"
        echo ""
        
        echo "=== 建议与修复 ==="
        echo "1. 如果Ping测试失败: 检查网络连接、防火墙设置"
        echo "2. 如果DNS解析失败: 检查/etc/resolv.conf配置"
        echo "3. 如果HTTPS访问失败: 检查系统时间、SSL证书、代理设置"
        echo "4. 如果特定网站无法访问: 检查DNS污染、GFW限制、代理配置"
        echo ""
        
        echo "=== 常用诊断命令 ==="
        echo "查看网络接口: ip addr show 或 ifconfig -a"
        echo "查看路由表: ip route show 或 route -n"
        echo "查看DNS配置: cat /etc/resolv.conf"
        echo "测试端口连通性: nc -zv host port"
        echo "跟踪路由: traceroute host 或 mtr host"
        echo "查看连接状态: ss -tunap 或 netstat -tunap"
        echo ""
        
        echo "=== 配置文件位置 ==="
        echo "网络配置: /etc/network/interfaces (Debian/Ubuntu)"
        echo "网络配置: /etc/sysconfig/network-scripts/ (RHEL/CentOS)"
        echo "DNS配置: /etc/resolv.conf"
        echo "主机名解析: /etc/hosts"
        echo "代理配置: ~/.bashrc 或 /etc/environment"
        
    } > "$report_file"
    
    echo -e "${GREEN}测试报告已生成: $report_file${NC}"
    echo ""
    cat "$report_file"
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}"
    echo "========================================="
    echo "    网络连通性测试菜单"
    echo "========================================="
    echo -e "${NC}"
    echo "1. 完整测试 (所有项目)"
    echo "2. DNS解析测试"
    echo "3. Ping连通性测试"
    echo "4. HTTP/HTTPS访问测试"
    echo "5. 详细HTTPS测试 (curl -vvvk)"
    echo "6. 路由跟踪测试"
    echo "7. 网络性能测试"
    echo "8. 端口连通性测试"
    echo "9. 系统信息收集"
    echo "10. 生成测试报告"
    echo "11. 查看日志文件"
    echo "12. 清理临时文件"
    echo "0. 退出"
    echo ""
}

# 清理临时文件
cleanup() {
    log_info "清理临时文件..."
    rm -f /tmp/network_test_*.log 2>/dev/null
    rm -f /tmp/network_report_*.txt 2>/dev/null
    rm -f /tmp/curl_test_*.tmp 2>/dev/null
    log_info "清理完成"
}

# 主函数
main() {
    # 检查参数
    if [ $# -gt 0 ]; then
        case "$1" in
            "ping")
                test_ping
                ;;
            "http")
                test_http
                ;;
            "https")
                test_https_detailed
                ;;
            "dns")
                test_dns
                ;;
            "full")
                print_banner
                check_commands
                get_system_info
                test_dns
                test_ping
                test_http
                test_https_detailed
                test_traceroute
                test_network_performance
                test_port_connectivity
                generate_report
                ;;
            *)
                echo "用法: $0 [ping|http|https|dns|full]"
                echo "不带参数运行进入交互菜单"
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # 交互式菜单
    while true; do
        show_menu
        read -p "请选择操作 [0-12]: " choice
        
        case $choice in
            1)
                print_banner
                check_commands
                get_system_info
                test_dns
                test_ping
                test_http
                test_https_detailed
                test_traceroute
                test_network_performance
                test_port_connectivity
                generate_report
                ;;
            2)
                print_banner
                test_dns
                ;;
            3)
                print_banner
                test_ping
                ;;
            4)
                print_banner
                test_http
                ;;
            5)
                print_banner
                test_https_detailed
                ;;
            6)
                print_banner
                test_traceroute
                ;;
            7)
                print_banner
                test_network_performance
                ;;
            8)
                print_banner
                test_port_connectivity
                ;;
            9)
                print_banner
                get_system_info
                echo -e "${GREEN}系统信息已保存到日志文件: $LOG_FILE${NC}"
                ;;
            10)
                print_banner
                generate_report
                ;;
            11)
                if [ -f "$LOG_FILE" ]; then
                    echo -e "${CYAN}=== 日志文件内容 ===${NC}"
                    tail -50 "$LOG_FILE"
                else
                    log_error "日志文件不存在: $LOG_FILE"
                fi
                ;;
            12)
                cleanup
                ;;
            0)
                echo -e "${GREEN}退出脚本${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 捕获退出信号
trap 'echo -e "\n${YELLOW}脚本被中断${NC}"; exit 1' INT TERM

# 运行主函数
main "$@"

testEOF

#赋权
chmod +x network-test.sh
