#!/bin/bash
# Python调用脚本 - 解决编码问题

# 设置环境变量
export PYTHONIOENCODING=utf-8
export PYTHONLEGACYWINDOWSSTDIO=utf-8
export LANG=zh_CN.UTF-8

# 调用Python包装器
python "/c/Users/Excoldinwarm/Desktop/Quant/CryptoSystem/crypto-grid-mvp/scripts/wrappers/python_encoding_wrapper.py" "$@"
