#!/bin/bash

# 环境设置脚本 - setup-environment.sh
# 用于检查和安装环境依赖

# 如果未从父脚本接收颜色变量，则设置默认值
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# 检查系统类型
detect_system() {
    echo -e "${BLUE}检测系统类型...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="Linux"
        echo -e "${GREEN}检测到Linux系统${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macOS"
        echo -e "${GREEN}检测到macOS系统${NC}"
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        OS_TYPE="Windows"
        echo -e "${GREEN}检测到Windows系统${NC}"
    else
        OS_TYPE="Unknown"
        echo -e "${YELLOW}未能识别的操作系统: $OSTYPE${NC}"
    fi
    
    export OS_TYPE
}

# 检查Python环境
check_python() {
    echo -e "${BLUE}检查Python环境...${NC}"
    
    if command -v python &>/dev/null || command -v python3 &>/dev/null; then
        # 尝试获取Python版本
        if command -v python3 &>/dev/null; then
            PYTHON_CMD="python3"
        else
            PYTHON_CMD="python"
        fi
        
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
        echo -e "${GREEN}Python已安装: $PYTHON_VERSION${NC}"
        
        # 检查Python版本
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
        
        if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
            echo -e "${YELLOW}警告: Python版本 $PYTHON_VERSION 低于推荐的3.10+${NC}"
            echo -e "${YELLOW}某些功能可能不可用或不稳定${NC}"
            
            read -p "是否继续？(y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${RED}安装已取消${NC}"
                exit 1
            fi
        fi
        
        # 检查pip
        if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
            if command -v pip3 &>/dev/null; then
                PIP_CMD="pip3"
            else
                PIP_CMD="pip"
            fi
            
            PIP_VERSION=$($PIP_CMD --version | awk '{print $2}')
            echo -e "${GREEN}pip已安装: $PIP_VERSION${NC}"
        else
            echo -e "${YELLOW}pip未安装，尝试安装...${NC}"
            
            case "$OS_TYPE" in
                Linux)
                    if command -v apt-get &>/dev/null; then
                        sudo apt-get update
                        sudo apt-get install -y python3-pip
                    elif command -v yum &>/dev/null; then
                        sudo yum install -y python3-pip
                    else
                        echo -e "${RED}无法自动安装pip，请手动安装${NC}"
                        exit 1
                    fi
                    ;;
                macOS)
                    if command -v brew &>/dev/null; then
                        brew install python3
                    else
                        echo -e "${RED}无法自动安装pip，请手动安装${NC}"
                        exit 1
                    fi
                    ;;
                Windows)
                    echo -e "${YELLOW}在Windows上，请从Python官网下载并安装Python: https://www.python.org/downloads/${NC}"
                    echo -e "${YELLOW}确保在安装时勾选'Add Python to PATH'${NC}"
                    exit 1
                    ;;
                *)
                    echo -e "${RED}无法为未知系统安装pip${NC}"
                    exit 1
                    ;;
            esac
            
            # 重新检查pip
            if command -v pip3 &>/dev/null; then
                PIP_CMD="pip3"
                PIP_VERSION=$($PIP_CMD --version | awk '{print $2}')
                echo -e "${GREEN}pip已安装: $PIP_VERSION${NC}"
            else
                echo -e "${RED}pip安装失败${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${RED}Python未安装，请先安装Python 3.10+${NC}"
        
        case "$OS_TYPE" in
            Linux)
                echo -e "${YELLOW}对于Linux用户:"
                echo -e "Debian/Ubuntu: sudo apt-get install python3.10"
                echo -e "CentOS/RHEL: sudo yum install python3${NC}"
                ;;
            macOS)
                echo -e "${YELLOW}对于macOS用户:"
                echo -e "使用Homebrew: brew install python3${NC}"
                ;;
            Windows)
                echo -e "${YELLOW}对于Windows用户:"
                echo -e "从Python官网下载并安装: https://www.python.org/downloads/"
                echo -e "确保在安装时勾选'Add Python to PATH'${NC}"
                ;;
            *)
                echo -e "${YELLOW}请从Python官网下载并安装: https://www.python.org/downloads/${NC}"
                ;;
        esac
        
        exit 1
    fi
}

