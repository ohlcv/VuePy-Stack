#!/bin/bash

# Docker网络修复脚本 - docker-network-fix.sh
# 用于检测和解决Docker网络连接问题

# 如果未从父脚本接收颜色变量，则设置默认值
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# 检查Docker是否正在运行
check_docker_running() {
    echo -e "${BLUE}检查Docker服务状态...${NC}"
    
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}错误: Docker未安装${NC}"
        echo -e "${YELLOW}请先安装Docker: https://docs.docker.com/get-docker/${NC}"
        return 1
    fi
    
    # 使用docker info命令检查Docker是否运行
    if ! docker info &>/dev/null; then
        echo -e "${RED}Docker服务未运行${NC}"
        echo -e "${YELLOW}尝试启动Docker服务...${NC}"
        
        # 检测操作系统并尝试启动Docker
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo systemctl start docker || sudo service docker start
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}请手动打开Docker Desktop应用程序${NC}"
            read -p "Docker启动后按回车继续..."
        elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
            echo -e "${YELLOW}请手动打开Docker Desktop应用程序${NC}"
            read -p "Docker启动后按回车继续..."
        fi
        
        # 再次检查Docker是否运行
        if ! docker info &>/dev/null; then
            echo -e "${RED}无法启动Docker服务，请手动检查问题${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}Docker服务正在运行${NC}"
    return 0
}

# 检查Docker网络
check_docker_network() {
    echo -e "${BLUE}检查Docker网络状态...${NC}"
    
    # 列出所有网络
    echo -e "${CYAN}当前Docker网络列表:${NC}"
    docker network ls
    
    # 检查默认bridge网络
    echo -e "\n${CYAN}检查默认bridge网络:${NC}"
    BRIDGE_STATUS=$(docker network inspect bridge --format "{{.Driver}} {{.Scope}}" 2>/dev/null)
    
    if [ -z "$BRIDGE_STATUS" ]; then
        echo -e "${RED}默认bridge网络不存在或无法访问${NC}"
        return 1
    else
        echo -e "${GREEN}默认bridge网络状态正常: $BRIDGE_STATUS${NC}"
    fi
    
    # 检查是否有自定义网络
    PROJECT_NETWORK=$(docker network ls --filter "name=crypto-grid" --format "{{.Name}}" | head -n 1)
    
    if [ -n "$PROJECT_NETWORK" ]; then
        echo -e "\n${CYAN}检查项目网络 $PROJECT_NETWORK:${NC}"
        docker network inspect "$PROJECT_NETWORK" --format "{{.Driver}} {{.Scope}}"
    else
        echo -e "${YELLOW}未找到项目相关的自定义网络${NC}"
    fi
    
    return 0
}

# 测试Docker网络连接
test_docker_network() {
    echo -e "${BLUE}测试Docker网络连接...${NC}"
    
    echo -e "${CYAN}创建测试容器...${NC}"
    docker run --rm --name network-test-1 -d alpine:latest sleep 30
    docker run --rm --name network-test-2 -d alpine:latest sleep 30
    
    sleep 2
    
    echo -e "${CYAN}测试容器间通信...${NC}"
    PING_RESULT=$(docker exec network-test-1 ping -c 2 network-test-2 2>&1)
    
    # 清理测试容器
    docker stop network-test-1 network-test-2 &>/dev/null
    
    if echo "$PING_RESULT" | grep -q "bytes from"; then
        echo -e "${GREEN}网络连接测试成功！容器间可以通信${NC}"
        NETWORK_OK=true
    else
        echo -e "${RED}网络连接测试失败！容器间无法通信${NC}"
        echo -e "${YELLOW}错误信息: $PING_RESULT${NC}"
        NETWORK_OK=false
    fi
    
    return 0
}

# 重置Docker网络
reset_docker_network() {
    echo -e "${YELLOW}警告: 即将重置Docker网络，这将断开所有运行中容器的网络连接${NC}"
    echo -e "${YELLOW}是否继续? (y/n)${NC}"
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}停止所有正在运行的容器...${NC}"
        docker stop $(docker ps -q) 2>/dev/null || true
        
        echo -e "${BLUE}重置Docker网络...${NC}"
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo -e "${CYAN}在Linux上重启Docker服务...${NC}"
            sudo systemctl restart docker || sudo service docker restart
        elif [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
            echo -e "${CYAN}在Windows/Mac上重启Docker...${NC}"
            echo -e "${YELLOW}请手动重启Docker Desktop应用程序${NC}"
            read -p "Docker重启后按回车继续..."
        fi
        
        echo -e "${GREEN}Docker网络已重置${NC}"
    else
        echo -e "${YELLOW}操作已取消${NC}"
    fi
    
    return 0
}

# 删除并重建项目网络
recreate_project_network() {
    echo -e "${BLUE}删除并重建项目网络...${NC}"
    
    # 检查项目的docker-compose文件
    DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${RED}错误: 未找到docker-compose.yml文件${NC}"
        return 1
    fi
    
    # 查找项目网络名称
    PROJECT_NETWORK=$(grep -A 5 "networks:" "$DOCKER_COMPOSE_FILE" | grep -v "networks:" | awk '{print $1}' | head -n 1 | tr -d ':')
    
    if [ -z "$PROJECT_NETWORK" ]; then
        echo -e "${RED}未在docker-compose.yml中找到网络定义${NC}"
        PROJECT_NETWORK="trading-net"  # 使用默认名称
    fi
    
    echo -e "${CYAN}项目网络名称: $PROJECT_NETWORK${NC}"
    
    # 停止所有相关容器
    echo -e "${CYAN}停止所有相关容器...${NC}"
    if command -v docker-compose &>/dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        DOCKER_COMPOSE_CMD="docker compose"
    fi
    
    $DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" down || true
    
    # 删除网络
    echo -e "${CYAN}删除网络 $PROJECT_NETWORK...${NC}"
    docker network rm "$PROJECT_NETWORK" 2>/dev/null || true
    
    # 创建网络
    echo -e "${CYAN}重新创建网络 $PROJECT_NETWORK...${NC}"
    docker network create "$PROJECT_NETWORK"
    
    echo -e "${GREEN}项目网络已重建${NC}"
    echo -e "${YELLOW}现在可以使用 ./start.sh up 重新启动容器${NC}"
    
    return 0
}

