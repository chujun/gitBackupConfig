
cat >> network-test.sh << 'testEOF'
###########################脚本开始#########################
#!/bin/bash
# 网络连通性测试脚本（参数化优化版）
# 功能：测试 ping 连通性、HTTP/HTTPS 访问、DNS 解析、路由跟踪等
# 支持：命令行参数、配置文件、环境变量三种配置方式
# 作者：元宝
# 版本：3.0
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

# ============================
# 默认配置参数
# 优先级：命令行参数 > 配置文件 > 环境变量 > 默认值
# ============================

# 日志文件
LOG_FILE="/tmp/network_test_$(date +%Y%m%d_%H%M%S).log"

# 默认Ping目标（可从环境变量覆盖）
DEFAULT_PING_TARGETS=("10.1.32.61" "8.8.8.8" "1.1.1.1" "114.114.114.114")
PING_TARGETS=("${DEFAULT_PING_TARGETS[@]}")

# 默认HTTP目标
DEFAULT_HTTP_TARGETS=(
    "http://www.baidu.com"
    "http://www.google.com"
    "https://www.google.com"
    "https://github.com"
    "https://www.qq.com"
    "https://www.taobao.com"
    "https://mirrors.aliyun.com"
)
HTTP_TARGETS=("${DEFAULT_HTTP_TARGETS[@]}")

# 默认详细HTTPS目标
DEFAULT_HTTPS_DETAILED_TARGETS=("https://www.google.com" "https://github.com")
HTTPS_DETAILED_TARGETS=("${DEFAULT_HTTPS_DETAILED_TARGETS[@]}")

# 默认DNS测试域名
DEFAULT_DNS_TARGETS=("www.baidu.com" "www.google.com" "github.com" "www.qq.com")
DNS_TARGETS=("${DEFAULT_DNS_TARGETS[@]}")

# 默认端口测试目标
declare -A DEFAULT_PORT_TARGETS=(
    ["www.baidu.com"]="80 443"
    ["github.com"]="443 22"
    ["8.8.8.8"]="53"
)
declare -A PORT_TARGETS
for key in "${!DEFAULT_PORT_TARGETS[@]}"; do
    PORT_TARGETS[$key]="${DEFAULT_PORT_TARGETS[$key]}"
done

# 测试参数
PING_COUNT=4
PING_TIMEOUT=2
CURL_TIMEOUT=10
TRACEROUTE_HOPS=15
TRACEROUTE_TIMEOUT=1
PERF_TEST_COUNT=10
PERF_TEST_INTERVAL=0.2

# 配置文件路径
CONFIG_FILE="$(dirname "$0")/network_test.conf"

# ============================
# 函数定义
# ============================

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

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_info "加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_debug "配置文件不存在: $CONFIG_FILE，使用默认配置"
    fi
}

# 加载环境变量
load_env_vars() {
    # 从环境变量加载Ping目标
    if [ -n "$NETWORK_TEST_PING_TARGETS" ]; then
        IFS=',' read -ra PING_TARGETS <<< "$NETWORK_TEST_PING_TARGETS"
        log_debug "从环境变量加载Ping目标: ${PING_TARGETS[*]}"
    fi
    
    # 从环境变量加载HTTP目标
    if [ -n "$NETWORK_TEST_HTTP_TARGETS" ]; then
        IFS=',' read -ra HTTP_TARGETS <<< "$NETWORK_TEST_HTTP_TARGETS"
        log_debug "从环境变量加载HTTP目标: ${HTTP_TARGETS[*]}"
    fi
    
    # 从环境变量加载主测试IP
    if [ -n "$NETWORK_TEST_PRIMARY_IP" ]; then
        # 确保主IP在Ping目标列表中
        if [[ ! " ${PING_TARGETS[@]} " =~ " ${NETWORK_TEST_PRIMARY_IP} " ]]; then
            PING_TARGETS+=("$NETWORK_TEST_PRIMARY_IP")
        fi
        log_debug "从环境变量加载主测试IP: $NETWORK_TEST_PRIMARY_IP"
    fi
}

