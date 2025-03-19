#!/bin/bash

# 加密货币网格交易系统 - 应用部署脚本
# 功能：部署和发布应用程序到指定位置或服务器

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
echo -e "${BLUE}  加密货币网格交易系统 - 应用部署工具       ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 切换到项目根目录
cd "$PARENT_DIR" || { echo -e "${RED}无法切换到项目目录: $PARENT_DIR${NC}"; exit 1; }

# 默认部署配置
DEPLOY_TARGET="local"  # 默认部署到本地目录
DEPLOY_DIR="$PARENT_DIR/deploy"  # 默认部署目录
VERSION=""  # 版本号
PACKAGE_TYPE="exe"  # 默认打包类型，可选值: exe, zip, all
RELEASE_NOTES=""  # 发布说明
REMOTE_HOST=""  # 远程服务器主机名
REMOTE_USER=""  # 远程服务器用户名
REMOTE_PATH=""  # 远程服务器路径

# 处理命令行参数
for i in "$@"; do
    case $i in
        --target=*)
            DEPLOY_TARGET="${i#*=}"
            ;;
        --dir=*)
            DEPLOY_DIR="${i#*=}"
            ;;
        --version=*)
            VERSION="${i#*=}"
            ;;
        --type=*)
            PACKAGE_TYPE="${i#*=}"
            ;;
        --notes=*)
            RELEASE_NOTES="${i#*=}"
            ;;
        --host=*)
            REMOTE_HOST="${i#*=}"
            ;;
        --user=*)
            REMOTE_USER="${i#*=}"
            ;;
        --path=*)
            REMOTE_PATH="${i#*=}"
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --target=TARGET    部署目标 (local, remote, github)"
            echo "  --dir=DIR          本地部署目录"
            echo "  --version=VERSION  手动指定版本号 (默认从package.json获取)"
            echo "  --type=TYPE        打包类型 (exe, zip, all)"
            echo "  --notes=NOTES      发布说明文件路径"
            echo "  --host=HOST        远程服务器主机名"
            echo "  --user=USER        远程服务器用户名"
            echo "  --path=PATH        远程服务器路径"
            echo "  --help             显示此帮助信息"
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $i${NC}"
            echo "使用 --help 查看可用选项"
            exit 1
            ;;
    esac
done

# 如果未指定版本号，则从package.json获取
if [ -z "$VERSION" ]; then
    if [ -f "./client/package.json" ]; then
        VERSION=$(grep -o '"version": "[^"]*"' ./client/package.json | head -1 | cut -d'"' -f4)
        echo -e "${YELLOW}从package.json获取的版本号: $VERSION${NC}"
    else
        echo -e "${RED}错误: 未找到client/package.json文件且未指定版本号${NC}"
        exit 1
    fi
fi

# 检查打包文件
echo -e "${YELLOW}跳过检查打包文件${NC}"

# 创建部署目录
mkdir -p "$DEPLOY_DIR/v$VERSION"

# 复制打包文件到部署目录
echo -e "${CYAN}复制打包文件到部署目录...${NC}"

# 检查要复制的文件类型
EXE_FILE="./dist/加密货币网格交易系统 Setup $VERSION.exe"
ZIP_FILE="./dist/加密货币网格交易系统-便携版-$VERSION.zip"
COPY_SUCCESS=false

if [ "$PACKAGE_TYPE" = "exe" ] || [ "$PACKAGE_TYPE" = "all" ]; then
    if [ -f "$EXE_FILE" ]; then
        cp "$EXE_FILE" "$DEPLOY_DIR/v$VERSION/"
        echo -e "${GREEN}已复制安装程序到: $DEPLOY_DIR/v$VERSION/$(basename "$EXE_FILE")${NC}"
        COPY_SUCCESS=true
    else
        echo -e "${YELLOW}警告: 未找到安装程序: $EXE_FILE${NC}"
    fi
fi

if [ "$PACKAGE_TYPE" = "zip" ] || [ "$PACKAGE_TYPE" = "all" ]; then
    if [ -f "$ZIP_FILE" ]; then
        cp "$ZIP_FILE" "$DEPLOY_DIR/v$VERSION/"
        echo -e "${GREEN}已复制便携版到: $DEPLOY_DIR/v$VERSION/$(basename "$ZIP_FILE")${NC}"
        COPY_SUCCESS=true
    else
        echo -e "${YELLOW}警告: 未找到便携版: $ZIP_FILE${NC}"
    fi
fi

