#!/bin/bash

# 加密货币网格交易系统 - 帮助脚本
# 功能：提供各种命令的详细帮助信息

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

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

# 帮助内容
show_help_setup() {
    echo -e "${BLUE}=========================${NC}"
    echo -e "${BLUE}    设置开发环境帮助    ${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""
    echo -e "${YELLOW}用法:${NC} ./start.sh setup [选项]"
    echo ""
    echo "此命令安装开发环境所需的所有依赖，包括:"
    echo "  • Node.js 包 (通过npm)"
    echo "  • Python 包 (通过pip)"
    echo "  • Docker 设置"
    echo ""
    echo -e "${YELLOW}选项:${NC}"
    echo "  --no-docker    跳过Docker设置"
    echo "  --no-node      跳过Node.js依赖安装"
    echo "  --no-python    跳过Python依赖安装"
    echo "  --cn           使用中国镜像源"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  ./start.sh setup --cn         # 使用中国镜像源设置环境"
    echo "  ./start.sh setup --no-docker  # 跳过Docker设置"
}

show_help_run() {
    echo -e "${BLUE}=========================${NC}"
    echo -e "${BLUE}    运行系统帮助        ${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""
    echo -e "${YELLOW}用法:${NC} ./start.sh run [模式]"
    echo ""
    echo "此命令构建并启动整个系统，包括:"
    echo "  • 前端Vue应用"
    echo "  • Electron容器"
    echo "  • Hummingbot容器管理"
    echo ""
    echo -e "${YELLOW}可用模式:${NC}"
    echo "  dev   开发模式，使用Vite开发服务器 (默认)"
    echo "  prod  生产模式，构建生产版本并运行"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  ./start.sh run       # 开发模式运行"
    echo "  ./start.sh run prod  # 生产模式运行"
}

show_help_docker() {
    echo -e "${BLUE}=========================${NC}"
    echo -e "${BLUE}    Docker命令帮助      ${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""
    echo -e "${YELLOW}Docker相关命令:${NC}"
    echo "  build      构建所有Docker容器"
    echo "  up         启动所有Docker容器（不重新构建）"
    echo "  down       停止并移除所有Docker容器"
    echo "  restart    重启所有服务"
    echo "  logs       查看服务日志"
    echo "  prune      清理Docker系统"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  ./start.sh build         # 构建所有容器"
    echo "  ./start.sh logs client   # 查看client容器的日志"
}

show_help_sources() {
    echo -e "${BLUE}=========================${NC}"
    echo -e "${BLUE}    软件源设置帮助      ${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""
    echo -e "${YELLOW}用法:${NC} ./start.sh sources [源]"
    echo ""
    echo "此命令配置npm和pip的软件源，可以在官方源和国内源之间切换"
    echo ""
    echo -e "${YELLOW}可用源:${NC}"
    echo "  cn     使用中国镜像源 (npm:淘宝, pip:清华)"
    echo "  us     使用官方源 (默认)"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  ./start.sh sources cn   # 设置为中国镜像源"
    echo "  ./start.sh sources us   # 设置为官方源"
}

show_help_fix_encoding() {
    echo -e "${BLUE}=======================================================${NC}"
    echo -e "${BLUE}    加密货币网格交易系统 - 中文编码问题修复工具      ${NC}"
    echo -e "${BLUE}=======================================================${NC}"
    echo
    echo -e "${CYAN}描述:${NC}"
    echo "  此命令用于解决Windows环境下的中文编码问题，包括命令行输出、Python脚本和"
    echo "  Electron与Python通信过程中的中文乱码问题。"
    echo
    echo -e "${CYAN}用法:${NC}"
    echo "  ./start.sh fix-encoding"
    echo
    echo -e "${CYAN}功能:${NC}"
    echo "  1. 自动设置必要的环境变量，确保UTF-8编码"
    echo "  2. 创建Python编码修复包装器，添加UTF-8编码声明"
    echo "  3. 修改run-system.sh脚本使用编码友好的方式启动Python"
    echo "  4. 更新Electron配置，确保与Python通信使用正确编码"
    echo "  5. 创建.env.encoding文件，方便手动加载编码环境变量"
    echo
    echo -e "${CYAN}示例:${NC}"
    echo "  ./start.sh fix-encoding"
    echo "  source .env.encoding"
    echo
    echo -e "${CYAN}注意事项:${NC}"
    echo "  - 此命令主要针对Windows环境，在Linux/Mac环境下一般不需要使用"
    echo "  - 修复后可能需要重启命令行窗口以使某些环境变量生效"
    echo "  - 如果仍有特定文件存在编码问题，请参考文档手动修复"
    echo
    echo -e "${CYAN}相关文档:${NC}"
    echo "  docs/中文编码问题解决方案.md"
}

# 显示帮助信息
if [ -z "$1" ]; then
    echo -e "${BLUE}加密货币网格交易系统 - 帮助${NC}"
    echo ""
    echo -e "使用: ${YELLOW}./start.sh help [命令]${NC} 查看特定命令的详细帮助"
    echo ""
    echo "可用的帮助主题:"
    echo "  setup        - 设置开发环境"
    echo "  run          - 运行系统"
    echo "  docker       - Docker相关命令"
    echo "  sources      - 配置软件源"
    echo "  fix-encoding - 修复中文编码问题"
    echo ""
    echo -e "示例: ${YELLOW}./start.sh help-run${NC} 或 ${YELLOW}./start.sh help run${NC}"
else
    case "$1" in
        setup)
            show_help_setup
            ;;
        run)
            show_help_run
            ;;
        docker|build|up|down|restart|logs|prune)
            show_help_docker
            ;;
        sources)
            show_help_sources
            ;;
        fix-encoding)
            show_help_fix_encoding
            ;;
        *)
            echo -e "${RED}未知的帮助主题: $1${NC}"
            echo -e "运行 ${YELLOW}./start.sh help${NC} 获取可用帮助主题列表"
            exit 1
            ;;
    esac
fi

exit 0 