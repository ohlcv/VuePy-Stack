#!/bin/bash

# 加密货币网格交易系统 - 运行脚本
# 功能：构建并启动整个系统

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
    NC='\033[0m' # No Color
fi

# 确保使用当前路径
cd "$PARENT_DIR" || { echo -e "${RED}无法切换到项目目录: $PARENT_DIR${NC}"; exit 1; }

# 显示标题
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}     运行加密货币网格交易系统 - 开发模式     ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 检查环境
echo -e "${YELLOW}检查Docker环境...${NC}"
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

# 默认为开发模式
MODE="dev"
if [ "$1" == "prod" ]; then
    MODE="prod"
    echo -e "${YELLOW}使用生产模式${NC}"
else
    echo -e "${YELLOW}使用开发模式${NC}"
fi

# 启动客户端应用
echo -e "${GREEN}启动客户端应用...${NC}"
cd client || { echo -e "${RED}无法切换到client目录${NC}"; exit 1; }

# 在开发模式下使用 npm run dev
if [ "$MODE" == "dev" ]; then
    echo -e "${YELLOW}使用Vite开发服务器${NC}"
    # 在后台运行开发服务器
    npm run dev -- --host &
    DEV_SERVER_PID=$!
    
    echo -e "${YELLOW}开发服务器已启动 (PID: $DEV_SERVER_PID)${NC}"
    echo -e "${YELLOW}请等待几秒钟，让开发服务器完全启动${NC}"
    sleep 5
    
    # 使用Electron开发模式
    echo -e "${GREEN}启动Electron应用...${NC}"
    npm run electron:dev
    
    # 结束开发服务器
    kill $DEV_SERVER_PID 2>/dev/null
else
    # 生产模式 - 构建并运行
    echo -e "${YELLOW}构建生产版本${NC}"
    npm run build
    
    echo -e "${GREEN}启动Electron应用...${NC}"
    npm run electron
fi

echo -e "${GREEN}系统已关闭${NC}"
exit 0 