# 解析命令行参数
parse_args() {
    local help_text="用法: $0 [选项] [测试类型]
    
选项:
  -h, --help                   显示此帮助信息
  -c, --config FILE           指定配置文件路径
  -l, --log FILE             指定日志文件路径
  -p, --ping IP1,IP2,...     指定Ping测试目标(逗号分隔)
  -w, --http URL1,URL2,...   指定HTTP测试目标(逗号分隔)
  -i, --ip IP                 指定主测试IP地址
  --ping-count NUM           Ping包数量(默认: $PING_COUNT)
  --ping-timeout SEC         Ping超时时间(默认: $PING_TIMEOUT)
  --curl-timeout SEC         Curl超时时间(默认: $CURL_TIMEOUT)
  --detailed-targets URL1,URL2 详细HTTPS测试目标
  
测试类型:
  full        完整测试(所有项目)
  ping        仅Ping测试
  http        仅HTTP/HTTPS测试
  https       详细HTTPS测试
  dns         DNS解析测试
  route       路由跟踪测试
  perf        网络性能测试
  port        端口连通性测试
  info        系统信息收集
  report      生成测试报告
  
示例:
  $0 -i 10.1.32.61 ping
  $0 -p 8.8.8.8,1.1.1.1,10.1.32.61 -w https://google.com,https://github.com full
  $0 --config /etc/network_test.conf"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                echo -e "$help_text"
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                load_config
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -p|--ping)
                IFS=',' read -ra PING_TARGETS <<< "$2"
                log_info "命令行参数: 设置Ping目标为 ${PING_TARGETS[*]}"
                shift 2
                ;;
            -w|--http)
                IFS=',' read -ra HTTP_TARGETS <<< "$2"
                log_info "命令行参数: 设置HTTP目标为 ${HTTP_TARGETS[*]}"
                shift 2
                ;;
            -i|--ip)
                local primary_ip="$2"
                # 确保主IP在Ping目标列表中
                if [[ ! " ${PING_TARGETS[@]} " =~ " ${primary_ip} " ]]; then
                    PING_TARGETS+=("$primary_ip")
                fi
                log_info "命令行参数: 设置主测试IP为 $primary_ip"
                shift 2
                ;;
            --ping-count)
                PING_COUNT="$2"
                log_info "命令行参数: 设置Ping包数量为 $PING_COUNT"
                shift 2
                ;;
            --ping-timeout)
                PING_TIMEOUT="$2"
                log_info "命令行参数: 设置Ping超时为 $PING_TIMEOUT 秒"
                shift 2
                ;;
            --curl-timeout)
                CURL_TIMEOUT="$2"
                log_info "命令行参数: 设置Curl超时为 $CURL_TIMEOUT 秒"
                shift 2
                ;;
            --detailed-targets)
                IFS=',' read -ra HTTPS_DETAILED_TARGETS <<< "$2"
                log_info "命令行参数: 设置详细HTTPS目标为 ${HTTPS_DETAILED_TARGETS[*]}"
                shift 2
                ;;
            -*)
                log_error "未知选项: $1"
                echo -e "$help_text"
                exit 1
                ;;
            *)
                # 剩下的参数是测试类型
                TEST_TYPE="$1"
                shift
                ;;
        esac
    done
    
    # 如果没有指定测试类型，则使用交互模式
    if [ -z "$TEST_TYPE" ]; then
        TEST_TYPE="interactive"
    fi
}

# 显示当前配置
show_config() {
    echo -e "${BLUE}当前测试配置:${NC}"
    echo "=============================="
    echo "Ping目标: ${PING_TARGETS[*]}"
    echo "HTTP目标: ${HTTP_TARGETS[*]}"
    echo "详细HTTPS目标: ${HTTPS_DETAILED_TARGETS[*]}"
    echo "DNS测试域名: ${DNS_TARGETS[*]}"
    echo "端口测试目标: ${#PORT_TARGETS[@]} 个"
    echo "Ping参数: 包数=$PING_COUNT, 超时=${PING_TIMEOUT}s"
    echo "Curl超时: ${CURL_TIMEOUT}s"
    echo "日志文件: $LOG_FILE"
    echo "配置文件: $CONFIG_FILE"
    echo "=============================="
    echo ""
}

