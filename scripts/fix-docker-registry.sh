#!/bin/bash

# Docker镜像源优化工具 - 增强版 2.0
# 用于测试各Docker镜像源的连接情况和速度，并配置最快的源

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 设置要测试的镜像源列表
MIRROR_SOURCES=(
    "https://registry.hub.docker.com"  # Docker官方源
    "https://mirror.baidubce.com"      # 百度云加速器
    "https://hub-mirror.c.163.com"     # 网易云加速器
    "https://docker.mirrors.ustc.edu.cn" # 中国科学技术大学开源软件镜像站
    "https://registry.docker-cn.com"   # Docker中国官方镜像
    "https://dockerhub.azk8s.cn"       # Azure中国镜像
)


# 标题
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Docker镜像源优化工具 - 增强版 2.0    ${NC}"
echo -e "${BLUE}=========================================${NC}"

# 检测是否安装了Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 未检测到Docker安装${NC}"
    echo -e "${YELLOW}请先安装Docker后再运行此脚本${NC}"
    exit 1
fi

# 测试Docker是否运行
if ! docker info &> /dev/null; then
    echo -e "${RED}错误: Docker未运行${NC}"
    echo -e "${YELLOW}请先启动Docker服务后再运行此脚本${NC}"
    exit 1
fi

echo -e "${CYAN}当前Docker信息:${NC}"
docker --version

# 获取当前镜像源配置
echo -e "\n${CYAN}当前镜像源配置:${NC}"
docker info | grep -A 10 "Registry Mirrors" || echo "未配置镜像源"

# 测试镜像源连接和速度
echo -e "\n${CYAN}开始测试各镜像源连接情况和速度...${NC}"

# 创建结果数组存储可连接的源和它们的速度
declare -A results

