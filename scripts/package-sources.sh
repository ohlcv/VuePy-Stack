#!/bin/bash

# 包管理源配置脚本 - package-sources.sh
# 用于配置npm、pip和Docker的源（官方源或国内源）
# 并自动修改Dockerfile和docker-compose.yml

# 如果未从父脚本接收颜色变量，则设置默认值
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# 如果未从父脚本接收目录变量，则设置默认值
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
fi

# 检测操作系统类型
detect_os_type() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Mac"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        echo "Windows"
    else
        echo "Unknown"
    fi
}

# 设置操作系统类型变量
OS_TYPE=$(detect_os_type)
echo -e "${YELLOW}检测到的操作系统类型: $OS_TYPE${NC}"

# 定义常量
DOCKERFILE="${SCRIPT_DIR}/client/Dockerfile"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"

# 显示标题
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  包管理源配置工具 - npm、pip和Docker源设置  ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 检查当前npm配置
check_npm_config() {
    echo -e "${YELLOW}检查当前npm配置:${NC}"
    
    if command -v npm &>/dev/null; then
        NPM_VERSION=$(npm --version 2>/dev/null || echo "未安装")
        NPM_REGISTRY=$(npm config get registry)
        
        echo "npm版本: $NPM_VERSION"
        echo "当前registry: $NPM_REGISTRY"
        
        # 返回版本
        echo "$NPM_VERSION"
    else
        echo -e "${YELLOW}npm未安装或不在PATH中${NC}"
        echo "未安装"
    fi
}

# 检查当前pip配置
check_pip_config() {
    echo -e "${YELLOW}检查当前pip配置:${NC}"
    
    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        # 确定pip命令
        if command -v pip3 &>/dev/null; then
            PIP_CMD="pip3"
        else
            PIP_CMD="pip"
        fi
        
        PIP_VERSION=$($PIP_CMD --version 2>/dev/null | cut -d' ' -f2 || echo "未安装")
        
        echo "pip版本: $PIP_VERSION"
        echo "当前配置:"
        $PIP_CMD config list 2>/dev/null || echo "无法获取pip配置"
        
        # 尝试获取index-url
        PIP_INDEX_URL=$($PIP_CMD config list 2>/dev/null | grep "index-url" | awk '{print $3}')
        
        if [ -n "$PIP_INDEX_URL" ]; then
            echo "当前index-url: $PIP_INDEX_URL"
        else
            echo "使用默认index-url (https://pypi.org/simple)"
            PIP_INDEX_URL="https://pypi.org/simple"
        fi
        
        # 返回版本
        echo "$PIP_VERSION"
    else
        echo -e "${YELLOW}pip未安装或不在PATH中${NC}"
        echo "未安装"
    fi
}

# 检查当前Docker镜像源配置
check_docker_config() {
    echo -e "${YELLOW}检查当前Docker配置:${NC}"
    
    if command -v docker &>/dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        echo "Docker版本: $DOCKER_VERSION"
        
        # 检查Docker daemon配置
        if [ -f "$DOCKER_DAEMON_JSON" ]; then
            echo "当前Docker配置文件:"
            cat "$DOCKER_DAEMON_JSON" 2>/dev/null || echo "无法读取docker配置文件"
            
            # 尝试解析registry-mirrors
            DOCKER_MIRRORS=$(grep -o '"registry-mirrors":\s*\[[^]]*\]' "$DOCKER_DAEMON_JSON" 2>/dev/null || echo "")
            if [ -n "$DOCKER_MIRRORS" ]; then
                echo "当前registry-mirrors: $DOCKER_MIRRORS"
            else
                echo "未配置registry-mirrors，使用Docker默认镜像源"
            fi
        else
            echo "Docker配置文件不存在，使用默认配置"
        fi
        
        # 返回版本
        echo "$DOCKER_VERSION"
    else
        echo -e "${YELLOW}Docker未安装或不在PATH中${NC}"
        echo "未安装"
    fi
}

