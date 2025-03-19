#!/bin/bash

# Docker系统清理脚本
# 用于清理所有未使用的Docker资源

# 获取颜色变量（如果从start.sh调用则已导出这些变量）
RED=${RED:-'\033[0;31m'}
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[0;33m'}
BLUE=${BLUE:-'\033[0;34m'}
NC=${NC:-'\033[0m'} # No Color

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   Docker系统清理工具   ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 询问用户确认
echo -e "${YELLOW}警告：此操作将删除：${NC}"
echo -e " - 所有未使用的容器"
echo -e " - 所有未使用的网络"
echo -e " - 所有未使用的镜像"
echo -e " - 所有未挂载的卷"
echo -e " - 所有构建缓存"
echo -e "${YELLOW}这将释放大量磁盘空间，但会清除所有不活动的资源。${NC}"
echo -e "${YELLOW}已启动的容器和其镜像不会被删除。${NC}"

# 判断是否传入了-f或--force参数
if [[ "$1" == "-f" || "$1" == "--force" ]]; then
    FORCE=true
else
    FORCE=false
fi

# 如果不是强制模式，询问确认
if [ "$FORCE" != true ]; then
    read -p "确认执行清理操作？ (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消${NC}"
        exit 0
    fi
fi

echo -e "${YELLOW}开始清理Docker系统...${NC}"

# 显示清理前的磁盘使用情况
echo -e "${BLUE}清理前Docker磁盘使用情况:${NC}"
docker system df

# 执行清理
echo -e "${YELLOW}执行Docker系统清理...${NC}"
docker system prune -a -f

# 显示清理后的磁盘使用情况
echo -e "${BLUE}清理后Docker磁盘使用情况:${NC}"
docker system df

echo -e "${GREEN}Docker系统清理完成!${NC}"