#!/bin/bash

# 更新 Docker 文件脚本
# 用于根据当前配置的源设置来更新 Dockerfile 和 docker-compose.yml 文件

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

# 设置操作系统类型变量
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

OS_TYPE=$(detect_os_type)
echo -e "${YELLOW}检测到的操作系统类型: $OS_TYPE${NC}"

# 定义常量
DOCKERFILE="${SCRIPT_DIR}/client/Dockerfile"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"

# Windows下尝试找到daemon.json的位置
if [[ "$OS_TYPE" == "Windows" ]]; then
    if [ -f "$HOME/.docker/daemon.json" ]; then
        DOCKER_DAEMON_JSON="$HOME/.docker/daemon.json"
    elif [ -f "/c/ProgramData/Docker/config/daemon.json" ]; then
        DOCKER_DAEMON_JSON="/c/ProgramData/Docker/config/daemon.json"
    else
        DOCKER_DAEMON_JSON="$HOME/.docker/daemon.json"
    fi
fi

# 显示标题
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  更新 Docker 文件 - 根据源配置更新          ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 获取当前配置的npm源
get_npm_registry() {
    if command -v npm &>/dev/null; then
        npm config get registry
    else
        echo "https://registry.npmjs.org/"
    fi
}

# 获取当前配置的pip源
get_pip_index_url() {
    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        # 确定pip命令
        if command -v pip3 &>/dev/null; then
            PIP_CMD="pip3"
        else
            PIP_CMD="pip"
        fi
        
        # 尝试获取index-url
        PIP_INDEX=$($PIP_CMD config list 2>/dev/null | grep "index-url" | awk -F '=' '{print $2}' | tr -d ' ')
        
        if [ -n "$PIP_INDEX" ]; then
            echo "$PIP_INDEX"
        else
            echo "https://pypi.org/simple"
        fi
    else
        echo "https://pypi.org/simple"
    fi
}

# 获取当前配置的pip trusted-host
get_pip_trusted_host() {
    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        # 确定pip命令
        if command -v pip3 &>/dev/null; then
            PIP_CMD="pip3"
        else
            PIP_CMD="pip"
        fi
        
        # 尝试获取trusted-host
        PIP_TRUSTED=$($PIP_CMD config list 2>/dev/null | grep "trusted-host" | awk -F '=' '{print $2}' | tr -d ' ')
        
        echo "$PIP_TRUSTED"
    else
        echo ""
    fi
}

# 获取当前配置的Docker镜像源
get_docker_mirrors() {
    if [ -f "$DOCKER_DAEMON_JSON" ]; then
        # 尝试解析registry-mirrors
        DOCKER_MIRRORS=$(grep -o '"registry-mirrors":\s*\[[^]]*\]' "$DOCKER_DAEMON_JSON" 2>/dev/null || echo "")
        if [ -n "$DOCKER_MIRRORS" ]; then
            # 提取第一个镜像源URL
            MIRROR_URL=$(echo "$DOCKER_MIRRORS" | grep -oP '(?<=\[")([^"]+)' | head -1)
            
            # 移除HTTP协议前缀，如果存在
            MIRROR_URL=$(echo "$MIRROR_URL" | sed -E 's|^https?://||')
            
            echo "$MIRROR_URL"
        else
            echo "registry.hub.docker.com"
        fi
    else
        echo "registry.hub.docker.com"
    fi
}

# 修改Dockerfile中的源配置
modify_dockerfile() {
    local npm_registry="$1"
    local pip_index_url="$2"
    local pip_trusted_host="$3"
    local docker_mirror="$4"
    
    if [ ! -f "$DOCKERFILE" ]; then
        echo -e "${YELLOW}警告: 未找到Dockerfile: $DOCKERFILE${NC}"
        return 1
    fi
    
    # 备份Dockerfile
    cp "$DOCKERFILE" "${DOCKERFILE}.bak.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}已备份Dockerfile${NC}"
    
    echo -e "${YELLOW}更新Dockerfile中的配置...${NC}"
    
    # 更新Docker基础镜像
    if [ -n "$docker_mirror" ]; then
        # 移除HTTP协议前缀，确保使用正确的Docker镜像引用格式
        docker_mirror=$(echo "$docker_mirror" | sed -E 's|^https?://||')
        
        if [[ "$docker_mirror" != */ ]]; then
            docker_mirror="${docker_mirror}/"
        fi
        
        # 如果是Docker Hub官方镜像源，则使用默认格式不加前缀
        if [[ "$docker_mirror" == "registry.hub.docker.com/" || "$docker_mirror" == "registry-1.docker.io/" ]]; then
            sed -i "s|ARG NODE_IMAGE=.*|ARG NODE_IMAGE=node:20-slim|g" "$DOCKERFILE"
        else
            # 更新NODE_IMAGE参数，使用自定义镜像源
            sed -i "s|ARG NODE_IMAGE=.*|ARG NODE_IMAGE=${docker_mirror}node:20-slim|g" "$DOCKERFILE"
        fi
        
        # 检查是否更新成功
        if grep -q "ARG NODE_IMAGE=" "$DOCKERFILE"; then
            echo -e "${GREEN}已更新Dockerfile中的NODE_IMAGE参数${NC}"
        else
            echo -e "${YELLOW}警告: 无法更新NODE_IMAGE参数${NC}"
        fi
    fi
    
    # 更新npm源配置
    if [ -n "$npm_registry" ]; then
        sed -i "s|npm config set registry.*|npm config set registry $npm_registry; \\\\|g" "$DOCKERFILE"
        sed -i "s|--registry=.*|--registry=\$NPM_REGISTRY --ignore-scripts|g" "$DOCKERFILE"
        
        echo -e "${GREEN}已更新Dockerfile中的npm源配置${NC}"
    fi
    
    # 更新pip源配置
    if [ -n "$pip_index_url" ]; then
        if [ -n "$pip_trusted_host" ]; then
            sed -i "s|-i .*|-i \$PIP_INDEX_URL --trusted-host \$PIP_TRUSTED_HOST --no-cache-dir -r requirements.txt|g" "$DOCKERFILE"
        else
            sed -i "s|-i .*|-i \$PIP_INDEX_URL --no-cache-dir -r requirements.txt|g" "$DOCKERFILE"
        fi
        
        echo -e "${GREEN}已更新Dockerfile中的pip源配置${NC}"
    fi
    
    echo -e "${GREEN}Dockerfile更新成功${NC}"
    return 0
}

