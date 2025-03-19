#!/bin/bash

# 加密货币网格交易系统 - 应用打包脚本
# 功能：打包Electron应用为可分发的.exe文件

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
echo -e "${BLUE}  加密货币网格交易系统 - 应用打包工具       ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 切换到项目根目录
cd "$PARENT_DIR" || { echo -e "${RED}无法切换到项目目录: $PARENT_DIR${NC}"; exit 1; }

# 解析参数
OUTPUT_DIR="./dist"
PLATFORM="win"  # 默认打包为Windows平台
DEBUG=false
SKIP_BUILD=false

# 处理命令行参数
for i in "$@"; do
    case $i in
        --platform=*)
            PLATFORM="${i#*=}"
            ;;
        --output=*)
            OUTPUT_DIR="${i#*=}"
            ;;
        --debug)
            DEBUG=true
            ;;
        --skip-build)
            SKIP_BUILD=true
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --platform=PLATFORM    指定打包平台 (win, mac, linux)"
            echo "  --output=DIR           指定输出目录"
            echo "  --debug                启用调试模式"
            echo "  --skip-build           跳过前端构建步骤"
            echo "  --help                 显示此帮助信息"
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $i${NC}"
            echo "使用 --help 查看可用选项"
            exit 1
            ;;
    esac
done

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 检查需要的工具
echo -e "${CYAN}检查必要的工具...${NC}"

# 检查Node.js和npm
if ! command -v node &> /dev/null; then
    echo -e "${RED}错误: 未安装Node.js${NC}"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo -e "${RED}错误: 未安装npm${NC}"
    exit 1
fi

# 进入client目录
cd ./client || { echo -e "${RED}无法进入client目录${NC}"; exit 1; }

# 构建前端
if [ "$SKIP_BUILD" = false ]; then
    echo -e "${CYAN}构建前端应用...${NC}"
    npm run build
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}前端构建失败${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}跳过前端构建${NC}"
fi

# 设置electron-builder参数
BUILDER_ARGS=""
case "$PLATFORM" in
    win)
        BUILDER_ARGS="--win --x64"
        ;;
    mac)
        BUILDER_ARGS="--mac"
        ;;
    linux)
        BUILDER_ARGS="--linux"
        ;;
    *)
        echo -e "${RED}不支持的平台: $PLATFORM${NC}"
        echo -e "${YELLOW}支持的平台: win, mac, linux${NC}"
        exit 1
        ;;
esac

if [ "$DEBUG" = true ]; then
    BUILDER_ARGS="$BUILDER_ARGS --debug"
fi

# 打包应用
echo -e "${CYAN}正在打包应用为 $PLATFORM 平台...${NC}"
echo -e "${YELLOW}使用参数: $BUILDER_ARGS${NC}"

# 确保package.json中有build字段
if ! grep -q '"build"' package.json; then
    echo -e "${YELLOW}警告: package.json中没有build配置，将添加默认配置${NC}"
    
    # 添加默认build配置
    TMP_FILE=$(mktemp)
    jq '. + {
        "build": {
            "appId": "com.example.cryptogrid",
            "productName": "加密货币网格交易系统",
            "files": ["dist/**/*", "src/main/**/*", "src/python/**/*"],
            "extraResources": ["src/python/**/*"],
            "win": {
                "target": "nsis",
                "icon": "src/assets/icon.ico"
            },
            "mac": {
                "target": "dmg",
                "icon": "src/assets/icon.icns"
            },
            "linux": {
                "target": "AppImage",
                "icon": "src/assets/icon.png"
            }
        }
    }' package.json > "$TMP_FILE" && mv "$TMP_FILE" package.json
fi

# 执行打包命令
NPM_PACKAGE_COMMAND="npm run package -- $BUILDER_ARGS"

# 检查package.json中是否有package脚本
if ! grep -q '"package"' package.json; then
    echo -e "${YELLOW}警告: package.json中没有package脚本，使用electron-builder命令${NC}"
    NPM_PACKAGE_COMMAND="./node_modules/.bin/electron-builder $BUILDER_ARGS"
fi

echo -e "${YELLOW}执行命令: $NPM_PACKAGE_COMMAND${NC}"
eval "$NPM_PACKAGE_COMMAND"

# 检查打包结果
if [ $? -eq 0 ]; then
    # 获取版本号
    VERSION=$(grep -o '"version": "[^"]*"' package.json | head -1 | cut -d'"' -f4)
    
    # 复制打包文件到输出目录
    if [ -d "dist" ]; then
        # 检查打包后的文件
        if [ "$PLATFORM" = "win" ] && [ -f "dist/加密货币网格交易系统 Setup $VERSION.exe" ]; then
            cp "dist/加密货币网格交易系统 Setup $VERSION.exe" "$PARENT_DIR/$OUTPUT_DIR/"
            echo -e "${GREEN}打包成功！${NC}"
            echo -e "${GREEN}安装程序已保存到: $PARENT_DIR/$OUTPUT_DIR/加密货币网格交易系统 Setup $VERSION.exe${NC}"
        elif [ -d "dist/win-unpacked" ]; then
            # 压缩便携版
            echo -e "${YELLOW}创建便携版压缩包...${NC}"
            cd dist
            zip -r "$PARENT_DIR/$OUTPUT_DIR/加密货币网格交易系统-便携版-$VERSION.zip" win-unpacked/
            echo -e "${GREEN}便携版已保存到: $PARENT_DIR/$OUTPUT_DIR/加密货币网格交易系统-便携版-$VERSION.zip${NC}"
            cd ..
        else
            echo -e "${YELLOW}在dist目录中找不到预期的打包文件，复制整个dist目录${NC}"
            cp -r dist/* "$PARENT_DIR/$OUTPUT_DIR/"
        fi
    else
        echo -e "${RED}打包后的dist目录不存在${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}应用打包完成!${NC}"
    echo -e "${GREEN}打包文件位于: $PARENT_DIR/$OUTPUT_DIR/${NC}"
else
    echo -e "${RED}打包失败! 请检查错误信息${NC}"
    exit 1
fi

# 返回到原始目录
cd "$PARENT_DIR"

exit 0 