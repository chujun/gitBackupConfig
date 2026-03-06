
cat >> network-test.sh << 'testEOF'
###########################脚本开始#########################

#!/bin/bash
# 网络连通性测试脚本（完整修复版）
# 功能：测试 ping 连通性、HTTP/HTTPS 访问、DNS 解析、路由跟踪等
# 新增：结果收集、统计汇总、详细报告功能
# 作者：元宝
# 版本：3.3
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
# 测试结果存储
# ============================
declare -a TEST_RESULTS
declare -A TEST_SUMMARY=(
    ["total"]=0
    ["passed"]=0
    ["failed"]=0
    ["warned"]=0
)

# 默认配置参数
LOG_FILE="/tmp/network_test_$(date +%Y%m%d_%H%M%S).log"
DEFAULT_PING_TARGETS=("10.1.32.61" "8.8.8.8" "1.1.1.1" "114.114.114.114")
PING_TARGETS=("${DEFAULT_PING_TARGETS[@]}")
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
DEFAULT_HTTPS_DETAILED_TARGETS=("https://www.google.com" "https://github.com")
HTTPS_DETAILED_TARGETS=("${DEFAULT_HTTPS_DETAILED_TARGETS[@]}")
DEFAULT_DNS_TARGETS=("www.baidu.com" "www.google.com" "github.com" "www.qq.com")
DNS_TARGETS=("${DEFAULT_DNS_TARGETS[@]}")
declare -A DEFAULT_PORT_TARGETS=(
    ["www.baidu.com"]="80 443"
    ["github.com"]="443 22"
    ["8.8.8.8"]="53"
)
declare -A PORT_TARGETS
for key in "${!DEFAULT_PORT_TARGETS[@]}"; do
    PORT_TARGETS[$key]="${DEFAULT_PORT_TARGETS[$key]}"
done

PING_COUNT=4
PING_TIMEOUT=2
CURL_TIMEOUT=10
TRACEROUTE_HOPS=15
TRACEROUTE_TIMEOUT=1
PERF_TEST_COUNT=10
PERF_TEST_INTERVAL=0.2
CONFIG_FILE="$(dirname "$0")/network_test.conf"

# ============================
# 辅助函数定义
# ============================

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}[INFO]${NC} 加载配置文件: $CONFIG_FILE"
        # 使用source加载配置文件
        source "$CONFIG_FILE" 2>/dev/null || echo -e "${YELLOW}[WARN]${NC} 配置文件加载失败，使用默认配置"
    else
        echo -e "${CYAN}[DEBUG]${NC} 配置文件不存在: $CONFIG_FILE，使用默认配置"
    fi
}

# 加载环境变量
load_env_vars() {
    # 从环境变量加载Ping目标
    if [ -n "$NETWORK_TEST_PING_TARGETS" ]; then
        IFS=',' read -ra PING_TARGETS <<< "$NETWORK_TEST_PING_TARGETS"
        echo -e "${CYAN}[DEBUG]${NC} 从环境变量加载Ping目标: ${PING_TARGETS[*]}"
    fi
    
    # 从环境变量加载HTTP目标
    if [ -n "$NETWORK_TEST_HTTP_TARGETS" ]; then
        IFS=',' read -ra HTTP_TARGETS <<< "$NETWORK_TEST_HTTP_TARGETS"
        echo -e "${CYAN}[DEBUG]${NC} 从环境变量加载HTTP目标: ${HTTP_TARGETS[*]}"
    fi
    
    # 从环境变量加载主测试IP
    if [ -n "$NETWORK_TEST_PRIMARY_IP" ]; then
        # 确保主IP在Ping目标列表中
        if [[ ! " ${PING_TARGETS[@]} " =~ " ${NETWORK_TEST_PRIMARY_IP} " ]]; then
            PING_TARGETS+=("$NETWORK_TEST_PRIMARY_IP")
        fi
        echo -e "${CYAN}[DEBUG]${NC} 从环境变量加载主测试IP: $NETWORK_TEST_PRIMARY_IP"
    fi
}

# 测试结果记录函数
record_test_result() {
    local test_name="$1"
    local target="$2"
    local result="$3"
    local message="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 存储测试结果
    TEST_RESULTS+=("$timestamp|$test_name|$target|$result|$message")
    
    # 更新统计
    TEST_SUMMARY["total"]=$((TEST_SUMMARY["total"] + 1))
    case "$result" in
        "PASS") TEST_SUMMARY["passed"]=$((TEST_SUMMARY["passed"] + 1)) ;;
        "FAIL") TEST_SUMMARY["failed"]=$((TEST_SUMMARY["failed"] + 1)) ;;
        "WARN") TEST_SUMMARY["warned"]=$((TEST_SUMMARY["warned"] + 1)) ;;
    esac
}

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