# 测试源的连接速度和可用性
test_source_speed() {
    local source_url="$1"
    local timeout=5
    
    echo -e "${YELLOW}测试源 $source_url 的连接速度...${NC}"
    
    # 使用curl测试响应时间（连接+首字节时间）
    local start_time=$(date +%s)
    curl -s -o /dev/null -m "$timeout" --connect-timeout "$timeout" "$source_url" 2>/dev/null
    local exit_code=$?
    local end_time=$(date +%s)
    
    # 计算耗时（秒）- 使用简单减法代替bc
    local time_diff=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}成功连接 $source_url，响应时间: ${time_diff}秒${NC}"
        # 返回纯数字，没有任何其他输出
        echo "$time_diff"
    elif [ $exit_code -eq 28 ]; then
        echo -e "${RED}连接超时: $source_url${NC}"
        echo "999999" # 使用大数值表示超时
    else
        echo -e "${RED}连接失败: $source_url (错误码: $exit_code)${NC}"
        echo "999999" # 使用大数值表示失败
    fi
}

# 设置npm registry
set_npm_registry() {
    local registry="$1"
    
    # 记录当前配置
    local current_registry=$(npm config get registry 2>/dev/null || echo "未配置")
    
    echo -e "${BLUE}设置npm registry: $registry${NC}"
    echo -e "${YELLOW}替换旧源: $current_registry${NC}"
    
    # 设置新源
    npm config set registry "$registry" >/dev/null 2>&1
    
    # 验证设置成功
    local new_registry=$(npm config get registry)
    
    if [ "$new_registry" = "$registry" ]; then
        echo -e "${GREEN}npm registry已设置为: $new_registry${NC}"
        return 0
    else
        echo -e "${RED}npm registry设置失败${NC}"
        return 1
    fi
}

# 设置pip index-url
set_pip_index() {
    local index_url="$1"
    local trusted_host="$2"
    
    # 获取当前配置的pip源
    local current_index_url=$(pip config list 2>/dev/null | grep "index-url" | awk -F '=' '{print $2}' | tr -d ' ' || echo "(默认) https://pypi.org/simple")
    
    echo -e "${BLUE}设置pip index-url: $index_url${NC}"
    echo -e "${YELLOW}替换旧源: $current_index_url${NC}"
    
    # 创建pip配置目录
    local pip_config_dir=""
    local pip_config_file=""
    
    if [[ "$OS_TYPE" == "Windows" ]]; then
        # Windows环境
        pip_config_dir="$HOME/pip"
        pip_config_file="$pip_config_dir/pip.ini"
        mkdir -p "$pip_config_dir" 2>/dev/null
        
        # 直接写入配置文件
        echo "[global]" > "$pip_config_file"
        echo "index-url = $index_url" >> "$pip_config_file"
        
        if [ -n "$trusted_host" ]; then
            echo "trusted-host = $trusted_host" >> "$pip_config_file"
        fi
        
        if [ -f "$pip_config_file" ]; then
            echo -e "${GREEN}pip配置已写入: $pip_config_file${NC}"
            return 0
        else
            echo -e "${RED}pip源设置失败${NC}"
            return 1
        fi
    else
        # Linux/Mac环境
        pip_config_dir="$HOME/.config/pip"
        pip_config_file="$pip_config_dir/pip.conf"
        mkdir -p "$pip_config_dir" 2>/dev/null

        # 设置pip源
        if ! pip config set global.index-url "$index_url" >/dev/null 2>&1; then
            echo -e "${RED}pip源设置失败${NC}"
            return 1
        fi
        
        # 设置trusted-host（如果提供）
        if [ -n "$trusted_host" ]; then
            pip config set global.trusted-host "$trusted_host" >/dev/null 2>&1
        fi
        
        echo -e "${GREEN}pip配置已更新${NC}"
        return 0
    fi
}

