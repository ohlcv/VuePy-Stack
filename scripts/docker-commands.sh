#!/bin/bash

# 加密货币网格交易系统 - Docker命令脚本
# 功能：处理所有Docker相关操作，如构建、启动、停止容器等

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# 导入通用变量和函数（如果它们是从父脚本导出的）
if [ -z "$GREEN" ]; then
    # 如果变量未定义，设置默认颜色
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
fi

# 切换到项目根目录
cd "$PARENT_DIR" || { echo -e "${RED}无法切换到项目目录: $PARENT_DIR${NC}"; exit 1; }

# 定义Docker Compose文件位置
DOCKER_COMPOSE_FILE="./docker-compose.yml"

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker未安装!${NC}"
        echo -e "${YELLOW}请先安装Docker: https://docs.docker.com/get-docker/${NC}"
        exit 1
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        echo -e "${RED}Docker未运行!${NC}"
        echo -e "${YELLOW}请启动Docker服务${NC}"
        exit 1
    fi
    
    # 检查Docker Compose是否安装
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}警告: 未检测到docker-compose命令${NC}"
        echo -e "${YELLOW}将尝试使用Docker Compose插件 (docker compose)${NC}"
        USE_COMPOSE_PLUGIN=true
    else
        USE_COMPOSE_PLUGIN=false
    fi
    
    # 检查docker-compose.yml文件是否存在
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${RED}错误: $DOCKER_COMPOSE_FILE文件不存在${NC}"
        echo -e "${YELLOW}请确保您在正确的项目目录中${NC}"
        exit 1
    fi
}

# 运行docker-compose命令
run_compose() {
    if [ "$USE_COMPOSE_PLUGIN" = true ]; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

# 构建Docker镜像
build_images() {
    echo -e "${BLUE}构建Docker镜像...${NC}"
    run_compose build "$@"
}

# 启动Docker容器
start_containers() {
    echo -e "${BLUE}启动Docker容器...${NC}"
    run_compose up -d "$@"
}

# 停止并移除Docker容器
stop_containers() {
    echo -e "${BLUE}停止并移除Docker容器...${NC}"
    run_compose down "$@"
}

# 重启Docker容器
restart_containers() {
    echo -e "${BLUE}重启Docker容器...${NC}"
    run_compose restart "$@"
}

# 查看Docker容器日志
view_logs() {
    echo -e "${BLUE}查看Docker容器日志...${NC}"
    run_compose logs "$@"
}

# 显示Docker容器状态
show_status() {
    echo -e "${BLUE}显示所有容器状态...${NC}"
    
    echo -e "${CYAN}Docker容器:${NC}"
    echo -e "NAMES\tSTATUS\tPORTS"
    docker ps --format "{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo -e "${YELLOW}没有运行中的容器${NC}"
    
    echo -e "\n${CYAN}Hummingbot策略:${NC}"
    echo -e "NAMES\tSTATUS\tCREATED AT"
    docker ps --filter "name=hummingbot_" --format "{{.Names}}\t{{.Status}}\t{{.CreatedAt}}" 2>/dev/null || echo -e "${YELLOW}没有运行中的Hummingbot容器${NC}"
}

# 启动客户端容器
start_client() {
    echo -e "${BLUE}启动客户端容器...${NC}"
    run_compose up -d client
}

# 启动Hummingbot容器
start_hummingbot() {
    # 检查参数
    if [ $# -lt 1 ]; then
        echo -e "${RED}错误: 缺少策略ID参数${NC}"
        echo -e "${YELLOW}用法: ./start.sh hummingbot <策略ID>${NC}"
        exit 1
    fi
    
    STRATEGY_ID=$1
    STRATEGY_DIR="./strategy_files/${STRATEGY_ID}"
    
    echo -e "${BLUE}启动Hummingbot容器(策略ID: $STRATEGY_ID)...${NC}"
    
    # 启动Hummingbot容器
    CONTAINER_NAME="hummingbot_${STRATEGY_ID}"
    
    # 检查容器是否已存在
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}容器 $CONTAINER_NAME 已存在${NC}"
        
        # 检查容器是否正在运行
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "${YELLOW}容器 $CONTAINER_NAME 已在运行中${NC}"
            return 0
        else
            echo -e "${YELLOW}正在启动已存在的容器 $CONTAINER_NAME...${NC}"
            docker start $CONTAINER_NAME
            return $?
        fi
    else
        echo -e "${YELLOW}创建并启动新容器 $CONTAINER_NAME...${NC}"
        docker run -d --name $CONTAINER_NAME \
            -v "$(pwd)/${STRATEGY_DIR}:/conf" \
            --network host \
            hummingbot/hummingbot:latest
        
        return $?
    fi
}

# 清理Docker系统
docker_prune() {
    echo -e "${BLUE}清理Docker系统...${NC}"
    
    # 确认用户真的想清理
    echo -e "${YELLOW}警告: 此操作将删除未使用的容器、网络、镜像和缓存${NC}"
    read -p "确定要继续吗? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消清理操作${NC}"
        return 0
    fi
    
    # 移除已停止的容器
    echo -e "${YELLOW}移除已停止的容器...${NC}"
    docker container prune -f
    
    # 移除未使用的网络
    echo -e "${YELLOW}移除未使用的网络...${NC}"
    docker network prune -f
    
    # 移除悬空镜像
    echo -e "${YELLOW}移除悬空镜像...${NC}"
    docker image prune -f
    
    # 移除未使用的数据卷
    echo -e "${YELLOW}移除未使用的数据卷...${NC}"
    docker volume prune -f
    
    echo -e "${GREEN}Docker系统清理完成${NC}"
}

# 预处理函数
preprocess() {
    # 检查Docker环境
    check_docker
}

# 主命令处理
main() {
    # 处理参数
    COMMAND=$1
    shift  # 移除第一个参数(命令名)
    
    # 进行前置检查
    preprocess
    
    # 处理命令
    case "$COMMAND" in
        build)
            build_images "$@"
            ;;
        build-up)
            build_images "$@" && start_containers "$@"
            ;;
        up)
            start_containers "$@"
            ;;
        down)
            stop_containers "$@"
            ;;
        restart)
            restart_containers "$@"
            ;;
        logs)
            view_logs "$@"
            ;;
        status)
            show_status
            ;;
        client)
            start_client
            ;;
        hummingbot)
            start_hummingbot "$@"
            ;;
        prune)
            docker_prune
            ;;
        *)
            echo -e "${RED}未知的Docker命令: $COMMAND${NC}"
            echo -e "${YELLOW}可用的命令:${NC}"
            echo -e "  build       - 构建所有镜像"
            echo -e "  build-up    - 构建并启动所有容器"
            echo -e "  up          - 启动所有容器"
            echo -e "  down        - 停止并移除所有容器"
            echo -e "  restart     - 重启所有容器"
            echo -e "  logs        - 查看容器日志"
            echo -e "  status      - 显示容器状态"
            echo -e "  client      - 启动客户端容器"
            echo -e "  hummingbot  - 启动Hummingbot容器"
            echo -e "  prune       - 清理Docker系统"
            exit 1
            ;;
    esac
    
    return $?
}

# 如果脚本被直接调用(而不是被source)，则运行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi