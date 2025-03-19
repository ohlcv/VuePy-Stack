#!/bin/bash

# 加密货币网格交易系统启动脚本 - 重构版
# 版本：2.0
# 描述：这是一个重新设计的启动脚本，更加模块化和可维护

# Windows兼容性检查
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    echo "检测到Windows环境，确保通过Git Bash或WSL运行此脚本"
    # 转换路径分隔符为Windows兼容格式 (如果需要)
    # 任何Windows特定的设置都可以放在这里
    
    # 设置中文编码环境变量
    export PYTHONIOENCODING=utf-8
    export PYTHONLEGACYWINDOWSSTDIO=utf-8
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    echo "已设置中文编码环境变量"
    
    # 加载额外的编码环境变量（如果存在）
    if [ -f "$SCRIPT_DIR/.env.encoding" ]; then
        source "$SCRIPT_DIR/.env.encoding"
        echo "已加载自定义编码环境变量"
    fi
fi

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 定义基本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SCRIPTS_PATH="$SCRIPT_DIR/scripts"
LOG_DIR="$SCRIPT_DIR/logs"
DATA_DIR="$SCRIPT_DIR/data"
STRATEGY_DIR="$SCRIPT_DIR/strategy_files"

# 导出通用变量供子脚本使用
export RED GREEN YELLOW BLUE PURPLE CYAN NC
export SCRIPT_DIR SCRIPTS_PATH LOG_DIR DATA_DIR STRATEGY_DIR

# 显示标题
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}   加密货币网格交易系统 - 启动脚本 v2.0     ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}加密货币网格交易系统启动脚本${NC}"
    echo ""
    echo "用法: ./start.sh [选项]"
    echo ""
    echo "主要选项:"
    echo "  setup         设置开发环境（安装依赖）"
    echo "  run           构建并启动系统（默认开发模式）"
    echo "  stop          停止并移除所有Docker容器"
    echo "  status        显示所有容器状态"
    echo ""
    echo "Docker相关选项:"
    echo "  build         构建所有容器"
    echo "  up            启动Docker容器（不构建）"
    echo "  down          停止并移除所有Docker容器"
    echo "  restart       重启所有服务"
    echo "  logs [服务名] 查看服务日志（默认查看所有）"
    echo "  prune         清理Docker系统，删除所有未使用的资源"
    echo "  update-docker 根据当前源设置更新Docker文件"
    echo ""
    echo "特殊命令:"
    echo "  sources       配置npm和pip的源（官方源或国内源）"
    echo "  fix-network   修复Docker网络连接问题"
    echo "  fix-encoding  修复Windows环境下的中文编码问题"
    echo ""
    echo "测试和环境:"
    echo "  local         运行本地测试（不依赖Docker）"
    echo "  clean         清理临时文件和停止的容器"
    echo "  check-deps    检查所有依赖及其版本"
    echo "  deploy        部署到生产环境"
    echo ""
    echo "单独服务:"
    echo "  client        启动客户端容器（单独）"
    echo "  hummingbot    启动Hummingbot容器（单独）"
    echo ""
    echo "打包:"
    echo "  package       打包应用为.exe文件"
    echo ""
    echo "详细帮助:"
    echo "  help          显示此帮助信息"
    echo "  help-[命令]   显示特定命令的详细帮助"
    echo ""
    echo "示例:"
    echo "  ./start.sh setup       # 设置开发环境"
    echo "  ./start.sh run         # 构建并启动系统"
    echo "  ./start.sh sources     # 配置源设置"
    echo "  ./start.sh fix-encoding # 修复中文编码问题"
    echo "  ./start.sh update-docker # 根据当前源设置更新Docker文件"
}

# 检查脚本是否存在
check_script() {
    local script_name="$1"
    if [ ! -f "$SCRIPTS_PATH/$script_name" ]; then
        echo -e "${RED}错误: 脚本 $script_name 不存在${NC}"
        return 1
    fi
    # 确保脚本有执行权限
    chmod +x "$SCRIPTS_PATH/$script_name"
    return 0
}

# 执行脚本
run_script() {
    local script_name="$1"
    shift  # 移除第一个参数（脚本名称）
    
    if check_script "$script_name"; then
        "$SCRIPTS_PATH/$script_name" "$@"
        return $?
    else
                return 1
    fi
}

# 处理命令
process_command() {
    local command="$1"
    shift  # 移除第一个参数（命令）
    
    case "$command" in
        # 基础环境命令
        setup)
            run_script "setup-environment.sh" "$@"
            ;;
        run)
            # 默认开发模式运行
            run_script "run-system.sh" "$@"
            ;;
        local)
            run_script "local-test.sh" "$@"
            ;;
            
        # Docker相关命令
        up|docker-up)
            run_script "docker-commands.sh" "up" "$@"
            ;;
        down|docker-down)
            run_script "docker-commands.sh" "down" "$@"
            ;;
        build)
            run_script "docker-commands.sh" "build" "$@"
            ;;
        build-up)
            run_script "docker-commands.sh" "build-up" "$@"
            ;;
        build-cn)
            run_script "docker-commands.sh" "build-cn" "$@"
            ;;
        stop)
            run_script "docker-commands.sh" "down" "$@"
            ;;
        restart)
            run_script "docker-commands.sh" "restart" "$@"
            ;;
        logs)
            run_script "docker-commands.sh" "logs" "$@"
            ;;
        status)
            run_script "docker-commands.sh" "status" "$@"
            ;;
        prune)
            run_script "docker-commands.sh" "prune" "$@"
            ;;
        update-docker)
            run_script "update-docker-files.sh" "$@"
            ;;
            
        # 单独服务命令
        client)
            run_script "docker-commands.sh" "client" "$@"
            ;;
        hummingbot)
            run_script "docker-commands.sh" "hummingbot" "$@"
            ;;
            
        # 辅助命令
        sources)
            run_script "package-sources.sh" "$@"
            ;;
        fix-network)
            run_script "docker-network-fix.sh" "$@"
            ;;
        clean)
            run_script "cleanup.sh" "$@"
            ;;
        check-deps)
            run_script "check-dependencies.sh" "$@"
            ;;
        debug)
            run_script "local-test.sh" "--debug" "$@"
            ;;
        # 编码问题修复命令
        fix-encoding)
            run_script "fix-encoding.sh" "$@"
            ;;
        
        # 打包命令
        package)
            run_script "package-app.sh" "$@"
            ;;
        
        # 部署命令
        deploy)
            run_script "deploy.sh" "$@"
            ;;
            
        # 帮助命令
        help)
            if [ -n "$1" ]; then
                # 显示特定命令的帮助
                run_script "help.sh" "$1"
            else
            show_help
            fi
            ;;
        help-*)
            # 从命令名称中提取子命令
            subcmd=$(echo "$command" | sed 's/help-//')
            run_script "help.sh" "$subcmd"
            ;;
            
        # 未知命令
        *)
            echo -e "${RED}未知命令: $command${NC}"
            echo -e "运行 ${YELLOW}./start.sh help${NC} 获取可用命令列表"
            return 1
            ;;
    esac
    
    return $?
}

# 主逻辑
if [ $# -eq 0 ]; then
    # 没有参数时显示帮助
    show_help
    exit 0
else
    # 有参数时处理命令
    process_command "$@"
    EXIT_CODE=$?
    
    # 显示命令执行状态
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}命令执行成功${NC}"
    else
        echo -e "${RED}命令执行失败，退出代码: $EXIT_CODE${NC}"
    fi
    
    exit $EXIT_CODE
fi 