# 修改docker-compose.yml中的源配置
modify_docker_compose() {
    local npm_registry="$1"
    local pip_index_url="$2"
    local pip_trusted_host="$3"
    local docker_mirror="$4"
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}警告: 未找到docker-compose.yml: $DOCKER_COMPOSE_FILE${NC}"
        return 1
    fi
    
    # 备份docker-compose.yml
    cp "$DOCKER_COMPOSE_FILE" "${DOCKER_COMPOSE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}已备份docker-compose.yml${NC}"
    
    echo -e "${YELLOW}更新docker-compose.yml中的配置...${NC}"
    
    # 更新Docker基础镜像
    if [ -n "$docker_mirror" ]; then
        # 移除HTTP协议前缀，确保使用正确的Docker镜像引用格式
        docker_mirror=$(echo "$docker_mirror" | sed -E 's|^https?://||')
        
        if [[ "$docker_mirror" != */ ]]; then
            docker_mirror="${docker_mirror}/"
        fi
        
        # 如果是Docker Hub官方镜像源，则使用默认格式不加前缀
        if [[ "$docker_mirror" == "registry.hub.docker.com/" || "$docker_mirror" == "registry-1.docker.io/" ]]; then
            sed -i "s|- NODE_IMAGE=.*|- NODE_IMAGE=node:20-slim|g" "$DOCKER_COMPOSE_FILE"
            sed -i "s|image: .*hummingbot/hummingbot:latest|image: hummingbot/hummingbot:latest|g" "$DOCKER_COMPOSE_FILE"
        else
            # 使用自定义镜像源
            sed -i "s|- NODE_IMAGE=.*|- NODE_IMAGE=${docker_mirror}node:20-slim|g" "$DOCKER_COMPOSE_FILE"
            sed -i "s|image: .*hummingbot/hummingbot:latest|image: ${docker_mirror}hummingbot/hummingbot:latest|g" "$DOCKER_COMPOSE_FILE"
        fi
        
        echo -e "${GREEN}已更新docker-compose.yml中的Docker镜像配置${NC}"
    fi
    
    # 更新npm源配置
    if [ -n "$npm_registry" ]; then
        sed -i "s|- NPM_REGISTRY=.*|- NPM_REGISTRY=$npm_registry|g" "$DOCKER_COMPOSE_FILE"
        echo -e "${GREEN}已更新docker-compose.yml中的npm源配置${NC}"
    fi
    
    # 更新pip源配置
    if [ -n "$pip_index_url" ]; then
        sed -i "s|- PIP_INDEX_URL=.*|- PIP_INDEX_URL=$pip_index_url|g" "$DOCKER_COMPOSE_FILE"
        
        if [ -n "$pip_trusted_host" ]; then
            sed -i "s|- PIP_TRUSTED_HOST=.*|- PIP_TRUSTED_HOST=$pip_trusted_host|g" "$DOCKER_COMPOSE_FILE"
        fi
        
        echo -e "${GREEN}已更新docker-compose.yml中的pip源配置${NC}"
    fi
    
    echo -e "${GREEN}docker-compose.yml更新成功${NC}"
    return 0
}

# 主函数
main() {
    # 获取当前配置的源
    local npm_registry=$(get_npm_registry)
    local pip_index_url=$(get_pip_index_url)
    local pip_trusted_host=$(get_pip_trusted_host)
    local docker_mirror=$(get_docker_mirrors)
    
    echo -e "${BLUE}当前配置的源:${NC}"
    echo -e "${CYAN}npm源: $npm_registry${NC}"
    echo -e "${CYAN}pip源: $pip_index_url${NC}"
    if [ -n "$pip_trusted_host" ]; then
        echo -e "${CYAN}pip trusted-host: $pip_trusted_host${NC}"
    fi
    echo -e "${CYAN}Docker镜像源: $docker_mirror${NC}"
    
    # 询问是否更新Docker文件
    echo -e "\n${YELLOW}是否根据当前配置更新Dockerfile和docker-compose.yml? (y/n)${NC}"
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 修改Dockerfile
        modify_dockerfile "$npm_registry" "$pip_index_url" "$pip_trusted_host" "$docker_mirror"
        
        # 修改docker-compose.yml
        modify_docker_compose "$npm_registry" "$pip_index_url" "$pip_trusted_host" "$docker_mirror"
        
        echo -e "${GREEN}Docker文件已更新，源配置已同步${NC}"
        echo -e "${YELLOW}需要重新构建Docker容器才能应用这些更改${NC}"
        echo -e "${YELLOW}可以使用 ./start.sh build 重新构建容器${NC}"
    else
        echo -e "${YELLOW}取消更新Docker文件${NC}"
    fi
    
    return 0
}

# 执行主函数
main "$@" 