# 设置Docker镜像源（registry-mirrors）
set_docker_mirrors() {
    local mirrors="$1"
    
    # 输出当前配置
    if [ -f "$DOCKER_DAEMON_JSON" ]; then
        local old_config=$(cat "$DOCKER_DAEMON_JSON")
        echo -e "${YELLOW}替换旧源: $old_config${NC}"
    fi
    
    if [[ "$OS_TYPE" == "Windows" ]] || [[ "$OS_TYPE" == "Mac" ]]; then
        echo -e "${YELLOW}在${OS_TYPE}系统上配置Docker镜像源...${NC}"
        
        # 尝试备份当前配置
        if [ -f "$DOCKER_DAEMON_JSON" ]; then
            cp "$DOCKER_DAEMON_JSON" "${DOCKER_DAEMON_JSON}.bak"
            echo -e "${GREEN}已备份当前配置到: $DOCKER_DAEMON_JSON.bak${NC}"
        fi
        
        # 检查文件是否存在
        if [ ! -f "$DOCKER_DAEMON_JSON" ]; then
            # 目录不存在则创建
            mkdir -p "$(dirname "$DOCKER_DAEMON_JSON")" 2>/dev/null
            
            # 创建基本配置
            echo "{}" > "$DOCKER_DAEMON_JSON" 2>/dev/null
        fi
        
        # 尝试多种方法更新配置
        local success=false
        
        # 方法1: 直接写入新配置
        if ! $success; then
            if echo "{\"registry-mirrors\":$mirrors}" > "$DOCKER_DAEMON_JSON" 2>/dev/null; then
                success=true
                echo -e "${GREEN}已成功更新Docker配置${NC}"
            fi
        fi
        
        # 方法2: 使用临时文件
        if ! $success; then
            local temp_file=$(mktemp)
            if echo "{\"registry-mirrors\":$mirrors}" > "$temp_file" && \
               cp "$temp_file" "$DOCKER_DAEMON_JSON" 2>/dev/null; then
                rm -f "$temp_file"
                success=true
                echo -e "${GREEN}已成功更新Docker配置（使用临时文件）${NC}"
            else
                rm -f "$temp_file"
            fi
        fi
        
        # 方法3: Windows下尝试使用PowerShell
        if [[ "$OS_TYPE" == "Windows" ]] && ! $success; then
            local ps_path=$(which powershell.exe 2>/dev/null)
            if [ -n "$ps_path" ]; then
                local win_path=$(echo "$DOCKER_DAEMON_JSON" | sed 's|/c/|C:/|')
                if "$ps_path" -Command "Set-Content -Path '$win_path' -Value '{\"registry-mirrors\":$mirrors}'" 2>/dev/null; then
                    success=true
                    echo -e "${GREEN}已成功更新Docker配置（使用PowerShell）${NC}"
                fi
            fi
        fi
        
        # 如果所有方法都失败，提供手动配置指导
        if ! $success; then
            echo -e "${YELLOW}自动更新配置文件失败，建议手动修改${NC}"
            echo -e "${YELLOW}您需要手动重启Docker Desktop以应用配置:${NC}"
            echo -e "${CYAN}1. 打开Docker Desktop -> Settings -> Docker Engine${NC}"
            echo -e "${CYAN}2. 确认以下配置已添加:${NC}"
            echo -e "${CYAN}   \"registry-mirrors\": $mirrors${NC}"
            echo -e "${CYAN}3. 点击Apply & Restart${NC}"
            
            # 检查是否已存在配置文件
            if [ -f "$DOCKER_DAEMON_JSON" ]; then
                echo -e "${YELLOW}或者您已经有一个配置文件: $DOCKER_DAEMON_JSON${NC}"
            fi
        fi
        
        echo -e "${YELLOW}Docker Desktop需要手动重启以应用新的镜像源设置${NC}"
        echo -e "${YELLOW}您可以在应用设置后手动测试连接${NC}"
        
        return 0
    else
        # Linux系统下的配置方式
        echo -e "${YELLOW}在Linux系统上配置Docker镜像源...${NC}"
        
        local success=false
        
        # 检查是否可以使用sudo
        if command -v sudo &>/dev/null; then
            if [ ! -d "$(dirname "$DOCKER_DAEMON_JSON")" ]; then
                sudo mkdir -p "$(dirname "$DOCKER_DAEMON_JSON")" 2>/dev/null
            fi
            
            if [ ! -f "$DOCKER_DAEMON_JSON" ]; then
                echo "{}" | sudo tee "$DOCKER_DAEMON_JSON" > /dev/null
            fi
            
            if echo "{\"registry-mirrors\":$mirrors}" | sudo tee "$DOCKER_DAEMON_JSON" > /dev/null; then
                success=true
                echo -e "${GREEN}已成功更新Docker配置${NC}"
                
                # 尝试重启Docker服务
                if sudo systemctl restart docker &>/dev/null; then
                    echo -e "${GREEN}已重启Docker服务${NC}"
                else
                    echo -e "${YELLOW}无法自动重启Docker服务，请手动重启:${NC}"
                    echo -e "${CYAN}sudo systemctl restart docker${NC}"
                fi
            fi
        fi
        
        if ! $success; then
            echo -e "${YELLOW}自动更新配置文件失败，建议手动修改${NC}"
            echo -e "${YELLOW}您需要手动编辑配置文件并重启Docker:${NC}"
            echo -e "${CYAN}1. 编辑 $DOCKER_DAEMON_JSON${NC}"
            echo -e "${CYAN}2. 添加: {\"registry-mirrors\": $mirrors}${NC}"
            echo -e "${CYAN}3. 重启 Docker: sudo systemctl restart docker${NC}"
        fi
        
        return 0
    fi
}

