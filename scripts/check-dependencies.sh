#!/bin/bash

# 加密货币网格交易系统 - 依赖检查脚本
# 功能：检查系统环境和必要依赖的版本

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# 导入通用变量和函数
if [ -z "$GREEN" ]; then
    # 如果变量未定义，设置默认颜色
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
fi

# 显示标题
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   加密货币网格交易系统 - 依赖检查工具     ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 切换到项目根目录
cd "$PARENT_DIR" || { echo -e "${RED}无法切换到项目目录${NC}"; exit 1; }

# 定义需要的最低版本
NODE_MIN_VERSION="14.0.0"
NPM_MIN_VERSION="6.0.0"
PYTHON_MIN_VERSION="3.8.0"
DOCKER_MIN_VERSION="20.10.0"

# 版本比较函数
version_gt() { 
    test "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" != "$1"
}

# 添加调试信息函数
debug_log() {
    echo -e "${BLUE}[DEBUG] $1${NC}"
}

# 检查基础环境
echo -e "${CYAN}检查基础环境...${NC}"
debug_log "开始检查基础环境"

# 检查操作系统
echo -e "${YELLOW}操作系统:${NC} $(uname -s) $(uname -r)"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    echo -e "${YELLOW}Windows环境:${NC} 通过Git Bash或WSL运行"
    echo -e "${YELLOW}Windows版本:${NC} $(cmd.exe /c ver 2>/dev/null || echo '无法获取Windows版本')"
fi
debug_log "完成操作系统检查"

# 检查Node.js
echo -e "\n${CYAN}检查Node.js环境...${NC}"
debug_log "开始检查Node.js环境"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2)
    echo -e "${YELLOW}Node.js版本:${NC} $NODE_VERSION"
    if version_gt "$NODE_VERSION" "$NODE_MIN_VERSION"; then
        echo -e "${GREEN}✓ Node.js版本符合要求（最低版本: $NODE_MIN_VERSION）${NC}"
    else
        echo -e "${RED}✗ Node.js版本过低，请升级至 $NODE_MIN_VERSION 或更高版本${NC}"
    fi
else
    echo -e "${RED}✗ 未安装Node.js${NC}"
fi
debug_log "完成Node.js检查"

# 检查NPM
echo -e "\n${CYAN}检查NPM环境...${NC}"
debug_log "开始检查NPM环境"
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    echo -e "${YELLOW}npm版本:${NC} $NPM_VERSION"
    if version_gt "$NPM_VERSION" "$NPM_MIN_VERSION"; then
        echo -e "${GREEN}✓ npm版本符合要求（最低版本: $NPM_MIN_VERSION）${NC}"
    else
        echo -e "${RED}✗ npm版本过低，请升级至 $NPM_MIN_VERSION 或更高版本${NC}"
    fi
else
    echo -e "${RED}✗ 未安装npm${NC}"
fi
debug_log "完成NPM检查"