# 检查Docker环境
check_docker() {
    echo -e "${BLUE}检查Docker环境...${NC}"
    
    if command -v docker &>/dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
        echo -e "${GREEN}Docker已安装: $DOCKER_VERSION${NC}"
        
        # 检查Docker服务是否运行
        if docker info &>/dev/null; then
            echo -e "${GREEN}Docker服务正在运行${NC}"
        else
            echo -e "${YELLOW}Docker服务未运行${NC}"
            
            # 尝试启动Docker服务
            case "$OS_TYPE" in
                Linux)
                    echo -e "${YELLOW}尝试启动Docker服务...${NC}"
                    if command -v systemctl &>/dev/null; then
                        sudo systemctl start docker
                    elif command -v service &>/dev/null; then
                        sudo service docker start
                    else
                        echo -e "${RED}无法自动启动Docker服务，请手动启动${NC}"
                    fi
                    ;;
                macOS|Windows)
                    echo -e "${YELLOW}请确保Docker Desktop正在运行${NC}"
                    ;;
                *)
                    echo -e "${RED}无法为未知系统启动Docker服务${NC}"
                    ;;
            esac
            
            # 再次检查Docker服务
            if docker info &>/dev/null; then
                echo -e "${GREEN}Docker服务已成功启动${NC}"
            else
                echo -e "${RED}Docker服务启动失败，请手动启动${NC}"
                exit 1
            fi
        fi
        
        # 检查Docker Compose
        if command -v docker-compose &>/dev/null; then
            COMPOSE_VERSION=$(docker-compose --version | grep -o "[0-9]*\.[0-9]*\.[0-9]*" | head -n 1)
            echo -e "${GREEN}Docker Compose已安装: $COMPOSE_VERSION${NC}"
        elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
            COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || docker compose version | grep -o "v[0-9]*\.[0-9]*\.[0-9]*" | sed 's/v//')
            echo -e "${GREEN}Docker Compose插件已安装: $COMPOSE_VERSION${NC}"
        else
            echo -e "${YELLOW}未找到Docker Compose，尝试安装...${NC}"
            
            case "$OS_TYPE" in
                Linux)
                    echo -e "${YELLOW}尝试安装Docker Compose...${NC}"
                    sudo curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                    sudo chmod +x /usr/local/bin/docker-compose
                    ;;
                macOS)
                    if command -v brew &>/dev/null; then
                        brew install docker-compose
                    else
                        echo -e "${YELLOW}请使用Homebrew安装Docker Compose: brew install docker-compose${NC}"
                    fi
                    ;;
                Windows)
                    echo -e "${YELLOW}在Windows上，Docker Compose应该与Docker Desktop一起安装${NC}"
                    echo -e "${YELLOW}如果没有，请重新安装Docker Desktop${NC}"
                    ;;
                *)
                    echo -e "${RED}无法为未知系统安装Docker Compose${NC}"
                    ;;
            esac
            
            # 重新检查Docker Compose
            if command -v docker-compose &>/dev/null; then
                COMPOSE_VERSION=$(docker-compose --version | grep -o "[0-9]*\.[0-9]*\.[0-9]*" | head -n 1)
                echo -e "${GREEN}Docker Compose已安装: $COMPOSE_VERSION${NC}"
            elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
                COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || docker compose version | grep -o "v[0-9]*\.[0-9]*\.[0-9]*" | sed 's/v//')
                echo -e "${GREEN}Docker Compose插件已安装: $COMPOSE_VERSION${NC}"
            else
                echo -e "${YELLOW}无法自动安装Docker Compose，请手动安装${NC}"
                echo -e "${YELLOW}详细说明：https://docs.docker.com/compose/install/${NC}"
            fi
        fi
    else
        echo -e "${RED}Docker未安装${NC}"
        
        # 提供安装Docker的说明
        case "$OS_TYPE" in
            Linux)
                echo -e "${YELLOW}对于Linux用户:"
                echo -e "Debian/Ubuntu: sudo apt-get install docker.io"
                echo -e "CentOS/RHEL: sudo yum install docker"
                echo -e "或按照官方指南: https://docs.docker.com/engine/install/${NC}"
                ;;
            macOS)
                echo -e "${YELLOW}对于macOS用户:"
                echo -e "下载并安装Docker Desktop: https://www.docker.com/products/docker-desktop${NC}"
                ;;
            Windows)
                echo -e "${YELLOW}对于Windows用户:"
                echo -e "下载并安装Docker Desktop: https://www.docker.com/products/docker-desktop${NC}"
                ;;
            *)
                echo -e "${YELLOW}请从Docker官网下载并安装: https://www.docker.com/get-started${NC}"
                ;;
        esac
        
        echo -e "${RED}请安装Docker后再继续${NC}"
        
        read -p "是否继续而不安装Docker? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}安装已取消${NC}"
            exit 1
        fi
    fi
}

