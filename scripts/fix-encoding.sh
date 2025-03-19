#!/bin/bash

# 加密货币网格交易系统 - 编码修复脚本
# 功能：修复Windows环境下的中文编码问题

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
echo -e "${BLUE}   加密货币网格交易系统 - 编码修复工具     ${NC}"
echo -e "${BLUE}=============================================${NC}"

# 切换到项目根目录
cd "$PARENT_DIR" || { echo -e "${RED}无法切换到项目目录: $PARENT_DIR${NC}"; exit 1; }

# 检查系统环境
echo -e "${CYAN}检查系统环境...${NC}"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    echo -e "${YELLOW}Windows环境:${NC} 通过Git Bash或WSL运行"
    
    # 检查是否有Python客户端代码
    PYTHON_DIR="$PARENT_DIR/client/src/python"
    if [ -d "$PYTHON_DIR" ]; then
        echo -e "${GREEN}✓ 找到Python客户端目录${NC}"
        
        # 创建编码修复的Python包装器
        echo -e "${CYAN}创建Python编码修复包装器...${NC}"
        WRAPPER_DIR="$PARENT_DIR/scripts/wrappers"
        mkdir -p "$WRAPPER_DIR"
        
        # 创建Python包装器脚本
        cat > "$WRAPPER_DIR/python_encoding_wrapper.py" << 'EOF'