log_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    local target="$4"
    
    if [ -z "$target" ]; then
        target="N/A"
    fi
    
    # 记录结果
    record_test_result "$test_name" "$target" "$result" "$message"
    
    # 显示结果
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓ ${test_name}: ${message}${NC}" | tee -a "$LOG_FILE"
    elif [ "$result" = "FAIL" ]; then
        echo -e "${RED}✗ ${test_name}: ${message}${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}⚠ ${test_name}: ${message}${NC}" | tee -a "$LOG_FILE"
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
  --create-config [FILE]     创建示例配置文件(默认: network_test.conf.example)
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
  $0 --config /etc/network_test.conf
  $0 --create-config
  $0 --create-config my_config.conf"
    
    # 设置默认测试类型
    TEST_TYPE="full"
    
    # 如果没有参数，使用默认的完整测试
    if [ $# -eq 0 ]; then
        return
    fi
    
    # 如果有参数，但第一个参数不是选项，则视为测试类型
    if [[ $1 != -* ]]; then
        TEST_TYPE="$1"
        return
    fi
    
    # 解析选项
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                echo -e "$help_text"
                exit 0
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -p|--ping)
                IFS=',' read -ra PING_TARGETS <<< "$2"
                echo -e "${GREEN}[INFO]${NC} 命令行参数: 设置Ping目标为 ${PING_TARGETS[*]}"
                shift 2
                ;;
            -w|--http)
                IFS=',' read -ra HTTP_TARGETS <<< "$2"
                echo -e "${GREEN}[INFO]${NC} 命令行参数: 设置HTTP目标为 ${HTTP_TARGETS[*]}"
                shift 2
                ;;
            -i|--ip)
                local primary_ip="$2"
                # 确保主IP在Ping目标列表中
                if [[ ! " ${PING_TARGETS[@]} " =~ " ${primary_ip} " ]]; then
                    PING_TARGETS+=("$primary_ip")
                fi
                echo -e "${GREEN}[INFO]${NC} 命令行参数: 设置主测试IP为 $primary_ip"
                shift 2
                ;;
            --create-config)
                local config_file="$2"
                if [[ -z "$config_file" ]] || [[ "$config_file" == -* ]]; then
                    config_file="network_test.conf.example"
                else
                    shift
                fi
                create_sample_config "$config_file"
                exit 0
                ;;
            --ping-count)
                PING_COUNT="$2"
                echo -e "${GREEN}[INFO]${NC} 命令行参数: 设置Ping包数量为 $PING_COUNT"
                shift 2
                ;;
            --ping-timeout)
                PING_TIMEOUT="$2"
                echo -e "${GREEN}[INFO]${NC} 命令行参数: 设置Ping超时为 $PING_TIMEOUT 秒"
                shift 2
                ;;
            --curl-timeout)
                CURL_TIMEOUT="$2"
                echo -e "${GREEN}[INFO]${NC} 命令行参数: 设置Curl超时为 $CURL_TIMEOUT 秒"
                shift 2
                ;;
            --detailed-targets)
                IFS=',' read -ra HTTPS_DETAILED_TARGETS <<< "$2"
                echo -e "${GREEN}[INFO]${NC} 命令行参数: 设置详细HTTPS目标为 ${HTTPS_DETAILED_TARGETS[*]}"
                shift 2
                ;;
            full|ping|http|https|dns|route|perf|port|info|report)
                TEST_TYPE="$1"
                shift
                ;;
            -*)
                echo -e "${RED}[ERROR]${NC} 未知选项: $1"
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
}