# 创建示例配置文件
create_sample_config() {
    local config_sample=$(cat << 'EOF'
# 网络测试脚本配置文件
# 注释以#开头，每行一个配置

# Ping测试目标(多个目标用空格分隔)
PING_TARGETS=("10.1.32.61" "8.8.8.8" "1.1.1.1" "114.114.114.114")

# HTTP/HTTPS测试目标
HTTP_TARGETS=(
    "http://www.baidu.com"
    "http://www.google.com"
    "https://www.google.com"
    "https://github.com"
    "https://www.qq.com"
    "https://mirrors.aliyun.com"
)

# 详细HTTPS测试目标
HTTPS_DETAILED_TARGETS=("https://www.google.com" "https://github.com")

# DNS测试域名
DNS_TARGETS=("www.baidu.com" "www.google.com" "github.com" "www.qq.com")

# 端口测试目标(主机:端口列表)
# 注意: 数组格式，键是主机，值是端口列表
declare -A PORT_TARGETS=(
    ["www.baidu.com"]="80 443"
    ["github.com"]="443 22"
    ["8.8.8.8"]="53"
)

# 测试参数
PING_COUNT=4
PING_TIMEOUT=2
CURL_TIMEOUT=10
TRACEROUTE_HOPS=15
TRACEROUTE_TIMEOUT=1
PERF_TEST_COUNT=10
PERF_TEST_INTERVAL=0.2
EOF
    )
    
    echo "$config_sample" > "$CONFIG_FILE.example"
    log_info "示例配置文件已创建: $CONFIG_FILE.example"
    echo "请根据需要修改，然后重命名为: network_test.conf"
}

# 打印横幅
print_banner() {
    clear
    echo -e "${BLUE}"
    echo "==============================================="
    echo "    网络连通性测试脚本 v3.0 (参数化版)"
    echo "==============================================="
    echo -e "${NC}"
    echo "开始时间: $(date)"
    echo "日志文件: $LOG_FILE"
    echo ""
    show_config
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
}

# DNS解析测试
test_dns() {
    log_info "开始DNS解析测试..."
    
    for domain in "${DNS_TARGETS[@]}"; do
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
        else
            log_result "HTTP访问" "FAIL" "$url 访问失败"
        fi
        
        echo ""
    done
}

# 详细HTTPS测试
test_https_detailed() {
    log_info "开始详细HTTPS测试..."
    
    for url in "${HTTPS_DETAILED_TARGETS[@]}"; do
        log_info "详细测试HTTPS: $url"
        
        echo -e "${CYAN}执行: curl -vvvk --max-time $CURL_TIMEOUT $url${NC}"
        
        # 创建临时文件存储输出
        local temp_file=$(mktemp)
        
        # 执行详细curl测试
        if curl -vvvk --max-time "$CURL_TIMEOUT" "$url" 2>&1 | tee "$temp_file" | grep -E "(SSL|Connected|HTTP)" | head -10; then
            log_result "HTTPS详细测试" "PASS" "$url SSL握手成功"
        else
            log_result "HTTPS详细测试" "FAIL" "$url SSL握手失败"
        fi
        
        # 清理临时文件
        rm -f "$temp_file"
        echo ""
    done
}

# 路由跟踪测试
test_traceroute() {
    log_info "开始路由跟踪测试..."
    
    # 使用第一个Ping目标进行路由跟踪
    local trace_target="${PING_TARGETS[0]}"
    
    if [ -z "$trace_target" ]; then
        trace_target="8.8.8.8"
    fi
    
    log_info "路由跟踪: $trace_target"
    
    # 使用traceroute
    if command -v traceroute &> /dev/null; then
        echo -e "${CYAN}使用traceroute:${NC}"
        if traceroute -n -m "$TRACEROUTE_HOPS" -w "$TRACEROUTE_TIMEOUT" "$trace_target" 2>&1 | head -20 | tee -a "$LOG_FILE"; then
            log_result "路由跟踪(traceroute)" "PASS" "$trace_target 路由跟踪完成"
        else
            log_result "路由跟踪(traceroute)" "FAIL" "$trace_target 路由跟踪失败"
        fi
    fi
    
    echo ""
}