if [ "$COPY_SUCCESS" = false ]; then
    echo -e "${RED}错误: 未找到任何打包文件${NC}"
    exit 1
fi

# 创建发布说明
if [ -n "$RELEASE_NOTES" ] && [ -f "$RELEASE_NOTES" ]; then
    cp "$RELEASE_NOTES" "$DEPLOY_DIR/v$VERSION/release-notes.md"
else
    # 创建默认发布说明
    cat > "$DEPLOY_DIR/v$VERSION/release-notes.md" << EOF
# 加密货币网格交易系统 v$VERSION 发布说明

## 版本信息
- 版本号: $VERSION
- 发布日期: $(date +"%Y-%m-%d")

## 更新内容
- 功能更新和Bug修复

## 安装说明
1. 下载并运行安装程序
2. 按照提示完成安装

## 系统要求
- Windows 10 或更高版本
- 4GB RAM 或更多
- 500MB 可用磁盘空间
EOF
    echo -e "${YELLOW}已创建默认发布说明: $DEPLOY_DIR/v$VERSION/release-notes.md${NC}"
fi

# 根据部署目标执行不同的部署操作
case "$DEPLOY_TARGET" in
    local)
        echo -e "${GREEN}已成功部署到本地目录: $DEPLOY_DIR/v$VERSION/${NC}"
        
        # 创建最新版本的符号链接
        if [ -d "$DEPLOY_DIR/latest" ]; then
            rm -rf "$DEPLOY_DIR/latest"
        fi
        ln -sf "$DEPLOY_DIR/v$VERSION" "$DEPLOY_DIR/latest"
        echo -e "${GREEN}已更新最新版本链接: $DEPLOY_DIR/latest/${NC}"
        ;;
        
    remote)
        # 检查远程部署信息
        if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_PATH" ]; then
            echo -e "${RED}错误: 远程部署需要指定主机名、用户名和路径${NC}"
            exit 1
        fi
        
        echo -e "${CYAN}部署到远程服务器: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH${NC}"
        
        # 确保远程目录存在
        ssh "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_PATH/v$VERSION"
        
        # 上传文件
        scp "$DEPLOY_DIR/v$VERSION/"* "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/v$VERSION/"
        
        # 更新最新版本链接
        ssh "$REMOTE_USER@$REMOTE_HOST" "rm -rf $REMOTE_PATH/latest && ln -sf $REMOTE_PATH/v$VERSION $REMOTE_PATH/latest"
        
        echo -e "${GREEN}已成功部署到远程服务器: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/v$VERSION/${NC}"
        ;;
        
    github)
        echo -e "${CYAN}部署到GitHub Releases...${NC}"
        
        # 检查是否安装了GitHub CLI
        if ! command -v gh &> /dev/null; then
            echo -e "${RED}错误: 未安装GitHub CLI，无法部署到GitHub${NC}"
            echo -e "${YELLOW}请安装GitHub CLI: https://cli.github.com/${NC}"
            exit 1
        fi
        
        # 检查是否已登录GitHub
        if ! gh auth status &> /dev/null; then
            echo -e "${RED}未登录GitHub，请先登录${NC}"
            gh auth login
        fi
        
        # 创建新的发布
        ASSETS_ARGS=""
        
        if [ -f "$DEPLOY_DIR/v$VERSION/$(basename "$EXE_FILE")" ]; then
            ASSETS_ARGS="$ASSETS_ARGS $DEPLOY_DIR/v$VERSION/$(basename "$EXE_FILE")"
        fi
        
        if [ -f "$DEPLOY_DIR/v$VERSION/$(basename "$ZIP_FILE")" ]; then
            ASSETS_ARGS="$ASSETS_ARGS $DEPLOY_DIR/v$VERSION/$(basename "$ZIP_FILE")"
        fi
        
        gh release create "v$VERSION" \
            --title "加密货币网格交易系统 v$VERSION" \
            --notes-file "$DEPLOY_DIR/v$VERSION/release-notes.md" \
            $ASSETS_ARGS
            
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}已成功部署到GitHub Releases！${NC}"
        else
            echo -e "${RED}部署到GitHub Releases失败！${NC}"
            exit 1
        fi
        ;;
        
    *)
        echo -e "${RED}未知的部署目标: $DEPLOY_TARGET${NC}"
        echo -e "${YELLOW}支持的部署目标: local, remote, github${NC}"
        exit 1
        ;;
esac

echo -e "\n${BLUE}=============================================${NC}"
echo -e "${GREEN}  部署完成！                               ${NC}"
echo -e "${BLUE}=============================================${NC}"

exit 0 