# 安装Python依赖
install_python_deps() {
    echo -e "${BLUE}安装Python依赖...${NC}"
    
    # 创建临时的pip缓存清单
    PIP_CACHE_FILE=$(mktemp)
    
    # 获取已安装的包列表
    $PIP_CMD list > "$PIP_CACHE_FILE"
    
    # 检查requirements.txt是否存在
    if [ ! -f "${SCRIPT_DIR}/requirements.txt" ]; then
        echo -e "${RED}错误: requirements.txt文件不存在${NC}"
        echo -e "${YELLOW}创建基本的requirements.txt文件...${NC}"
        
        echo "requests>=2.31.0
pyyaml>=6.0
ccxt>=4.0.0
loguru>=0.7.0
docker>=7.0.0
pytest>=7.0.0" > "${SCRIPT_DIR}/requirements.txt"
        
        echo -e "${GREEN}已创建基本的requirements.txt文件${NC}"
    fi
    
    # 读取requirements.txt文件中的依赖
    MISSING_PACKAGES=()
    while read package; do
        # 忽略空行和注释
        [[ -z "$package" || "$package" =~ ^# ]] && continue
        
        # 提取包名和版本
        PKG_NAME=$(echo "$package" | cut -d'>' -f1 | cut -d'=' -f1 | cut -d'<' -f1 | xargs)
        
        # 特殊处理pyyaml作为yaml模块
        if [ "$PKG_NAME" = "pyyaml" ]; then
            PKG_CHECK_NAME="yaml"
        else
            PKG_CHECK_NAME="$PKG_NAME"
        fi
        
        # 检查包是否已安装 - 先尝试import检查
        if ! $PYTHON_CMD -c "import $PKG_CHECK_NAME" &>/dev/null; then
            # 如果import失败，再检查pip列表
            if ! grep -i "^$PKG_NAME " "$PIP_CACHE_FILE" &>/dev/null; then
                echo -e "${YELLOW}未安装: $package${NC}"
                MISSING_PACKAGES+=("$package")
            else
                echo -e "${GREEN}已安装: $PKG_NAME${NC}"
            fi
        else
            echo -e "${GREEN}已安装: $PKG_NAME${NC}"
        fi
    done < "${SCRIPT_DIR}/requirements.txt"
    
    # 删除临时文件
    rm -f "$PIP_CACHE_FILE"
    
    # 安装缺失的包
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo -e "${YELLOW}安装缺失的Python依赖...${NC}"
        echo -e "${YELLOW}将安装以下包: ${MISSING_PACKAGES[@]}${NC}"
        
        # 安装依赖，使用 --no-cache-dir 避免缓存问题
        $PIP_CMD install --no-cache-dir "${MISSING_PACKAGES[@]}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Python依赖安装成功${NC}"
        else
            echo -e "${RED}Python依赖安装失败${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}所有Python依赖已安装${NC}"
    fi
}

# 检查和配置Docker网络
setup_docker_network() {
    echo -e "${BLUE}配置Docker网络...${NC}"
    
    # 检查是否有Docker网络配置脚本
    if [ -f "$SCRIPTS_PATH/docker-network-setup.sh" ]; then
        echo -e "${YELLOW}使用docker-network-setup.sh配置网络环境...${NC}"
        bash "$SCRIPTS_PATH/docker-network-setup.sh"
    else
        echo -e "${YELLOW}未找到Docker网络配置脚本，使用基本配置...${NC}"
        
        # 检查是否存在cryptosystem_network网络
        if ! docker network ls | grep -q "cryptosystem_network"; then
            echo -e "${YELLOW}创建Docker网络: cryptosystem_network${NC}"
            docker network create cryptosystem_network
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Docker网络创建成功${NC}"
            else
                echo -e "${RED}Docker网络创建失败${NC}"
            fi
        else
            echo -e "${GREEN}Docker网络已存在: cryptosystem_network${NC}"
        fi
    fi
}

# 创建必要的目录
create_directories() {
    echo -e "${BLUE}跳过创建目录...${NC}"
    # 已移除目录创建操作
}

# 询问是否配置包管理源
configure_sources() {
    echo -e "${YELLOW}是否配置npm和pip的源? (y/n)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 检查是否有包管理源配置脚本
        if [ -f "$SCRIPTS_PATH/package-sources.sh" ]; then
            bash "$SCRIPTS_PATH/package-sources.sh"
        else
            echo -e "${RED}错误: package-sources.sh脚本不存在${NC}"
            echo -e "${YELLOW}跳过配置包管理源${NC}"
        fi
    fi
}

# 确认Docker服务配置
confirm_docker_services() {
    echo -e "${BLUE}检查Docker服务配置...${NC}"
    
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${GREEN}找到Docker Compose配置: $DOCKER_COMPOSE_FILE${NC}"
        
        # 提取服务名称
        SERVICES=$(grep -E "^  [a-zA-Z0-9_-]+:" "$DOCKER_COMPOSE_FILE" | sed 's/^  \([a-zA-Z0-9_-]*\):.*$/\1/' | tr '\n' ' ')
        
        echo -e "${CYAN}配置文件中定义的服务:${NC}"
        for service in $SERVICES; do
            echo -e "  - $service"
        done
    else
        echo -e "${YELLOW}未找到Docker Compose配置文件${NC}"
    fi
}

# 显示设置完成信息
show_completion() {
    echo -e "\n${GREEN}=====================================================${NC}"
    echo -e "${GREEN}            环境设置已完成!                 ${NC}"
    echo -e "${GREEN}=====================================================${NC}"
    echo -e "${YELLOW}您现在可以使用以下命令:${NC}"
    echo -e "  - ${CYAN}./start.sh run${NC} - 构建并启动系统"
    echo -e "  - ${CYAN}./start.sh local${NC} - 运行本地测试"
    echo -e "  - ${CYAN}./start.sh build${NC} - 仅构建容器"
    echo -e "  - ${CYAN}./start.sh help${NC} - 显示更多命令"
    echo -e "${GREEN}=====================================================${NC}"
}

# 主函数
main() {
    echo -e "${BLUE}开始设置开发环境...${NC}"
    
    # 检测系统类型
    detect_system
    
    # 检查Python
    check_python
    
    # 安装Python依赖
    install_python_deps
    
    # 检查Docker
    check_docker
    
    # 创建必要的目录
    create_directories
    
    # 询问是否配置包管理源
    configure_sources
    
    # 设置Docker网络
    setup_docker_network
    
    # 确认Docker服务配置
    confirm_docker_services
    
    # 显示设置完成信息
    show_completion
}

# 执行主函数
main "$@" 