# 创建示例配置文件
create_sample_config() {
    local config_path="$1"
    if [ -z "$config_path" ]; then
        config_path="network_test.conf.example"
    fi
    
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
    
    echo "$config_sample" > "$config_path"
    log_info "示例配置文件已创建: $config_path"
    echo -e "${GREEN}请根据需要修改，然后重命名为: network_test.conf${NC}"
    echo ""
    
    # 显示文件内容
    echo "配置文件内容预览:"
    echo "========================"
    cat "$config_path"
    echo "========================"
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

# 打印横幅
print_banner() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo "    网络连通性测试脚本 v3.3 (完整修复版)"
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

# ============================
# 测试函数定义
# ============================

# DNS解析测试
test_dns() {
    log_info "开始DNS解析测试..."
    
    for domain in "${DNS_TARGETS[@]}"; do
        log_info "测试域名解析: $domain"
        
        # 使用dig测试
        if command -v dig &> /dev/null; then
            echo -e "${CYAN}[DEBUG]${NC} 使用dig解析: $domain"
            if dig +short "$domain" A 2>/dev/null | head -5; then
                log_result "DNS解析(dig)" "PASS" "$domain 解析成功" "$domain"
            else
                log_result "DNS解析(dig)" "FAIL" "$domain 解析失败" "$domain"
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
            log_result "Ping测试" "PASS" "$target 连通正常" "$target"
            echo -e "${CYAN}统计信息:${NC}"
            echo "$stats"
        else
            log_result "Ping测试" "FAIL" "$target 无法连通" "$target"
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
            log_result "HTTP访问" "PASS" "$url 访问成功 (状态码: $status_code)" "$url"
        else
            log_result "HTTP访问" "FAIL" "$url 访问失败" "$url"
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
            log_result "HTTPS详细测试" "PASS" "$url SSL握手成功" "$url"
        else
            log_result "HTTPS详细测试" "FAIL" "$url SSL握手失败" "$url"
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
            log_result "路由跟踪(traceroute)" "PASS" "$trace_target 路由跟踪完成" "$trace_target"
        else
            log_result "路由跟踪(traceroute)" "FAIL" "$trace_target 路由跟踪失败" "$trace_target"
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
        log_result "网络性能" "PASS" "$perf_target 性能测试完成" "$perf_target"
        echo -e "${CYAN}性能统计:${NC}"
        echo "$stats"
    else
        log_result "网络性能" "FAIL" "$perf_target 性能测试失败" "$perf_target"
    fi
    
    echo ""
}

# 端口连通性测试
test_port_connectivity() {
    log_info "开始端口连通性测试..."
    
    # 检查PORT_TARGETS是否为空
    if [ ${#PORT_TARGETS[@]} -eq 0 ]; then
        log_warn "PORT_TARGETS数组为空，跳过端口测试"
        return
    fi
    
    # 使用计数器跟踪有效测试
    local valid_tests=0
    local total_tests=0
    
    for host in "${!PORT_TARGETS[@]}"; do
        # 跳过空主机名
        if [ -z "$host" ] || [ "$host" = "" ]; then
            log_warn "跳过空主机名的端口测试"
            continue
        fi
        
        # 获取端口列表
        local ports_str="${PORT_TARGETS[$host]}"
        
        # 检查端口列表是否为空
        if [ -z "$ports_str" ]; then
            log_warn "主机 '$host' 的端口列表为空，跳过"
            continue
        fi
        
        # 分割端口列表
        local ports
        IFS=' ' read -ra ports <<< "$ports_str"
        
        for port in "${ports[@]}"; do
            # 跳过空端口
            if [ -z "$port" ] || ! [[ "$port" =~ ^[0-9]+$ ]]; then
                log_warn "主机 '$host' 的端口 '$port' 无效，跳过"
                continue
            fi
            
            total_tests=$((total_tests + 1))
            log_info "测试端口: $host:$port"
            
            # 设置超时并测试TCP连接
            if timeout 3 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
                log_result "端口测试" "PASS" "$host:$port 可连接(TCP)" "$host:$port"
                valid_tests=$((valid_tests + 1))
            else
                # 尝试使用nc (netcat)
                if command -v nc &> /dev/null; then
                    if nc -z -w 3 "$host" "$port" 2>/dev/null; then
                        log_result "端口测试" "PASS" "$host:$port 可连接(nc)" "$host:$port"
                        valid_tests=$((valid_tests + 1))
                    else
                        log_result "端口测试" "FAIL" "$host:$port 不可连接" "$host:$port"
                    fi
                else
                    log_result "端口测试" "FAIL" "$host:$port 不可连接(无nc)" "$host:$port"
                fi
            fi
        done
    done
    
    # 输出测试统计
    echo ""
    log_info "端口测试完成: $valid_tests/$total_tests 个测试通过"
    
    if [ $total_tests -eq 0 ]; then
        log_warn "未执行任何有效的端口测试"
        log_info "请检查PORT_TARGETS配置"
    fi
}

# 生成测试结果汇总报告
generate_summary_report() {
    local report_file="/tmp/network_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "================================================"
        echo "           网络连通性测试结果汇总报告"
        echo "================================================"
        echo "生成时间: $(date)"
        echo "测试主机: $(hostname)"
        echo "运行用户: $(whoami)"
        echo "日志文件: $LOG_FILE"
        echo "================================================"
        echo ""
        
        # 总体统计
        local total=${TEST_SUMMARY["total"]}
        local passed=${TEST_SUMMARY["passed"]}
        local failed=${TEST_SUMMARY["failed"]}
        local warned=${TEST_SUMMARY["warned"]}
        local pass_rate=0
        
        if [ $total -gt 0 ]; then
            pass_rate=$((passed * 100 / total))
        fi
        
        echo "=== 总体统计 ==="
        echo "总测试数: $total"
        echo "通过: $passed"
        echo "失败: $failed"
        echo "警告: $warned"
        echo "通过率: ${pass_rate}%"
        echo ""
        
        # 按测试类型分组
        echo "=== 按测试类型统计 ==="
        declare -A test_type_stats
        
        for result_line in "${TEST_RESULTS[@]}"; do
            IFS='|' read -r timestamp test_name target result message <<< "$result_line"
            if [ -z "${test_type_stats[$test_name]}" ]; then
                test_type_stats[$test_name]="0 0 0"  # passed failed warned
            fi
            
            IFS=' ' read -r p f w <<< "${test_type_stats[$test_name]}"
            case "$result" in
                "PASS") p=$((p + 1)) ;;
                "FAIL") f=$((f + 1)) ;;
                "WARN") w=$((w + 1)) ;;
            esac
            test_type_stats[$test_name]="$p $f $w"
        done
        
        for test_type in "${!test_type_stats[@]}"; do
            IFS=' ' read -r p f w <<< "${test_type_stats[$test_type]}"
            local total_type=$((p + f + w))
            if [ $total_type -gt 0 ]; then
                local rate=$((p * 100 / total_type))
                echo "  $test_type: 总计 $total_type, 通过 $p, 失败 $f, 警告 $w, 通过率 ${rate}%"
            fi
        done
        echo ""
        
        # 失败和警告详情
        if [ $failed -gt 0 ] || [ $warned -gt 0 ]; then
            echo "=== 需要关注的项目 ==="
            
            for result_line in "${TEST_RESULTS[@]}"; do
                IFS='|' read -r timestamp test_name target result message <<< "$result_line"
                if [ "$result" = "FAIL" ] || [ "$result" = "WARN" ]; then
                    echo "  [$result] $test_name - $target: $message"
                fi
            done
            echo ""
        fi
        
        # 详细结果列表
        echo "=== 详细测试结果 ==="
        echo "时间 | 测试类型 | 测试目标 | 结果 | 详细信息"
        echo "------------------------------------------------"
        
        for result_line in "${TEST_RESULTS[@]}"; do
            IFS='|' read -r timestamp test_name target result message <<< "$result_line"
            
            # 简化和美化显示
            local display_target="$target"
            if [ ${#display_target} -gt 30 ]; then
                display_target="${display_target:0:27}..."
            fi
            
            local display_message="$message"
            if [ ${#display_message} -gt 40 ]; then
                display_message="${display_message:0:37}..."
            fi
            
            # 根据结果添加颜色标记
            local result_color=""
            case "$result" in
                "PASS") result_color="✓" ;;
                "FAIL") result_color="✗" ;;
                "WARN") result_color="⚠" ;;
            esac
            
            printf "%-19s | %-20s | %-30s | %-6s | %-40s\n" \
                "$timestamp" "$test_name" "$display_target" "$result_color" "$display_message"
        done
        echo ""
        
        # 建议和下一步
        echo "=== 建议与后续步骤 ==="
        if [ $failed -eq 0 ] && [ $warned -eq 0 ]; then
            echo "✅ 所有测试通过，网络状态良好。"
        elif [ $failed -gt 0 ]; then
            echo "❌ 发现失败的测试项，需要排查："
            echo "   1. 检查网络连接和防火墙设置"
            echo "   2. 验证DNS解析是否正常"
            echo "   3. 检查目标服务是否可用"
            echo "   4. 查看详细日志: $LOG_FILE"
        else
            echo "⚠️ 有警告项目，建议检查："
            echo "   1. 查看警告详情"
            echo "   2. 确认是否影响正常使用"
        fi
        
        echo ""
        echo "=== 快速诊断命令 ==="
        echo "# 检查网络接口"
        echo "ip addr show"
        echo ""
        echo "# 检查路由表"
        echo "ip route show"
        echo ""
        echo "# 测试到特定主机的连通性"
        echo "ping -c 4 8.8.8.8"
        echo ""
        echo "# 测试DNS解析"
        echo "dig +short www.baidu.com"
        
    } > "$report_file"
    
    # 同时在控制台显示精简报告
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}             测试结果汇总${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo "总测试数: ${TEST_SUMMARY["total"]}"
    echo -e "通过: ${GREEN}${TEST_SUMMARY["passed"]}${NC}"
    echo -e "失败: ${RED}${TEST_SUMMARY["failed"]}${NC}"
    echo -e "警告: ${YELLOW}${TEST_SUMMARY["warned"]}${NC}"
    
    if [ ${TEST_SUMMARY["total"]} -gt 0 ]; then
        local pass_rate=$((TEST_SUMMARY["passed"] * 100 / TEST_SUMMARY["total"]))
        echo -e "通过率: ${BLUE}${pass_rate}%${NC}"
    fi
    
    if [ ${TEST_SUMMARY["failed"]} -gt 0 ]; then
        echo ""
        echo -e "${RED}=== 失败项目 ===${NC}"
        for result_line in "${TEST_RESULTS[@]}"; do
            IFS='|' read -r timestamp test_name target result message <<< "$result_line"
            if [ "$result" = "FAIL" ]; then
                echo -e "${RED}✗ ${test_name} - ${target}: ${message}${NC}"
            fi
        done
    fi
    
    if [ ${TEST_SUMMARY["warned"]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}=== 警告项目 ===${NC}"
        for result_line in "${TEST_RESULTS[@]}"; do
            IFS='|' read -r timestamp test_name target result message <<< "$result_line"
            if [ "$result" = "WARN" ]; then
                echo -e "${YELLOW}⚠ ${test_name} - ${target}: ${message}${NC}"
            fi
        done
    fi
    
    echo ""
    echo -e "${GREEN}详细报告已保存至: $report_file${NC}"
    echo -e "${GREEN}日志文件: $LOG_FILE${NC}"
    
    # 返回总体状态码
    if [ ${TEST_SUMMARY["failed"]} -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# 清理临时文件
cleanup() {
    log_info "清理临时文件..."
    rm -f /tmp/network_test_*.log 2>/dev/null
    rm -f /tmp/network_report_*.txt 2>/dev/null
    rm -f /tmp/network_summary_*.txt 2>/dev/null
    rm -f /tmp/curl_test_*.tmp 2>/dev/null
    log_info "清理完成"
}

# 主测试函数
run_tests() {
    local test_type="$1"
    
    # 清空之前的结果
    TEST_RESULTS=()
    TEST_SUMMARY["total"]=0
    TEST_SUMMARY["passed"]=0
    TEST_SUMMARY["failed"]=0
    TEST_SUMMARY["warned"]=0
    
    # 加载配置
    load_config
    load_env_vars
    
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
            generate_summary_report
            ;;
        "ping")
            print_banner
            test_ping
            generate_summary_report
            ;;
        "http")
            print_banner
            test_http
            generate_summary_report
            ;;
        "https")
            print_banner
            test_https_detailed
            generate_summary_report
            ;;
        "dns")
            print_banner
            test_dns
            generate_summary_report
            ;;
        "route")
            print_banner
            test_traceroute
            generate_summary_report
            ;;
        "perf")
            print_banner
            test_network_performance
            generate_summary_report
            ;;
        "port")
            print_banner
            test_port_connectivity
            generate_summary_report
            ;;
        "info")
            print_banner
            get_system_info
            echo -e "${GREEN}系统信息已保存到日志文件: $LOG_FILE${NC}"
            ;;
        "report")
            print_banner
            generate_summary_report
            ;;
        *)
            # 默认运行完整测试
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
            generate_summary_report
            ;;
    esac
    
    return $?
}

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 捕获退出信号
    trap 'echo -e "\n${YELLOW}脚本被中断${NC}"; cleanup; exit 1' INT TERM
    
    # 运行测试
    run_tests "$TEST_TYPE"
    local test_status=$?
    
    # 清理
    cleanup
    
    exit $test_status
}

# 运行主函数
main "$@"

###########################脚本结束#########################
testEOF

#赋权
chmod +x network-test.sh