# 测试Docker镜像源连接
test_docker_connection() {
    echo -e "${YELLOW}测试Docker镜像源连接...${NC}"
    
    # 检查Docker是否已安装
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Docker未安装，跳过连接测试${NC}"
        return 1
    fi
    
    # 尝试拉取一个小的测试镜像(alpine是最小的官方镜像之一)
    echo -e "${CYAN}尝试从配置的镜像源拉取测试镜像(alpine:latest)...${NC}"
    
    # 尝试拉取，设置超时
    docker pull alpine:latest --quiet &>/dev/null &
    local pull_pid=$!
    
    # 等待30秒或直到拉取完成
    local timeout=30
    local counter=0
    while kill -0 $pull_pid 2>/dev/null; do
        if [ $counter -ge $timeout ]; then
            echo -e "${RED}拉取超时，Docker连接可能有问题${NC}"
            kill $pull_pid 2>/dev/null || true
            return 1
        fi
        echo -n "."
        sleep 1
        counter=$((counter + 1))
    done
    
    # 检查拉取是否成功
    if docker image inspect alpine:latest &>/dev/null; then
        echo -e "\n${GREEN}连接测试成功! Docker镜像源工作正常${NC}"
        echo -e "${CYAN}提示: 如果您在构建时遇到网络问题，可以尝试以下操作:${NC}"
        echo -e "${CYAN}1. 确保您的网络环境稳定，可以访问Docker镜像源${NC}"
        echo -e "${CYAN}2. 如果使用代理，确保Docker也配置了相同的代理设置${NC}"
        echo -e "${CYAN}3. 尝试在Docker Desktop中手动设置镜像源${NC}"
        return 0
    else
        echo -e "\n${RED}连接测试失败，无法拉取镜像${NC}"
        echo -e "${YELLOW}您可能遇到网络连接问题，建议检查:${NC}"
        echo -e "${YELLOW}1. 网络连接是否正常${NC}"
        echo -e "${YELLOW}2. 是否需要配置代理${NC}"
        echo -e "${YELLOW}3. 镜像源URL是否正确${NC}"
        echo -e "${YELLOW}4. 尝试重启Docker服务${NC}"
        return 1
    fi
}