# 修复IP地址分配问题
fix_ip_allocation() {
    echo -e "${BLUE}修复IP地址分配问题...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${CYAN}清理Docker IPAM数据...${NC}"
        
        echo -e "${YELLOW}警告: 此操作需要sudo权限${NC}"
        
        # 停止Docker
        sudo systemctl stop docker || sudo service docker stop
        
        # 备份目录
        BACKUP_DIR="/tmp/docker_ipam_backup_$(date +%Y%m%d%H%M%S)"
        sudo mkdir -p "$BACKUP_DIR"
        
        # 备份并清理数据
        sudo cp -r /var/lib/docker/network "$BACKUP_DIR/"
        echo -e "${GREEN}已备份网络数据到 $BACKUP_DIR${NC}"
        
        # 删除网络配置文件
        sudo rm -rf /var/lib/docker/network/files/local-kv.db
        
        # 启动Docker
        sudo systemctl start docker || sudo service docker start
        
        echo -e "${GREEN}IP分配问题已修复${NC}"
    else
        echo -e "${YELLOW}在非Linux系统上，请使用Docker Desktop应用程序的'Reset to factory defaults'选项${NC}"
        echo -e "${YELLOW}注意: 这将删除所有容器、镜像和设置${NC}"
    fi
    
    return 0
}

# 修复DNS问题
fix_dns_issues() {
    echo -e "${BLUE}修复Docker DNS问题...${NC}"
    
    # 检查当前DNS设置
    echo -e "${CYAN}当前DNS设置:${NC}"
    docker run --rm alpine:latest cat /etc/resolv.conf
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${CYAN}配置Docker守护进程DNS...${NC}"
        
        # 创建或修改Docker守护进程配置
        if [ ! -d "/etc/docker" ]; then
            sudo mkdir -p /etc/docker
        fi
        
        echo -e "${YELLOW}是否使用Google DNS (8.8.8.8, 8.8.4.4)? (y/n)${NC}"
        read -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo '{"dns": ["8.8.8.8", "8.8.4.4"]}' | sudo tee /etc/docker/daemon.json
            echo -e "${GREEN}已配置为使用Google DNS${NC}"
        else
            echo -e "${YELLOW}请输入首选DNS服务器IP (如: 114.114.114.114):${NC}"
            read DNS1
            echo -e "${YELLOW}请输入备用DNS服务器IP (可选，按回车跳过):${NC}"
            read DNS2
            
            if [ -n "$DNS2" ]; then
                echo "{\"dns\": [\"$DNS1\", \"$DNS2\"]}" | sudo tee /etc/docker/daemon.json
            else
                echo "{\"dns\": [\"$DNS1\"]}" | sudo tee /etc/docker/daemon.json
            fi
            
            echo -e "${GREEN}已配置自定义DNS${NC}"
        fi
        
        # 重启Docker
        echo -e "${CYAN}重启Docker以应用DNS设置...${NC}"
        sudo systemctl restart docker || sudo service docker restart
        
        # 验证设置
        echo -e "${CYAN}新的DNS设置:${NC}"
        sleep 2
        docker run --rm alpine:latest cat /etc/resolv.conf
    else
        echo -e "${YELLOW}在非Linux系统上，请通过Docker Desktop设置DNS${NC}"
        echo -e "${YELLOW}打开Docker Desktop -> Settings -> Docker Engine，添加如下配置:${NC}"
        echo -e "${CYAN}\"dns\": [\"8.8.8.8\", \"8.8.4.4\"]${NC}"
    fi
    
    return 0
}

# 主函数
main() {
    echo -e "${BLUE}Docker网络诊断和修复工具${NC}"
    
    # 检查Docker是否运行
    check_docker_running || exit 1
    
    # 检查Docker网络状态
    check_docker_network
    
    # 测试Docker网络连接
    test_docker_network
    
    if [ "$NETWORK_OK" = true ]; then
        echo -e "${GREEN}Docker网络状态良好${NC}"
        echo -e "${YELLOW}是否仍要执行修复操作? (y/n)${NC}"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}退出，无需修复${NC}"
            exit 0
        fi
    fi
    
    echo -e "\n${BLUE}可用的修复选项:${NC}"
    echo -e "${CYAN}1. 重置Docker网络${NC}"
    echo -e "${CYAN}2. 删除并重建项目网络${NC}"
    echo -e "${CYAN}3. 修复IP地址分配问题${NC}"
    echo -e "${CYAN}4. 修复DNS问题${NC}"
    echo -e "${CYAN}0. 退出${NC}"
    
    echo -e "${YELLOW}请选择要执行的操作 (0-4):${NC}"
    read -n 1 -r
    echo
    
    case $REPLY in
        1)
            reset_docker_network
            ;;
        2)
            recreate_project_network
            ;;
        3)
            fix_ip_allocation
            ;;
        4)
            fix_dns_issues
            ;;
        0)
            echo -e "${GREEN}已退出${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}修复操作完成${NC}"
    echo -e "${YELLOW}建议使用 ./start.sh restart 重启项目容器${NC}"
}

# 执行主函数
main "$@" 