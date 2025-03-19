#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =========== Docker网络配置 ===========

# 创建专用网络
create_docker_network() {
    local NETWORK_NAME="cryptosystem_network"
    
    echo -e "${YELLOW}正在创建Docker网络: ${NETWORK_NAME}${NC}"
    
    # 检查网络是否已存在
    if docker network ls | grep -q "${NETWORK_NAME}"; then
        echo -e "${GREEN}✓ 网络 ${NETWORK_NAME} 已存在${NC}"
        return 0
    fi
    
    # 创建网络
    if docker network create --driver bridge "${NETWORK_NAME}"; then
        echo -e "${GREEN}✓ 成功创建网络 ${NETWORK_NAME}${NC}"
    else
        echo -e "${RED}✗ 创建网络 ${NETWORK_NAME} 失败${NC}"
        return 1
    fi
}

# Docker网络诊断
diagnose_docker_network() {
    echo -e "${YELLOW}开始Docker网络诊断...${NC}"
    
    # 检查Docker是否运行
    if ! docker info &>/dev/null; then
        echo -e "${RED}✗ Docker未运行或无法访问${NC}"
        return 1
    fi
    
    # 详细网络连接性检查
    echo -e "${YELLOW}检查网络连接性:${NC}"
    local connection_test=$(docker run --rm alpine sh -c "
        echo '尝试解析域名...';
        nslookup github.com || nslookup google.com || nslookup baidu.com;
        
        echo '尝试访问网站...';
        # 只获取HTTP状态码而不是整个页面内容
        wget --spider --timeout=10 https://www.github.com && echo '✓ GitHub可访问' || 
        wget --spider --timeout=10 https://www.google.com && echo '✓ Google可访问' || 
        wget --spider --timeout=10 https://www.baidu.com && echo '✓ Baidu可访问' || 
        echo '✗ 所有测试网站均不可访问';
        
        echo '网络检查完成'
    " 2>&1)
    
    echo "$connection_test"
    
    # 分析测试结果
    if echo "$connection_test" | grep -q "Network is unreachable"; then
        echo -e "${RED}✗ 网络不可达${NC}"
        return 1
    fi
    
    if echo "$connection_test" | grep -q "connection refused"; then
        echo -e "${RED}✗ 连接被拒绝${NC}"
        return 1
    fi
    
    if ! echo "$connection_test" | grep -q "网络检查完成"; then
        echo -e "${RED}✗ 网络检查未完成${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Docker容器网络连接正常${NC}"
    return 0
}

# =========== pip 包管理器配置 ===========

# 检查pip包管理器源可用性
test_pip_sources() {
    echo -e "${BLUE}开始配置pip包管理器...${NC}"
    
    # 定义pip源列表
    local PIP_SOURCES=(
        "https://pypi.org/simple"
        "https://pypi.tuna.tsinghua.edu.cn/simple"
        "https://mirrors.aliyun.com/pypi/simple/"
        "https://mirrors.cloud.tencent.com/pypi/simple"
    )
    
    local fastest_source=""
    local fastest_time=9999
    
    for source in "${PIP_SOURCES[@]}"; do
        echo -e "${BLUE}测试pip源: ${source}${NC}"
        local start_time=$(date +%s)
        
        # 测试连接，增加超时到10秒
        timeout 10 pip install --index-url "$source" --quiet --dry-run pip 2>/dev/null
        if [ $? -eq 0 ]; then
            local end_time=$(date +%s)
            local current_time=$((end_time - start_time))
            echo -e "${GREEN}✓ 源 ${source} 可用 (${current_time}秒)${NC}"
            
            # 更新最快源
            if [[ $current_time -lt $fastest_time ]]; then
                fastest_time=$current_time
                fastest_source=$source
            fi
        else
            echo -e "${RED}✗ 源 ${source} 不可用${NC}"
        fi
    done
    
    # 设置最快源
    if [[ -n $fastest_source ]]; then
        echo -e "${GREEN}配置最快的pip源: ${fastest_source} (${fastest_time}秒)${NC}"
        # 显示将写入的配置文件路径
        PIP_CONFIG_FILE="$HOME/.pip/pip.conf"
        if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
            PIP_CONFIG_DIR=$(pip config list -v | grep "pip.locations.global.config" | cut -d "=" -f2 | tr -d "'" | xargs dirname 2>/dev/null)
            if [[ -n "$PIP_CONFIG_DIR" ]]; then
                PIP_CONFIG_FILE="$PIP_CONFIG_DIR/pip.ini"
            else
                PIP_CONFIG_FILE="$APPDATA/pip/pip.ini"
            fi
        fi
        # echo "配置将写入: $PIP_CONFIG_FILE"
        pip config set global.index-url "$fastest_source"
        echo -e "${GREEN}pip源配置完成!${NC}"
        return 0
    else
        echo -e "${RED}✗ 没有找到可用的pip源${NC}"
        return 1
    fi
}

# =========== npm 包管理器配置 ===========

# 检查npm包管理器源可用性
test_npm_sources() {
    # 检查是否安装了npm
    if ! command -v npm &>/dev/null; then
        echo -e "${YELLOW}npm未安装，跳过npm源测试${NC}"
        return 1
    fi
    
    echo -e "${BLUE}开始配置npm包管理器...${NC}"
    
    # 定义npm源列表
    local NPM_SOURCES=(
        "https://registry.npmjs.org"
        "https://registry.npmmirror.com"
        "https://registry.cnpmjs.org"
    )
    
    local fastest_source=""
    local fastest_time=9999
    
    for source in "${NPM_SOURCES[@]}"; do
        echo -e "${BLUE}测试npm源: ${source}${NC}"
        local start_time=$(date +%s)
        
        # 测试连接，增加超时到10秒
        npm ping --registry=$source --fetch-retries=0 --fetch-timeout=10000 --silent >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            local end_time=$(date +%s)
            local current_time=$((end_time - start_time))
            echo -e "${GREEN}✓ 源 ${source} 可用 (${current_time}秒)${NC}"
            
            # 更新最快源
            if [[ $current_time -lt $fastest_time ]]; then
                fastest_time=$current_time
                fastest_source=$source
            fi
        else
            echo -e "${RED}✗ 源 ${source} 不可用${NC}"
        fi
    done
    
    # 设置最快源
    if [[ -n $fastest_source ]]; then
        echo -e "${GREEN}配置最快的npm源: ${fastest_source} (${fastest_time}秒)${NC}"
        npm config set registry "$fastest_source"
        echo -e "${GREEN}npm源配置完成!${NC}"
        return 0
    else
        echo -e "${RED}✗ 没有找到可用的npm源${NC}"
        return 1
    fi
}

# =========== 诊断工具与汇总报告 ===========

# 生成网络诊断报告
generate_report() {
    echo -e "${YELLOW}========== 网络环境诊断报告 ==========${NC}"
    
    # 检查公共DNS服务器连通性
    echo -e "${BLUE}DNS服务器连通性:${NC}"
    ping -c 1 8.8.8.8 &>/dev/null && echo -e "${GREEN}✓ Google DNS (8.8.8.8) 可访问${NC}" || echo -e "${RED}✗ Google DNS (8.8.8.8) 不可访问${NC}"
    ping -c 1 114.114.114.114 &>/dev/null && echo -e "${GREEN}✓ 114 DNS (114.114.114.114) 可访问${NC}" || echo -e "${RED}✗ 114 DNS (114.114.114.114) 不可访问${NC}"
    
    # 检查常用网站连通性
    echo -e "${BLUE}网站连通性:${NC}"
    curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 https://www.google.com 2>/dev/null | grep -q "200\|301\|302" && echo -e "${GREEN}✓ Google 可访问${NC}" || echo -e "${RED}✗ Google 不可访问${NC}"
    curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 https://github.com 2>/dev/null | grep -q "200\|301\|302" && echo -e "${GREEN}✓ GitHub 可访问${NC}" || echo -e "${RED}✗ GitHub 不可访问${NC}"
    curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 https://www.baidu.com 2>/dev/null | grep -q "200\|301\|302" && echo -e "${GREEN}✓ Baidu 可访问${NC}" || echo -e "${RED}✗ Baidu 不可访问${NC}"
    
    # 显示当前网络配置 - 兼容不同操作系统
    echo -e "${BLUE}当前网络配置:${NC}"
    echo -ne "IP地址: "
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        ipconfig | grep "IPv4" | head -1 | cut -d ":" -f 2 || echo "无法获取"
    else 
        hostname -I 2>/dev/null || ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' || echo "无法获取"
    fi
    
    echo -ne "默认网关: "
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        ipconfig | grep "默认网关" | head -1 | cut -d ":" -f 2 || echo "无法获取"
    else
        ip route | grep default | awk '{print $3}' 2>/dev/null || echo "无法获取"
    fi
    
    # 显示当前配置的包管理器源
    echo -e "${BLUE}包管理器源配置:${NC}"
    echo -e "pip源: $(pip config list | grep 'index-url' || echo 'pip源未配置')"
    echo -e "npm源: $(npm config get registry 2>/dev/null || echo 'npm源未配置')"
    
    echo -e "${YELLOW}========== 报告结束 ==========${NC}"
}

# =========== 主函数 ===========

main() {
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}  CryptoSystem环境配置工具  ${NC}"
    echo -e "${YELLOW}============================================${NC}"
    
    # 安装依赖工具
    echo -e "${YELLOW}检查必要工具...${NC}"
    which bc &>/dev/null || { echo -e "${YELLOW}安装bc计算工具...${NC}"; apt-get update &>/dev/null && apt-get install -y bc &>/dev/null || yum install -y bc &>/dev/null; }
    
    # 配置Docker网络
    create_docker_network || {
        echo -e "${RED}网络创建失败，请检查Docker环境${NC}"
        # 继续执行，不退出
    }
    
    diagnose_docker_network || {
        echo -e "${RED}Docker网络诊断未通过${NC}"
        # 继续执行，不退出
    }
    
    # 配置pip
    test_pip_sources
    local pip_status=$?
    
    # 配置npm
    test_npm_sources
    local npm_status=$?
    
    # 生成诊断报告
    generate_report
    
    # 最终结果汇总
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}  配置结果汇总  ${NC}"
    echo -e "${YELLOW}============================================${NC}"
    
    [ $pip_status -eq 0 ] && echo -e "${GREEN}✓ pip配置成功${NC}" || echo -e "${RED}✗ pip配置失败${NC}"
    [ $npm_status -eq 0 ] && echo -e "${GREEN}✓ npm配置成功${NC}" || echo -e "${RED}✗ npm配置失败${NC}"
    
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${GREEN}配置已完成！请根据上述报告检查环境状态。${NC}"
    echo -e "${YELLOW}============================================${NC}"
}

# 执行主函数
main