# 自动检测最佳源
auto_detect_sources() {
    echo -e "${BLUE}自动检测最佳源...${NC}"
    
    # 定义要测试的源
    local npm_sources=(
        "https://registry.npmjs.org/|官方源"
        "https://registry.npmmirror.com/|淘宝镜像"
    )
    
    local pip_sources=(
        "https://pypi.org/simple|官方源"
        "https://mirrors.aliyun.com/pypi/simple/|阿里云镜像"
    )
    
    local docker_sources=(
        "https://registry-1.docker.io|官方源"
        "https://registry.cn-hangzhou.aliyuncs.com|阿里云镜像"
    )
    
    # 检测npm源
    echo -e "\n${CYAN}检测npm源:${NC}"
    local npm_best_source=""
    local npm_best_time=999999
    local npm_best_name=""
    
    for source_info in "${npm_sources[@]}"; do
        IFS='|' read -r source_url source_name <<< "$source_info"
        echo -e "${YELLOW}测试 $source_name ($source_url)...${NC}"
        
        # 捕获纯数字输出
        local result=$(test_source_speed "$source_url" | tail -n 1)
        
        # 预防非数字输出，确保result是数字
        if ! [[ "$result" =~ ^[0-9]+$ ]]; then
            result=999999
        fi
        
        # 数值比较（小于）
        if [ "$result" -lt "$npm_best_time" ]; then
            npm_best_time=$result
            npm_best_source=$source_url
            npm_best_name=$source_name
        fi
    done
    
    if [ "$npm_best_time" -lt 999999 ]; then
        echo -e "${GREEN}最佳npm源: $npm_best_name ($npm_best_source), 响应时间: ${npm_best_time}秒${NC}"
        NPM_REGISTRY="$npm_best_source"
    else
        echo -e "${RED}未找到可用的npm源，使用默认官方源${NC}"
        NPM_REGISTRY="https://registry.npmjs.org/"
    fi
    
    # 检测pip源
    echo -e "\n${CYAN}检测pip源:${NC}"
    local pip_best_source=""
    local pip_best_time=999999
    local pip_best_name=""
    local pip_best_host=""
    
    for source_info in "${pip_sources[@]}"; do
        IFS='|' read -r source_url source_name <<< "$source_info"
        echo -e "${YELLOW}测试 $source_name ($source_url)...${NC}"
        
        # 捕获纯数字输出
        local result=$(test_source_speed "$source_url" | tail -n 1)
        
        # 预防非数字输出，确保result是数字
        if ! [[ "$result" =~ ^[0-9]+$ ]]; then
            result=999999
        fi
        
        # 数值比较（小于）
        if [ "$result" -lt "$pip_best_time" ]; then
            pip_best_time=$result
            pip_best_source=$source_url
            pip_best_name=$source_name
            # 提取主机名作为trusted-host
            pip_best_host=$(echo "$source_url" | grep -oE '([^/]+\.)+[^/.]+' | head -1)
        fi
    done
    
    if [ "$pip_best_time" -lt 999999 ]; then
        echo -e "${GREEN}最佳pip源: $pip_best_name ($pip_best_source), 响应时间: ${pip_best_time}秒${NC}"
        PIP_INDEX_URL="$pip_best_source"
        
        # 如果不是官方源，设置trusted-host
        if [[ "$pip_best_source" != "https://pypi.org/simple"* ]]; then
            PIP_TRUSTED_HOST="$pip_best_host"
        else
            PIP_TRUSTED_HOST=""
        fi
    else
        echo -e "${RED}未找到可用的pip源，使用默认官方源${NC}"
        PIP_INDEX_URL="https://pypi.org/simple"
        PIP_TRUSTED_HOST=""
    fi
    
    # 检测Docker源
    echo -e "\n${CYAN}检测Docker源:${NC}"
    local docker_best_source=""
    local docker_best_time=999999
    local docker_best_name=""
    
    for source_info in "${docker_sources[@]}"; do
        IFS='|' read -r source_url source_name <<< "$source_info"
        echo -e "${YELLOW}测试 $source_name ($source_url)...${NC}"
        
        # 捕获纯数字输出
        local result=$(test_source_speed "$source_url" | tail -n 1)
        
        # 预防非数字输出，确保result是数字
        if ! [[ "$result" =~ ^[0-9]+$ ]]; then
            result=999999
        fi
        
        # 数值比较（小于）
        if [ "$result" -lt "$docker_best_time" ]; then
            docker_best_time=$result
            docker_best_source=$source_url
            docker_best_name=$source_name
        fi
    done
    
    if [ "$docker_best_time" -lt 999999 ]; then
        echo -e "${GREEN}最佳Docker源: $docker_best_name ($docker_best_source), 响应时间: ${docker_best_time}秒${NC}"
        DOCKER_MIRRORS="[\"$docker_best_source\"]"
    else
        echo -e "${RED}未找到可用的Docker源，使用默认官方源${NC}"
        DOCKER_MIRRORS='["https://registry-1.docker.io"]'
    fi
    
    # 显示选择结果
    echo -e "\n${BLUE}自动检测结果:${NC}"
    echo -e "${CYAN}npm源: $NPM_REGISTRY${NC}"
    echo -e "${CYAN}pip源: $PIP_INDEX_URL${NC}"
    if [ -n "$PIP_TRUSTED_HOST" ]; then
        echo -e "${CYAN}pip trusted-host: $PIP_TRUSTED_HOST${NC}"
    fi
    echo -e "${CYAN}Docker源: $DOCKER_MIRRORS${NC}"
    
    # 询问用户是否应用
    echo -e "\n${YELLOW}是否应用自动检测的配置? (y/n)${NC}"
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        echo -e "${YELLOW}取消自动配置${NC}"
        # 清空配置，不应用
        NPM_REGISTRY=""
        PIP_INDEX_URL=""
        PIP_TRUSTED_HOST=""
        DOCKER_MIRRORS=""
        return 1
    fi
}

