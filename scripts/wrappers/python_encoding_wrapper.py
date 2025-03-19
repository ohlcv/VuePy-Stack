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