#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Python编码修复包装器
用于解决Windows环境下Python脚本中文显示乱码问题
"""

import os
import sys
import subprocess
import locale

def main():
    # 设置环境变量
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    
    # 打印当前环境信息
    print(f"系统编码: {sys.getdefaultencoding()}")
    print(f"终端编码: {sys.stdout.encoding}")
    print(f"区域设置: {locale.getpreferredencoding()}")
    
    # 获取原始Python脚本路径和参数
    if len(sys.argv) < 2:
        print("用法: python_encoding_wrapper.py <python脚本路径> [参数...]")
        return 1
    
    script_path = sys.argv[1]
    script_args = sys.argv[2:]
    
    # 确保Python脚本文件存在
    if not os.path.exists(script_path):
        print(f"错误: 找不到Python脚本: {script_path}")
        return 1
    
    # 检查脚本第一行，如果没有编码声明，添加一个
    with open(script_path, 'r', encoding='utf-8') as f:
        script_content = f.read()
    
    # 检查脚本是否已有编码声明
    has_encoding = False
    script_lines = script_content.split('\n')
    if len(script_lines) > 0:
        if script_lines[0].startswith('#!'):
            if len(script_lines) > 1 and '# -*- coding:' in script_lines[1]:
                has_encoding = True
        elif '# -*- coding:' in script_lines[0]:
            has_encoding = True
    
    if not has_encoding:
        print("添加UTF-8编码声明到脚本...")
        with open(script_path, 'w', encoding='utf-8') as f:
            f.write('# -*- coding: utf-8 -*-\n\n' + script_content)
    
    # 使用适当的编码运行Python脚本
    cmd = [sys.executable, "-u", script_path] + script_args
    print(f"执行命令: {' '.join(cmd)}")
    
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        encoding='utf-8'
    )
    
    # 实时输出结果
    while True:
        output = process.stdout.readline()
        if output == '' and process.poll() is not None:
            break
        if output:
            print(output.strip())
    
    # 输出错误信息
    for line in process.stderr:
        print(f"错误: {line.strip()}")
    
    return process.poll()

if __name__ == "__main__":
    sys.exit(main())
EOF
        
        # 设置执行权限
        chmod +x "$WRAPPER_DIR/python_encoding_wrapper.py"
        echo -e "${GREEN}✓ 已创建Python编码修复包装器${NC}"
        
        # 创建修复后的Python调用脚本
        echo -e "${CYAN}创建Python调用脚本...${NC}"
        cat > "$WRAPPER_DIR/python_fixed.sh" << EOF
#!/bin/bash
# Python调用脚本 - 解决编码问题

# 设置环境变量
export PYTHONIOENCODING=utf-8
export PYTHONLEGACYWINDOWSSTDIO=utf-8
export LANG=zh_CN.UTF-8

# 调用Python包装器
python "$WRAPPER_DIR/python_encoding_wrapper.py" "\$@"
EOF
        
        # 设置执行权限
        chmod +x "$WRAPPER_DIR/python_fixed.sh"
        echo -e "${GREEN}✓ 已创建Python调用脚本${NC}"
        
        # 修改run-system.sh脚本，使用修复编码的Python
        echo -e "${CYAN}修改run-system.sh使用编码修复后的Python...${NC}"
        if [ -f "$SCRIPT_DIR/run-system.sh" ]; then
            # 备份原始脚本
            cp "$SCRIPT_DIR/run-system.sh" "$SCRIPT_DIR/run-system.sh.bak"
            
            # 替换Python调用
            sed -i 's/python /\.\/scripts\/wrappers\/python_fixed.sh /g' "$SCRIPT_DIR/run-system.sh"
            echo -e "${GREEN}✓ 已修改run-system.sh脚本${NC}"
        else
            echo -e "${RED}✗ 找不到run-system.sh脚本${NC}"
        fi
        
        # 更新Electron配置，确保正确处理中文编码
        echo -e "${CYAN}更新Electron配置...${NC}"
        ELECTRON_MAIN="$PARENT_DIR/client/src/main/index.js"
        if [ -f "$ELECTRON_MAIN" ]; then
            # 备份原始脚本
            cp "$ELECTRON_MAIN" "$ELECTRON_MAIN.bak"
            
            # 添加编码设置
            if ! grep -q "process.env.PYTHONIOENCODING" "$ELECTRON_MAIN"; then
                sed -i '/const { app, BrowserWindow } = require/a\
// 设置Python编码环境变量\
process.env.PYTHONIOENCODING = "utf-8";\
process.env.PYTHONLEGACYWINDOWSSTDIO = "utf-8";\
process.env.LANG = "zh_CN.UTF-8";' "$ELECTRON_MAIN"
                echo -e "${GREEN}✓ 已更新Electron配置${NC}"
            else
                echo -e "${YELLOW}Electron配置已包含编码设置，跳过${NC}"
            fi
        else
            echo -e "${RED}✗ 找不到Electron主文件${NC}"
        fi
        
        # 更新Python主脚本，确保包含编码声明
        echo -e "${CYAN}更新Python主脚本...${NC}"
        PYTHON_MAIN="$PYTHON_DIR/main.py"
        if [ -f "$PYTHON_MAIN" ]; then
            # 检查脚本是否已包含编码声明
            if ! grep -q "# -*- coding: utf-8 -*-" "$PYTHON_MAIN"; then
                # 备份原始脚本
                cp "$PYTHON_MAIN" "$PYTHON_MAIN.bak"
                
                # 添加编码声明
                sed -i '1s/^/# -*- coding: utf-8 -*-\n\n/' "$PYTHON_MAIN"
                echo -e "${GREEN}✓ 已添加Python编码声明${NC}"
            else
                echo -e "${YELLOW}Python主脚本已包含编码声明，跳过${NC}"
            fi
        else
            echo -e "${RED}✗ 找不到Python主脚本${NC}"
        fi
    else
        echo -e "${RED}✗ 找不到Python客户端目录${NC}"
    fi
    
    # 创建.bashrc文件，设置全局环境变量
    echo -e "${CYAN}创建编码环境变量设置脚本...${NC}"
    cat > "$PARENT_DIR/.env.encoding" << EOF
# 编码环境变量设置
export PYTHONIOENCODING=utf-8
export PYTHONLEGACYWINDOWSSTDIO=utf-8
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
EOF
    
    echo -e "${GREEN}✓ 已创建编码环境变量设置脚本${NC}"
    echo -e "${YELLOW}请在使用系统前运行以下命令加载环境变量:${NC}"
    echo -e "${CYAN}source $PARENT_DIR/.env.encoding${NC}"
    
    # 修改start.sh，添加自动加载环境变量的功能
    echo -e "${CYAN}更新start.sh脚本...${NC}"
    START_SCRIPT="$PARENT_DIR/start.sh"
    if [ -f "$START_SCRIPT" ]; then
        # 备份原始脚本
        cp "$START_SCRIPT" "$START_SCRIPT.bak"
        
        # 在Windows检测部分后添加环境变量加载
        if ! grep -q "source.*\.env\.encoding" "$START_SCRIPT"; then
            sed -i '/任何Windows特定的设置都可以放在这里/a\
    # 加载编码环境变量\
    if [ -f "$SCRIPT_DIR/.env.encoding" ]; then\
        source "$SCRIPT_DIR/.env.encoding"\
        echo "已加载编码环境变量"\
    fi' "$START_SCRIPT"
            echo -e "${GREEN}✓ 已更新start.sh脚本${NC}"
        else
            echo -e "${YELLOW}start.sh已包含环境变量加载，跳过${NC}"
        fi
    else
        echo -e "${RED}✗ 找不到start.sh脚本${NC}"
    fi
else
    echo -e "${GREEN}非Windows环境，编码问题不太可能出现${NC}"
    echo -e "${YELLOW}如果仍有编码问题，请考虑设置以下环境变量:${NC}"
    echo -e "${CYAN}export PYTHONIOENCODING=utf-8${NC}"
    echo -e "${CYAN}export LANG=zh_CN.UTF-8${NC}"
    echo -e "${CYAN}export LC_ALL=zh_CN.UTF-8${NC}"
fi

echo -e "\n${BLUE}=============================================${NC}"
echo -e "${GREEN}      编码修复完成                           ${NC}"
echo -e "${BLUE}=============================================${NC}"

exit 0 