# 主函数
main() {
    # 检查当前配置
    local npm_version=$(check_npm_config)
    local pip_version=$(check_pip_config)
    local docker_version=$(check_docker_config)
    
    echo -e "\n${BLUE}选择源配置选项:${NC}"
    echo -e "${CYAN}1. 官方源 (默认，全球通用)${NC}"
    echo -e "${CYAN}2. 中国镜像源 (国内推荐)${NC}"
    echo -e "${CYAN}3. 自定义源${NC}"
    echo -e "${CYAN}4. 自动检测最佳源${NC}"
    echo -e "${CYAN}0. 退出${NC}"
    
    echo -e "${YELLOW}请选择 (0-4):${NC}"
    read -n 1 -r
    echo
    
    local NPM_REGISTRY=""
    local PIP_INDEX_URL=""
    local PIP_TRUSTED_HOST=""
    local DOCKER_MIRRORS=""
    
    case $REPLY in
        1)
            echo -e "${BLUE}使用官方源${NC}"
            NPM_REGISTRY="https://registry.npmjs.org/"
            PIP_INDEX_URL="https://pypi.org/simple"
            DOCKER_MIRRORS='["https://registry-1.docker.io"]'
            ;;
        2)
            echo -e "${BLUE}使用中国镜像源${NC}"
            echo -e "${CYAN}npm: 淘宝 NPM 镜像${NC}"
            echo -e "${CYAN}pip: 阿里云镜像${NC}"
            echo -e "${CYAN}docker: 阿里云镜像${NC}"
            NPM_REGISTRY="https://registry.npmmirror.com/"
            PIP_INDEX_URL="https://mirrors.aliyun.com/pypi/simple/"
            PIP_TRUSTED_HOST="mirrors.aliyun.com"
            DOCKER_MIRRORS='["https://registry.cn-hangzhou.aliyuncs.com"]'
            ;;
        3)
            echo -e "${BLUE}自定义源${NC}"
            echo -e "${YELLOW}请输入npm registry (留空使用默认):${NC}"
            read custom_npm_registry
            
            echo -e "${YELLOW}请输入pip index-url (留空使用默认):${NC}"
            read custom_pip_index
            
            echo -e "${YELLOW}请输入pip trusted-host (留空不设置):${NC}"
            read custom_pip_trusted_host
            
            echo -e "${YELLOW}请输入Docker镜像源 URL (留空使用默认):${NC}"
            read custom_docker_mirror
            
            if [ -n "$custom_npm_registry" ]; then
                NPM_REGISTRY="$custom_npm_registry"
            fi
            
            if [ -n "$custom_pip_index" ]; then
                PIP_INDEX_URL="$custom_pip_index"
                
                if [ -n "$custom_pip_trusted_host" ]; then
                    PIP_TRUSTED_HOST="$custom_pip_trusted_host"
                else
                    # 尝试从index-url提取域名作为trusted-host
                    PIP_TRUSTED_HOST=$(echo "$custom_pip_index" | grep -oP '(?<=://)([^/]+)')
                fi
            fi
            
            if [ -n "$custom_docker_mirror" ]; then
                DOCKER_MIRRORS="[\"$custom_docker_mirror\"]"
            fi
            ;;
        4)
            # 自动检测最佳源
            auto_detect_sources
            ;;
        0)
            echo -e "${GREEN}退出，未做任何更改${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return 1
            ;;
    esac
    
    # 设置所选源
    local changes_made=false
    
    if [ -n "$NPM_REGISTRY" ]; then
        set_npm_registry "$NPM_REGISTRY" && changes_made=true
    fi
    
    if [ -n "$PIP_INDEX_URL" ]; then
        set_pip_index "$PIP_INDEX_URL" "$PIP_TRUSTED_HOST" && changes_made=true
    fi
    
    if [ -n "$DOCKER_MIRRORS" ]; then
        if set_docker_mirrors "$DOCKER_MIRRORS"; then
            changes_made=true
            
            # 添加Docker连接测试
            if [[ "$OS_TYPE" == "Windows" ]] || [[ "$OS_TYPE" == "Mac" ]]; then
                echo -e "${YELLOW}Docker Desktop需要手动重启以应用新的镜像源设置${NC}"
                echo -e "${YELLOW}您可以在应用设置后手动测试连接${NC}"
            else
                # 在Linux上自动测试连接
                test_docker_connection
            fi
        fi
    fi
    
    if [ "$changes_made" = true ]; then
        echo -e "${GREEN}源配置已更新${NC}"
        
        # 提示用户可以使用update-docker命令更新Docker文件
        echo -e "${YELLOW}如需更新Dockerfile和docker-compose.yml中的源配置，请使用以下命令:${NC}"
        echo -e "${CYAN}  ./start.sh update-docker${NC}"
    fi
    
    return 0
}

# 执行主函数
main "$@" 