for mirror in "${MIRROR_SOURCES[@]}"; do
    echo -e "\n${YELLOW}测试镜像源: ${mirror}${NC}"
    
    # 测试连接 - 尝试使用curl请求
    domain=$(echo "$mirror" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    echo -e "${CYAN}尝试连接到域名: ${domain}${NC}"
    
    # 使用curl测试连接 (5秒超时)
    curl_start=$(date +%s)
    if curl -s --connect-timeout 5 --max-time 5 -I "$mirror" > /dev/null 2>&1; then
        curl_end=$(date +%s)
        curl_time=$((curl_end - curl_start))
        echo -e "${GREEN}✓ 连接成功! 响应时间: ${curl_time}秒${NC}"
        
        # 测试拉取小镜像的速度
        echo -e "${CYAN}测试镜像拉取速度...${NC}"
        # 确保没有hello-world镜像
        docker rmi hello-world > /dev/null 2>&1 || true
        
        # 配置临时Docker配置使用当前测试的源
        if [[ "$mirror" != "https://registry.hub.docker.com" ]]; then
            # 非官方源需要配置registry-mirrors
            config_file="${HOME}/.docker/daemon.json.test"
            mkdir -p "${HOME}/.docker" 2>/dev/null || true
            echo "{\"registry-mirrors\": [\"$mirror\"]}" > "$config_file"
            
            # 在Windows上需要手动应用,无法在脚本中立即生效
            echo -e "${YELLOW}请在另一个终端中重启Docker后再继续...${NC}"
            if [[ "$OS" == "MINGW"* || "$OS" == "MSYS"* ]]; then
                echo -e "${YELLOW}请手动将以下配置复制到Docker Desktop设置中:${NC}"
                cat "$config_file"
                echo -e "${YELLOW}应用配置后按任意键继续...${NC}"
                read -n 1
            fi
        fi
        
        # 测试拉取镜像
        pull_start=$(date +%s)
        if docker pull hello-world > /dev/null 2>&1; then
            pull_end=$(date +%s)
            pull_time=$((pull_end - pull_start))
            echo -e "${GREEN}✓ 镜像拉取成功! 耗时: ${pull_time}秒${NC}"
            
            # 记录结果 - 综合评分 (连接时间+拉取时间)
            total_time=$((curl_time + pull_time))
            results["$mirror"]=$total_time
            
            # 清理测试镜像
            docker rmi hello-world > /dev/null 2>&1 || true
        else
            echo -e "${RED}✗ 镜像拉取失败${NC}"
        fi
    else
        echo -e "${RED}✗ 连接失败${NC}"
    fi
done

# 分析结果并找出最快的源
echo -e "\n${CYAN}镜像源测试结果:${NC}"
best_mirror=""
best_time=999999

for mirror in "${!results[@]}"; do
    time=${results["$mirror"]}
    echo -e "${mirror}: ${time}秒"
    
    # 判断是否是最快的源
    if [[ $time -lt $best_time ]]; then
        best_time=$time
        best_mirror=$mirror
    fi
    
    # 如果官方源可以连接，优先使用官方源
    if [[ "$mirror" == "https://registry.hub.docker.com" && $time -lt 999999 ]]; then
        echo -e "${GREEN}官方源可用，将优先使用${NC}"
        best_mirror=$mirror
        break
    fi
done

# 如果找到了最快的源，进行配置
if [[ -n "$best_mirror" ]]; then
    echo -e "\n${GREEN}最快的镜像源是: ${best_mirror} (${best_time}秒)${NC}"
    
    # 检测操作系统
    OS=$(uname -s)
    echo -e "\n${CYAN}检测到操作系统: ${OS}${NC}"
    
    # 根据操作系统类型配置最快的源
    case "$OS" in
        Linux)
            # Linux系统
            sudo mkdir -p /etc/docker
            echo '{
  "registry-mirrors": ["'$best_mirror'"]
}' | sudo tee /etc/docker/daemon.json
            echo -e "${GREEN}Docker镜像源已配置为 ${best_mirror}${NC}"
            sudo systemctl restart docker
            ;;
            
        Darwin)
            # macOS系统
            echo -e "${YELLOW}请手动配置Docker Desktop:${NC}"
            echo -e "1. 打开Docker Desktop"
            echo -e "2. 点击右上角的设置图标"
            echo -e "3. 选择'Docker Engine'"
            echo -e "4. 添加以下配置:"
            echo -e '{
  "registry-mirrors": ["'$best_mirror'"]
}'
            echo -e "5. 点击'Apply & Restart'"
            ;;
            
        MINGW*|MSYS*|CYGWIN*)
            # Windows系统
            config_path="$HOME/.docker/daemon.json"
            mkdir -p "$(dirname "$config_path")"
            echo '{
  "registry-mirrors": ["'$best_mirror'"]
}' > "$config_path"
            echo -e "${GREEN}配置已写入 ${config_path}${NC}"
            echo -e "${YELLOW}请重启Docker Desktop以应用更改${NC}"
            ;;
            
        *)
            echo -e "${RED}不支持的操作系统: $OS${NC}"
            ;;
    esac
    
    # 修改docker-compose.yml中的镜像源
    echo -e "\n${CYAN}是否修改docker-compose.yml使用最快的镜像源? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # 查找docker-compose.yml文件
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
        COMPOSE_FILE=""
        
        for potential_path in "$SCRIPT_DIR/../docker-compose.yml" "$SCRIPT_DIR/docker-compose.yml"; do
            if [[ -f "$potential_path" ]]; then
                COMPOSE_FILE="$potential_path"
                break
            fi
        done
        
        if [[ -n "$COMPOSE_FILE" ]]; then
            echo -e "${GREEN}找到docker-compose.yml文件: $COMPOSE_FILE${NC}"
            
            # 备份原始文件
            cp "$COMPOSE_FILE" "${COMPOSE_FILE}.bak"
            echo -e "${GREEN}已备份原始文件${NC}"
            
            # 根据最快的源修改镜像引用
            if [[ "$best_mirror" == "https://registry.hub.docker.com" ]]; then
                # 使用官方镜像
                sed -i.tmp 's|registry.cn-hangzhou.aliyuncs.com/hummingbot/hummingbot|hummingbot/hummingbot|g' "$COMPOSE_FILE"
                sed -i.tmp 's|registry.cn-hangzhou.aliyuncs.com/google_containers/python|python|g' "$COMPOSE_FILE"
                sed -i.tmp 's|registry.cn-hangzhou.aliyuncs.com/library/node|node|g' "$COMPOSE_FILE"
            else
                # 使用镜像源
                mirror_domain=$(echo "$best_mirror" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
                sed -i.tmp 's|hummingbot/hummingbot|'$mirror_domain'/hummingbot/hummingbot|g' "$COMPOSE_FILE"
                sed -i.tmp 's|python:3.10|'$mirror_domain'/google_containers/python:3.10|g' "$COMPOSE_FILE"
                sed -i.tmp 's|node:20-slim|'$mirror_domain'/library/node:20-slim|g' "$COMPOSE_FILE"
            fi
            
            rm -f "${COMPOSE_FILE}.tmp"
            echo -e "${GREEN}docker-compose.yml已更新为使用${best_mirror}${NC}"
        else
            echo -e "${RED}未找到docker-compose.yml文件${NC}"
        fi
    fi
else
    echo -e "\n${RED}没有找到可用的镜像源${NC}"
    echo -e "${YELLOW}请检查网络连接或手动配置Docker镜像源${NC}"
fi

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Docker镜像源测试与配置完成!${NC}"
echo -e "${GREEN}=========================================${NC}"