# 检查Python
echo -e "\n${CYAN}检查Python环境...${NC}"
debug_log "开始检查Python环境"
PYTHON_CMD=""
for cmd in python3 python; do
    if command -v $cmd &> /dev/null; then
        PYTHON_VERSION=$($cmd --version 2>&1 | grep -oP '(?<=Python )[0-9.]+')
        if [[ $PYTHON_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${YELLOW}$cmd版本:${NC} $PYTHON_VERSION"
            if version_gt "$PYTHON_VERSION" "$PYTHON_MIN_VERSION"; then
                echo -e "${GREEN}✓ $cmd版本符合要求（最低版本: $PYTHON_MIN_VERSION）${NC}"
                PYTHON_CMD=$cmd
                break
            else
                echo -e "${RED}✗ $cmd版本过低，请升级至 $PYTHON_MIN_VERSION 或更高版本${NC}"
            fi
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}✗ 未找到合适的Python版本${NC}"
else
    # 检查Python依赖
    echo -e "\n${YELLOW}检查Python包...${NC}"
    debug_log "开始检查Python包"
    $PYTHON_CMD -c "
import sys

try:
    import requests
    print('\033[0;32m✓ requests已安装\033[0m')
except ImportError:
    print('\033[0;31m✗ 缺少requests包\033[0m')

try:
    import sqlite3
    print('\033[0;32m✓ sqlite3已安装\033[0m')
except ImportError:
    print('\033[0;31m✗ 缺少sqlite3包\033[0m')

try:
    import docker
    print('\033[0;32m✓ docker-py已安装\033[0m')
except ImportError:
    print('\033[0;31m✗ 缺少docker-py包 (用于Docker管理)\033[0m')

try:
    import numpy
    print('\033[0;32m✓ numpy已安装\033[0m')
except ImportError:
    print('\033[0;31m✗ 缺少numpy包 (用于数据处理)\033[0m')
"
    debug_log "完成Python包检查"
fi
debug_log "完成Python环境检查"

# 检查Docker（设置超时，避免卡住）
echo -e "\n${CYAN}检查Docker环境...${NC}"
debug_log "开始检查Docker环境"

docker_check_with_timeout() {
    # 设置超时时间为10秒
    timeout 10s docker info &> /dev/null
    return $?
}

if command -v docker &> /dev/null; then
    # 去掉Docker版本字符串中的非版本部分
    DOCKER_VERSION=$(docker --version | grep -oP '(?<=version )[0-9.]+')
    echo -e "${YELLOW}Docker版本:${NC} $DOCKER_VERSION"
    if version_gt "$DOCKER_VERSION" "$DOCKER_MIN_VERSION"; then
        echo -e "${GREEN}✓ Docker版本符合要求（最低版本: $DOCKER_MIN_VERSION）${NC}"
    else
        echo -e "${RED}✗ Docker版本过低，请升级至 $DOCKER_MIN_VERSION 或更高版本${NC}"
    fi
    
    # 检查Docker运行状态（带超时）
    echo -e "${YELLOW}正在检查Docker服务状态...（最多等待10秒）${NC}"
    if docker_check_with_timeout; then
        echo -e "${GREEN}✓ Docker服务正在运行${NC}"
        
        # 检查是否有Hummingbot镜像
        echo -e "${YELLOW}正在检查Hummingbot镜像...${NC}"
        if timeout 5s docker images | grep -q "hummingbot/hummingbot"; then
            HUMMINGBOT_VERSION=$(docker images | grep "hummingbot/hummingbot" | awk '{print $2}')
            echo -e "${GREEN}✓ 已安装Hummingbot镜像（版本: $HUMMINGBOT_VERSION）${NC}"
        else
            echo -e "${RED}✗ 未安装Hummingbot镜像${NC}"
        fi
    else
        echo -e "${RED}✗ Docker服务未运行或检查超时${NC}"
    fi
else
    echo -e "${RED}✗ 未安装Docker${NC}"
fi
debug_log "完成Docker环境检查"

# 检查项目依赖
echo -e "\n${CYAN}检查项目配置...${NC}"
debug_log "开始检查项目配置"

# 检查client目录
if [ -d "./client" ]; then
    echo -e "${GREEN}✓ 存在client目录${NC}"
    
    # 检查package.json
    if [ -f "./client/package.json" ]; then
        echo -e "${GREEN}✓ 存在package.json${NC}"
        
        # 检查重要前端依赖
        cd client
        if [ -d "./node_modules" ]; then
            echo -e "${YELLOW}检查前端依赖...${NC}"
            if [ -d "./node_modules/vue" ]; then
                VUE_VERSION=$(grep -o '"version": "[^"]*"' ./node_modules/vue/package.json | cut -d'"' -f4)
                echo -e "${GREEN}✓ Vue已安装 (版本: $VUE_VERSION)${NC}"
            else
                echo -e "${RED}✗ Vue未安装${NC}"
            fi
            
            if [ -d "./node_modules/electron" ]; then
                ELECTRON_VERSION=$(grep -o '"version": "[^"]*"' ./node_modules/electron/package.json | cut -d'"' -f4)
                echo -e "${GREEN}✓ Electron已安装 (版本: $ELECTRON_VERSION)${NC}"
            else
                echo -e "${RED}✗ Electron未安装${NC}"
            fi
            
            if [ -d "./node_modules/vite" ]; then
                VITE_VERSION=$(grep -o '"version": "[^"]*"' ./node_modules/vite/package.json | cut -d'"' -f4)
                echo -e "${GREEN}✓ Vite已安装 (版本: $VITE_VERSION)${NC}"
            else
                echo -e "${RED}✗ Vite未安装${NC}"
            fi
        else
            echo -e "${RED}✗ 未安装前端依赖，请运行 'npm install'${NC}"
        fi
        cd ..
    else
        echo -e "${RED}✗ 缺少package.json${NC}"
    fi
else
    echo -e "${RED}✗ 缺少client目录${NC}"
fi
debug_log "完成项目配置检查"

# 检查脚本目录
echo -e "\n${CYAN}检查脚本目录...${NC}"
debug_log "开始检查脚本目录"
if [ -d "./scripts" ]; then
    echo -e "${GREEN}✓ 存在scripts目录${NC}"
    
    # 统计必要脚本
    SCRIPT_COUNT=$(ls -1 ./scripts/*.sh 2>/dev/null | wc -l)
    echo -e "${YELLOW}已存在 $SCRIPT_COUNT 个脚本文件${NC}"
    
    # 检查重要脚本是否存在
    MISSING_SCRIPTS=()
    for script in "docker-commands.sh" "run-system.sh" "local-test.sh" "help.sh"; do
        if [ ! -f "./scripts/$script" ]; then
            MISSING_SCRIPTS+=("$script")
        fi
    done
    
    if [ ${#MISSING_SCRIPTS[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ 所有重要脚本已存在${NC}"
    else
        echo -e "${RED}✗ 缺少以下脚本:${NC}"
        for script in "${MISSING_SCRIPTS[@]}"; do
            echo -e "${RED}  - $script${NC}"
        done
    fi
else
    echo -e "${RED}✗ 缺少scripts目录${NC}"
fi
debug_log "完成脚本目录检查"

# 检查数据目录结构
echo -e "\n${CYAN}检查数据目录结构...${NC}"
debug_log "开始检查数据目录结构"
for dir in "logs" "data" "strategy_files"; do
    if [ -d "./$dir" ]; then
        echo -e "${GREEN}✓ 存在$dir目录${NC}"
    else
        echo -e "${RED}✗ 缺少$dir目录，将自动创建${NC}"
        mkdir -p "./$dir"
    fi
done
debug_log "完成数据目录结构检查"

# 检查SQLite数据库
echo -e "\n${CYAN}检查SQLite数据库...${NC}"
debug_log "开始检查SQLite数据库"
if [ -f "./data/crypto_grid.db" ]; then
    echo -e "${GREEN}✓ 存在SQLite数据库${NC}"
    DB_SIZE=$(du -h ./data/crypto_grid.db | cut -f1)
    echo -e "${YELLOW}  数据库大小: $DB_SIZE${NC}"
else
    echo -e "${YELLOW}⚠ 不存在SQLite数据库，将在首次运行时创建${NC}"
fi
debug_log "完成SQLite数据库检查"

echo -e "\n${BLUE}=============================================${NC}"
echo -e "${GREEN}      依赖检查完成                           ${NC}"
echo -e "${BLUE}=============================================${NC}"

exit 0 