# 网络性能测试
test_network_performance() {
    log_info "开始网络性能测试..."
    
    # 测试第一个Ping目标的性能
    local perf_target="${PING_TARGETS[0]}"
    
    if [ -z "$perf_target" ]; then
        perf_target="8.8.8.8"
    fi
    
    if ping -c "$PERF_TEST_COUNT" -i "$PERF_TEST_INTERVAL" -W 1 "$perf_target" 2>&1 | tee -a "$LOG_FILE"; then
        # 提取性能数据
        local stats=$(ping -c "$PERF_TEST_COUNT" -i "$PERF_TEST_INTERVAL" -W 1 "$perf_target" 2>/dev/null | tail -2)
        log_result "网络性能" "PASS" "$perf_target 性能测试完成"
        echo -e "${CYAN}性能统计:${NC}"
        echo "$stats"
    else
        log_result "网络性能" "FAIL" "$perf_target 性能测试失败"
    fi
    
    echo ""
}

# 端口连通性测试
test_port_connectivity() {
    log_info "开始端口连通性测试..."
    
    for host in "${!PORT_TARGETS[@]}"; do
        for port in ${PORT_TARGETS[$host]}; do
            log_info "测试端口: $host:$port"
            
            if timeout 3 bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
                log_result "端口测试" "PASS" "$host:$port 可连接"
            else
                log_result "端口测试" "FAIL" "$host:$port 不可连接"
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
        echo "测试配置:"
        echo "  Ping目标: ${PING_TARGETS[*]}"
        echo "  HTTP目标: ${#HTTP_TARGETS[@]} 个"
        echo "日志文件: $LOG_FILE"
        echo "========================================="
        
    } > "$report_file"
    
    echo -e "${GREEN}测试报告已生成: $report_file${NC}"
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
    echo "11. 查看当前配置"
    echo "12. 创建示例配置文件"
    echo "13. 查看日志文件"
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

# 主测试函数
run_tests() {
    local test_type="$1"
    
    case "$test_type" in
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
        "ping")
            print_banner
            test_ping
            ;;
        "http")
            print_banner
            test_http
            ;;
        "https")
            print_banner
            test_https_detailed
            ;;
        "dns")
            print_banner
            test_dns
            ;;
        "route")
            print_banner
            test_traceroute
            ;;
        "perf")
            print_banner
            test_network_performance
            ;;
        "port")
            print_banner
            test_port_connectivity
            ;;
        "info")
            print_banner
            get_system_info
            echo -e "${GREEN}系统信息已保存到日志文件: $LOG_FILE${NC}"
            ;;
        "report")
            print_banner
            generate_report
            ;;
        "interactive")
            # 交互式菜单
            while true; do
                show_menu
                read -p "请选择操作 [0-13]: " choice
                
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
                        show_config
                        ;;
                    12)
                        create_sample_config
                        ;;
                    13)
                        if [ -f "$LOG_FILE" ]; then
                            echo -e "${CYAN}=== 日志文件内容 ===${NC}"
                            tail -50 "$LOG_FILE"
                        else
                            log_error "日志文件不存在: $LOG_FILE"
                        fi
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
            ;;
        *)
            log_error "未知的测试类型: $test_type"
            echo "可用测试类型: full, ping, http, https, dns, route, perf, port, info, report"
            exit 1
            ;;
    esac
}

# 主函数
main() {
    # 加载配置
    load_config
    load_env_vars
    
    # 解析命令行参数
    parse_args "$@"
    
    # 捕获退出信号
    trap 'echo -e "\n${YELLOW}脚本被中断${NC}"; exit 1' INT TERM
    
    # 运行测试
    run_tests "$TEST_TYPE"
}

# 运行主函数
main "$@"
###########################脚本结束#########################
testEOF

#赋权
chmod +x network-test.sh
