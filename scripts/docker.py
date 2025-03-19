#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Docker命令模块

提供Docker相关的命令，包括构建、优化Docker镜像
"""

import os
import sys
import argparse
import logging
import json
import re
import time
import shutil
import subprocess
from pathlib import Path

# 配置日志
logger = logging.getLogger("ads.docker")


def run_command(command, cwd=None, env=None, capture_output=True):
    """
    运行shell命令

    Args:
        command: 要运行的命令（字符串或列表）
        cwd: 工作目录
        env: 环境变量
        capture_output: 是否捕获输出

    Returns:
        (返回码, 标准输出, 标准错误)
    """
    if isinstance(command, str):
        shell = True
    else:
        shell = False

    try:
        if capture_output:
            process = subprocess.run(
                command,
                shell=shell,
                cwd=cwd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            return process.returncode, process.stdout, process.stderr
        else:
            process = subprocess.run(command, shell=shell, cwd=cwd, env=env)
            return process.returncode, None, None
    except Exception as e:
        logger.error(f"执行命令失败: {e}")
        return 1, None, str(e)


def check_docker_installed():
    """
    检查Docker是否安装

    Returns:
        如果安装了Docker返回True，否则返回False
    """
    ret_code, stdout, stderr = run_command("docker --version")
    if ret_code == 0:
        return True
    return False


def get_docker_info():
    """
    获取Docker信息

    Returns:
        Docker信息字典，如果发生错误则返回None
    """
    ret_code, stdout, stderr = run_command("docker info --format '{{json .}}'")
    if ret_code == 0 and stdout:
        try:
            return json.loads(stdout.strip())
        except json.JSONDecodeError:
            logger.error("无法解析Docker信息")
            # 尝试不使用json格式获取信息
            ret_code, stdout, stderr = run_command("docker info")
            if ret_code == 0 and stdout:
                # 将文本格式转换为字典
                info = {}
                section = None
                for line in stdout.strip().split("\n"):
                    line = line.strip()
                    if not line:
                        continue
                    if not line.startswith(" "):
                        # 这是一个主要部分
                        section = line.rstrip(":")
                        info[section] = {}
                    elif ":" in line:
                        # 这是一个键值对
                        key, value = [x.strip() for x in line.split(":", 1)]
                        if section:
                            if isinstance(info[section], dict):
                                info[section][key] = value
                            else:
                                info[section] = {key: value}
                        else:
                            info[key] = value
                return info
    return None


def get_docker_version():
    """
    获取Docker版本信息

    Returns:
        Docker版本信息字典，如果发生错误则返回None
    """
    ret_code, stdout, stderr = run_command("docker version --format '{{json .}}'")
    if ret_code == 0 and stdout:
        try:
            return json.loads(stdout.strip())
        except json.JSONDecodeError:
            logger.error("无法解析Docker版本信息")
            # 尝试不使用json格式获取版本信息
            ret_code, stdout, stderr = run_command("docker version")
            if ret_code == 0 and stdout:
                # 将文本格式转换为字典
                version = {}
                section = None
                for line in stdout.strip().split("\n"):
                    line = line.strip()
                    if not line:
                        continue
                    if not line.startswith(" "):
                        # 这是一个主要部分
                        section = line.rstrip(":")
                        version[section] = {}
                    elif ":" in line:
                        # 这是一个键值对
                        key, value = [x.strip() for x in line.split(":", 1)]
                        if section:
                            if isinstance(version[section], dict):
                                version[section][key] = value
                            else:
                                version[section] = {key: value}
                        else:
                            version[key] = value
                return version
    return None


def build_image(args):
    """
    构建Docker镜像

    Args:
        args: 命令行参数

    Returns:
        退出码
    """
    # 检查Docker是否安装
    if not check_docker_installed():
        print("错误: Docker未安装或者不在PATH中")
        return 1

    # 获取Dockerfile路径
    dockerfile = (
        args.dockerfile
        if hasattr(args, "dockerfile") and args.dockerfile
        else "Dockerfile"
    )

    # 检查Dockerfile是否存在
    if not os.path.exists(dockerfile):
        print(f"错误: Dockerfile不存在: {dockerfile}")
        return 1

    # 获取镜像名称
    if not hasattr(args, "tag") or not args.tag:
        print("错误: 必须指定镜像标签(--tag)")
        return 1

    tag = args.tag

    # 设置构建上下文
    context = args.context if hasattr(args, "context") and args.context else "."

    # 检查构建上下文是否存在
    if not os.path.exists(context):
        print(f"错误: 构建上下文不存在: {context}")
        return 1

    # 构建命令
    build_cmd = ["docker", "build"]

    # 添加Dockerfile路径
    build_cmd.extend(["-f", dockerfile])

    # 添加镜像标签
    build_cmd.extend(["-t", tag])

    # 设置构建参数
    if hasattr(args, "build_arg") and args.build_arg:
        for arg in args.build_arg:
            build_cmd.extend(["--build-arg", arg])

    # 是否使用缓存
    if hasattr(args, "no_cache") and args.no_cache:
        build_cmd.append("--no-cache")

    # 是否总是拉取基础镜像
    if hasattr(args, "pull") and args.pull:
        build_cmd.append("--pull")

    # 指定构建平台
    if hasattr(args, "platform") and args.platform:
        build_cmd.extend(["--platform", args.platform])

    # 指定构建目标阶段
    if hasattr(args, "target") and args.target:
        build_cmd.extend(["--target", args.target])

    # 指定网络模式
    if hasattr(args, "network") and args.network:
        build_cmd.extend(["--network", args.network])

    # 添加构建标签
    if hasattr(args, "label") and args.label:
        for label in args.label:
            build_cmd.extend(["--label", label])

    # 构建输出选项
    if hasattr(args, "output") and args.output:
        build_cmd.extend(["--output", args.output])

    # 压缩构建上下文
    if hasattr(args, "compress") and args.compress:
        build_cmd.append("--compress")

    # 指定构建进度显示
    if hasattr(args, "progress") and args.progress:
        build_cmd.extend(["--progress", args.progress])
    else:
        # 默认使用 auto 进度显示
        build_cmd.extend(["--progress", "auto"])

    # 外部缓存源
    if hasattr(args, "cache_from") and args.cache_from:
        for cache_src in args.cache_from:
            build_cmd.extend(["--cache-from", cache_src])

    # 导出构建缓存
    if hasattr(args, "cache_to") and args.cache_to:
        build_cmd.extend(["--cache-to", args.cache_to])

    # 秘密挂载
    if hasattr(args, "secret") and args.secret:
        for secret in args.secret:
            build_cmd.extend(["--secret", secret])

    # SSH挂载
    if hasattr(args, "ssh") and args.ssh:
        for ssh in args.ssh:
            build_cmd.extend(["--ssh", ssh])

    # 添加构建上下文路径
    build_cmd.append(context)

    # 显示构建信息
    print(f"正在构建Docker镜像: {tag}")
    print(f"使用Dockerfile: {dockerfile}")

    # 如果有特定的构建平台，显示平台信息
    if hasattr(args, "platform") and args.platform:
        print(f"目标平台: {args.platform}")

    # 如果有目标阶段，显示目标信息
    if hasattr(args, "target") and args.target:
        print(f"构建目标阶段: {args.target}")

    # 执行构建
    start_time = time.time()

    try:
        # 设置环境变量以改进Docker构建输出
        env = os.environ.copy()
        env["DOCKER_BUILDKIT"] = "1"  # 启用BuildKit以提高构建性能

        # 如果指定了构建输出或缓存选项，确保使用BuildKit
        uses_buildkit_features = (
            hasattr(args, "output")
            and args.output
            or hasattr(args, "cache_from")
            and args.cache_from
            or hasattr(args, "cache_to")
            and args.cache_to
            or hasattr(args, "secret")
            and args.secret
            or hasattr(args, "ssh")
            and args.ssh
        )
        if uses_buildkit_features:
            env["DOCKER_BUILDKIT"] = "1"

        ret_code, stdout, stderr = run_command(build_cmd, env=env, capture_output=False)
        end_time = time.time()

        if ret_code == 0:
            print(f"\n镜像构建成功: {tag}")
            print(f"构建耗时: {end_time - start_time:.2f}秒")

            # 显示构建的镜像信息
            print("\n镜像信息:")
            image_info_cmd = [
                "docker",
                "image",
                "inspect",
                "--format",
                "'{{.Id}} {{.Size}} {{.Created}}'",
                tag,
            ]
            info_code, info_stdout, info_stderr = run_command(image_info_cmd)
            if info_code == 0 and info_stdout:
                try:
                    image_id, image_size, created = (
                        info_stdout.strip().replace("'", "").split(" ", 2)
                    )
                    print(f"- ID: {image_id}")
                    # 转换字节为可读格式
                    try:
                        size_mb = float(image_size) / (1024 * 1024)
                        print(f"- 大小: {size_mb:.2f} MB")
                    except ValueError:
                        print(f"- 大小: {image_size}")
                    print(f"- 创建时间: {created}")
                except ValueError:
                    # 如果解析失败，直接输出原始信息
                    print(f"- 详细信息: {info_stdout.strip()}")

            # 检查镜像大小是否过大（超过1GB）
            if info_code == 0 and info_stdout:
                try:
                    _, image_size, _ = (
                        info_stdout.strip().replace("'", "").split(" ", 2)
                    )
                    size_mb = float(image_size) / (1024 * 1024)
                    if size_mb > 1000:  # 超过1GB
                        print("\n注意: 镜像大小超过1GB，可能需要优化")
                        print("优化建议:")
                        print("- 使用多阶段构建（multi-stage builds）")
                        print("- 清理临时文件和包管理器缓存")
                        print("- 考虑使用更小的基础镜像")
                        print("- 使用.dockerignore排除不必要的文件")
                except (ValueError, IndexError):
                    pass  # 忽略解析错误

            return 0
        else:
            print(f"\n镜像构建失败!")
            if stderr:
                print(f"错误信息: {stderr}")

            # 分析常见错误并提供具体建议
            if stderr:
                if "no such file or directory" in stderr.lower():
                    print("\n可能的问题: 文件或目录不存在")
                    print("建议: 检查Dockerfile中引用的所有文件路径是否正确")
                elif "denied" in stderr.lower() or "permission" in stderr.lower():
                    print("\n可能的问题: 权限错误")
                    print("建议: 检查文件权限，或尝试使用管理员权限运行命令")
                elif (
                    "network timeout" in stderr.lower()
                    or "could not resolve" in stderr.lower()
                ):
                    print("\n可能的问题: 网络连接问题")
                    print("建议: 检查网络连接，或使用 --network=host 选项")
                elif "unknown instruction" in stderr.lower():
                    print("\n可能的问题: Dockerfile语法错误")
                    print("建议: 检查Dockerfile中的指令是否正确")
                else:
                    # 提供一些常见问题的解决建议
                    print("\n可能的解决方案:")
                    print("1. 检查Dockerfile语法是否正确")
                    print("2. 确保所有引用的文件和路径都存在")
                    print("3. 检查构建参数是否正确")
                    print("4. 如果是网络问题，尝试使用 --network=host 选项")
                    print("5. 尝试使用 --no-cache 选项进行完全重新构建")

            return 1
    except KeyboardInterrupt:
        print("\n构建被用户取消")
        return 130
    except Exception as e:
        print(f"\n构建过程中发生错误: {e}")
        logger.error(f"构建过程中发生异常: {e}", exc_info=True)
        return 1


def optimize_dockerfile(args):
    """
    优化Dockerfile

    Args:
        args: 命令行参数

    Returns:
        退出码
    """
    # 获取Dockerfile路径
    dockerfile = (
        args.dockerfile
        if hasattr(args, "dockerfile") and args.dockerfile
        else "Dockerfile"
    )

    if not os.path.exists(dockerfile):
        print(f"错误: Dockerfile不存在: {dockerfile}")
        return 1

    # 读取Dockerfile内容
    try:
        with open(dockerfile, "r") as f:
            content = f.read()
    except Exception as e:
        print(f"读取Dockerfile失败: {e}")
        return 1

    # 创建备份
    backup_file = f"{dockerfile}.bak"
    try:
        shutil.copy2(dockerfile, backup_file)
        print(f"已创建Dockerfile备份: {backup_file}")
    except Exception as e:
        print(f"创建备份失败: {e}")
        return 1

    # 分析并优化Dockerfile
    optimized_content = analyze_and_optimize_dockerfile(content)

    # 如果没有任何优化，返回
    if content == optimized_content:
        print("Dockerfile已经是优化的，无需更改")

        # 删除备份文件
        if hasattr(args, "no_backup") and args.no_backup:
            try:
                os.remove(backup_file)
                print(f"已删除备份文件: {backup_file}")
            except Exception as e:
                print(f"删除备份文件失败: {e}")

        return 0

    # 保存优化后的Dockerfile
    output_file = args.output if hasattr(args, "output") and args.output else dockerfile

    try:
        with open(output_file, "w") as f:
            f.write(optimized_content)
        print(f"已保存优化后的Dockerfile: {output_file}")
        return 0
    except Exception as e:
        print(f"保存Dockerfile失败: {e}")
        return 1


def analyze_and_optimize_dockerfile(content):
    """
    分析并优化Dockerfile内容

    Args:
        content: Dockerfile内容

    Returns:
        优化后的Dockerfile内容
    """
    optimized = content

    # 1. 合并RUN命令
    optimized = optimize_run_commands(optimized)

    # 2. 优化COPY命令
    optimized = optimize_copy_commands(optimized)

    # 3. 添加.dockerignore建议
    optimized = suggest_dockerignore(optimized)

    # 4. 优化基础镜像
    optimized = optimize_base_image(optimized)

    # 5. 调整命令顺序提高缓存利用率
    optimized = optimize_command_order(optimized)

    return optimized


def optimize_run_commands(content):
    """
    合并多个RUN命令为一个，减少镜像层数

    Args:
        content: Dockerfile内容

    Returns:
        优化后的内容
    """
    # 提取所有RUN命令
    run_pattern = re.compile(r"^RUN\s+(.+)$", re.MULTILINE)
    runs = run_pattern.findall(content)

    if len(runs) <= 1:
        return content

    # 检查是否有依赖顺序的RUN命令
    # 简单实现：如果两个连续的RUN之间没有其他指令，则认为可以合并
    lines = content.split("\n")
    run_indexes = []

    for i, line in enumerate(lines):
        if line.strip().startswith("RUN "):
            run_indexes.append(i)

    # 找出可以合并的RUN命令组
    mergeable_groups = []
    current_group = [run_indexes[0]]

    for i in range(1, len(run_indexes)):
        if run_indexes[i] == run_indexes[i - 1] + 1:
            current_group.append(run_indexes[i])
        else:
            if len(current_group) > 1:
                mergeable_groups.append(current_group)
            current_group = [run_indexes[i]]

    if len(current_group) > 1:
        mergeable_groups.append(current_group)

    # 如果没有可合并的组，返回原内容
    if not mergeable_groups:
        return content

    # 合并RUN命令
    for group in reversed(mergeable_groups):
        # 提取命令内容
        commands = [lines[idx].strip()[4:] for idx in group]

        # 创建合并后的RUN命令
        merged_command = "RUN " + " && \\\n    ".join(commands)

        # 替换原来的命令
        for idx in reversed(group[1:]):
            lines.pop(idx)
        lines[group[0]] = merged_command

    return "\n".join(lines)


def optimize_copy_commands(content):
    """
    优化COPY命令，减少不必要的拷贝

    Args:
        content: Dockerfile内容

    Returns:
        优化后的内容
    """
    # 此处实现COPY命令优化
    # 例如：检测是否有不必要的通配符拷贝，或者可以用.dockerignore优化的情况
    return content


def suggest_dockerignore(content):
    """
    根据Dockerfile内容，建议.dockerignore文件内容

    Args:
        content: Dockerfile内容

    Returns:
        优化后的内容（添加了注释建议）
    """
    # 检查是否已经包含.dockerignore建议
    if ".dockerignore" in content:
        return content

    # 添加.dockerignore建议注释
    suggestion = """
# 建议创建.dockerignore文件，包含以下内容:
# .git
# .gitignore
# .vscode
# .idea
# __pycache__
# *.pyc
# *.pyo
# *.pyd
# node_modules
# npm-debug.log
# .DS_Store
"""

    return content + suggestion


def optimize_base_image(content):
    """
    优化基础镜像选择

    Args:
        content: Dockerfile内容

    Returns:
        优化后的内容
    """
    # 提取FROM指令
    from_pattern = re.compile(r"^FROM\s+([^#\n\r]+)", re.MULTILINE)
    from_match = from_pattern.search(content)

    if not from_match:
        return content

    base_image = from_match.group(1).strip()

    # 检查是否使用了特定标签而不是latest
    if ":latest" in base_image or ":" not in base_image:
        lines = content.split("\n")
        for i, line in enumerate(lines):
            if line.strip().startswith("FROM ") and (
                ":latest" in line or ":" not in line
            ):
                # 添加注释建议使用特定版本
                lines[i] = f"{line} # 建议使用特定版本标签而不是默认的latest"
                break
        return "\n".join(lines)

    return content


def optimize_command_order(content):
    """
    优化命令顺序，提高缓存利用率

    Args:
        content: Dockerfile内容

    Returns:
        优化后的内容
    """
    # 此处实现命令顺序优化
    # 例如：确保依赖文件先复制，代码最后复制
    return content


def optimize_image(args):
    """
    优化Docker镜像

    Args:
        args: 命令行参数

    Returns:
        退出码
    """
    # 获取镜像名称
    if not hasattr(args, "image") or not args.image:
        print("错误: 必须指定镜像名称(--image)")
        return 1

    image = args.image

    # 检查镜像是否存在
    ret_code, stdout, stderr = run_command(f"docker image inspect {image}")
    if ret_code != 0:
        print(f"错误: 镜像不存在: {image}")
        return 1

    print(f"正在分析镜像: {image}")

    # 获取镜像历史
    ret_code, stdout, stderr = run_command(
        f"docker history --no-trunc --format '{{.CreatedBy}}|{{.Size}}' {image}"
    )
    if ret_code != 0 or not stdout:
        print(f"获取镜像历史失败: {stderr}")
        return 1

    # 分析镜像层
    large_layers = []
    for line in stdout.strip().split("\n"):
        if not line:
            continue

        try:
            cmd, size = line.split("|")
            # 转换大小为MB
            size_mb = float(
                size.strip()
                .replace("MB", "")
                .replace("GB", "000")
                .replace("kB", "0.001")
            )
            if size_mb > 10:  # 大于10MB的层
                large_layers.append((cmd, size_mb))
        except Exception as e:
            print(f"解析层信息出错: {e}")
            continue

    # 打印大层信息
    if large_layers:
        print("\n大尺寸镜像层 (>10MB):")
        for cmd, size in large_layers:
            print(f"- {size:.2f} MB: {cmd[:100]}{'...' if len(cmd) > 100 else ''}")

    # 生成优化建议
    print("\n优化建议:")

    # 1. 检查缓存利用率
    print("1. 缓存优化:")
    print("   - 确保将变更频率较低的层放在前面")
    print("   - 将依赖文件(如package.json, requirements.txt)单独COPY并先安装")

    # 2. 建议多阶段构建
    has_build_tools = False
    for cmd, _ in large_layers:
        if any(
            tool in cmd
            for tool in ["gcc", "g++", "make", "build-essential", "python-dev"]
        ):
            has_build_tools = True
            break

    if has_build_tools:
        print("2. 使用多阶段构建:")
        print("   - 检测到构建工具安装，建议使用多阶段构建减小最终镜像大小")
        print("   - 示例: FROM node:14 AS builder ... FROM node:14-slim")

    # 3. 清理建议
    print("3. 清理临时文件:")
    print("   - 在同一个RUN命令中安装依赖并清理缓存")
    print("   - 使用--no-cache选项安装软件包")
    print("   - 删除不需要的构建依赖")

    # 4. 使用更小的基础镜像
    print("4. 基础镜像选择:")
    print("   - 考虑使用alpine或slim版本的基础镜像")
    print("   - 自定义基础镜像，只包含必要的组件")

    return 0


def docker_help(args):
    """
    显示Docker命令帮助信息

    Args:
        args: 命令行参数

    Returns:
        退出码
    """
    parser = create_parser()
    parser.print_help()
    return 0


def start_container(args):
    """启动Docker容器"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 启动单个或多个容器
    success = True
    for container in args.container:
        print(f"正在启动容器: {container}")
        ret_code, stdout, stderr = run_command(f"docker start {container}")

        if ret_code == 0:
            print(f"容器 {container} 启动成功")
        else:
            print(f"容器 {container} 启动失败: {stderr}")
            success = False

    return 0 if success else 1


def stop_container(args):
    """停止Docker容器"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 处理超时参数
    timeout = f"--time {args.time}" if args.time else ""

    # 停止单个或多个容器
    success = True
    for container in args.container:
        print(f"正在停止容器: {container}")
        ret_code, stdout, stderr = run_command(f"docker stop {timeout} {container}")

        if ret_code == 0:
            print(f"容器 {container} 已停止")
        else:
            print(f"容器 {container} 停止失败: {stderr}")
            success = False

    return 0 if success else 1


def restart_container(args):
    """重启Docker容器"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 处理超时参数
    timeout = f"--time {args.time}" if args.time else ""

    # 重启单个或多个容器
    success = True
    for container in args.container:
        print(f"正在重启容器: {container}")
        ret_code, stdout, stderr = run_command(f"docker restart {timeout} {container}")

        if ret_code == 0:
            print(f"容器 {container} 已重启")
        else:
            print(f"容器 {container} 重启失败: {stderr}")
            success = False

    return 0 if success else 1


def remove_container(args):
    """删除Docker容器"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 构建删除命令参数
    cmd_options = []
    if args.force:
        cmd_options.append("--force")
    if args.volumes:
        cmd_options.append("--volumes")

    options = " ".join(cmd_options)

    # 删除单个或多个容器
    success = True
    for container in args.container:
        print(f"正在删除容器: {container}")
        ret_code, stdout, stderr = run_command(f"docker rm {options} {container}")

        if ret_code == 0:
            print(f"容器 {container} 已删除")
        else:
            print(f"容器 {container} 删除失败: {stderr}")
            success = False

    return 0 if success else 1


def pause_container(args):
    """暂停Docker容器"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 暂停单个或多个容器
    success = True
    for container in args.container:
        print(f"正在暂停容器: {container}")
        ret_code, stdout, stderr = run_command(f"docker pause {container}")

        if ret_code == 0:
            print(f"容器 {container} 已暂停")
        else:
            print(f"容器 {container} 暂停失败: {stderr}")
            success = False

    return 0 if success else 1


def resume_container(args):
    """恢复Docker容器"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 恢复单个或多个容器
    success = True
    for container in args.container:
        print(f"正在恢复容器: {container}")
        ret_code, stdout, stderr = run_command(f"docker unpause {container}")

        if ret_code == 0:
            print(f"容器 {container} 已恢复")
        else:
            print(f"容器 {container} 恢复失败: {stderr}")
            success = False

    return 0 if success else 1


def container_logs(args):
    """获取Docker容器日志"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 构建日志命令选项
    cmd_options = []
    if args.follow:
        cmd_options.append("--follow")
    if args.tail:
        cmd_options.append(f"--tail {args.tail}")
    if args.since:
        cmd_options.append(f"--since {args.since}")
    if args.until:
        cmd_options.append(f"--until {args.until}")
    if args.timestamps:
        cmd_options.append("--timestamps")

    options = " ".join(cmd_options)

    # 获取容器日志
    print(f"正在获取容器 {args.container} 的日志:")
    ret_code, stdout, stderr = run_command(
        f"docker logs {options} {args.container}", capture_output=False
    )

    return ret_code


def container_status(args):
    """获取Docker容器状态"""
    # 构建过滤条件
    filters = []
    if args.name:
        filters.append(f"name={args.name}")
    if args.status:
        filters.append(f"status={args.status}")

    filter_cmd = f'--filter {" --filter ".join(filters)}' if filters else ""

    # 获取容器列表命令
    format_template = (
        "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}"
    )
    cmd = f'docker ps {"-a" if args.all else ""} {filter_cmd} --format "{format_template}"'

    ret_code, stdout, stderr = run_command(cmd)

    if ret_code != 0:
        print(f"获取容器状态失败: {stderr}")
        return 1

    if not stdout.strip():
        print("没有找到符合条件的容器")
        return 0

    # 解析并格式化输出
    containers = []
    for line in stdout.strip().split("\n"):
        if line:
            parts = line.split("\t")
            if len(parts) >= 6:
                containers.append(
                    {
                        "ID": parts[0],
                        "名称": parts[1],
                        "镜像": parts[2],
                        "状态": parts[3],
                        "端口": parts[4],
                        "已运行": parts[5],
                    }
                )

    # 使用tabulate打印表格
    if containers:
        headers = ["ID", "名称", "镜像", "状态", "端口", "已运行"]
        table_data = [
            [c["ID"], c["名称"], c["镜像"], c["状态"], c["端口"], c["已运行"]]
            for c in containers
        ]
        print(tabulate.tabulate(table_data, headers=headers, tablefmt="grid"))

    return 0


def container_inspect(args):
    """检查Docker容器配置和状态"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 构建format参数
    format_param = f'--format "{args.format}"' if args.format else ""

    # 执行inspect命令
    cmd = f"docker container inspect {format_param} {args.container}"
    ret_code, stdout, stderr = run_command(cmd)

    if ret_code != 0:
        print(f"检查容器失败: {stderr}")
        return 1

    # 尝试格式化JSON输出，如果可能的话
    if not args.format and stdout:
        try:
            container_info = json.loads(stdout)
            stdout = json.dumps(container_info, indent=2, ensure_ascii=False)
        except json.JSONDecodeError:
            pass

    print(stdout)
    return 0


def run_container(args):
    """运行Docker容器"""
    if not args.image:
        print("错误: 必须指定镜像名称")
        return 1

    # 构建run命令选项
    cmd_options = []

    # 容器名称
    if args.name:
        cmd_options.append(f"--name {args.name}")

    # 网络选项
    if args.network:
        cmd_options.append(f"--network {args.network}")

    # 端口映射
    if args.port:
        for port in args.port:
            cmd_options.append(f"-p {port}")

    # 数据卷映射
    if args.volume:
        for volume in args.volume:
            cmd_options.append(f"-v {volume}")

    # 环境变量
    if args.env:
        for env in args.env:
            cmd_options.append(f"-e {env}")

    # 后台运行
    if args.detach:
        cmd_options.append("-d")

    # 自动删除
    if args.rm:
        cmd_options.append("--rm")

    # 交互式
    if args.interactive:
        cmd_options.append("-i")

    # 伪终端
    if args.tty:
        cmd_options.append("-t")

    # 资源限制
    if args.memory:
        cmd_options.append(f"--memory {args.memory}")
    if args.cpus:
        cmd_options.append(f"--cpus {args.cpus}")

    # 其他选项
    if args.entrypoint:
        cmd_options.append(f"--entrypoint {args.entrypoint}")
    if args.workdir:
        cmd_options.append(f"--workdir {args.workdir}")
    if args.user:
        cmd_options.append(f"--user {args.user}")

    # 命令和参数
    command = args.command if args.command else ""

    # 构建完整命令
    options = " ".join(cmd_options)
    cmd = f"docker run {options} {args.image} {command}"

    print(f"正在运行容器: {args.image}")
    ret_code, stdout, stderr = run_command(cmd, capture_output=False)

    return ret_code


def exec_container(args):
    """在运行中的容器内执行命令"""
    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    if not args.command:
        print("错误: 必须指定要执行的命令")
        return 1

    # 构建exec命令选项
    cmd_options = []

    # 交互式
    if args.interactive:
        cmd_options.append("-i")

    # 伪终端
    if args.tty:
        cmd_options.append("-t")

    # 用户
    if args.user:
        cmd_options.append(f"--user {args.user}")

    # 工作目录
    if args.workdir:
        cmd_options.append(f"--workdir {args.workdir}")

    # 环境变量
    if args.env:
        for env in args.env:
            cmd_options.append(f"--env {env}")

    # 构建完整命令
    options = " ".join(cmd_options)
    cmd = f"docker exec {options} {args.container} {args.command}"

    print(f"在容器 {args.container} 中执行命令: {args.command}")
    ret_code, stdout, stderr = run_command(cmd, capture_output=False)

    return ret_code


def network_list(args):
    """列出Docker网络"""
    # 构建过滤条件
    filters = []
    if args.driver:
        filters.append(f"driver={args.driver}")
    if args.name:
        filters.append(f"name={args.name}")

    filter_cmd = f'--filter {" --filter ".join(filters)}' if filters else ""

    # 获取网络列表命令
    format_template = "{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}\t{{.Internal}}"
    cmd = f'docker network ls {filter_cmd} --format "{format_template}"'

    ret_code, stdout, stderr = run_command(cmd)

    if ret_code != 0:
        print(f"获取网络列表失败: {stderr}")
        return 1

    if not stdout.strip():
        print("没有找到符合条件的网络")
        return 0

    # 解析并格式化输出
    networks = []
    for line in stdout.strip().split("\n"):
        if line:
            parts = line.split("\t")
            if len(parts) >= 5:
                networks.append(
                    {
                        "ID": parts[0],
                        "名称": parts[1],
                        "驱动": parts[2],
                        "范围": parts[3],
                        "内部": parts[4],
                    }
                )

    # 使用tabulate打印表格
    if networks:
        headers = ["ID", "名称", "驱动", "范围", "内部"]
        table_data = [
            [n["ID"], n["名称"], n["驱动"], n["范围"], n["内部"]] for n in networks
        ]
        print(tabulate.tabulate(table_data, headers=headers, tablefmt="grid"))

    return 0


def network_create(args):
    """创建Docker网络"""
    if not args.name:
        print("错误: 必须指定网络名称")
        return 1

    # 构建create命令选项
    cmd_options = []

    # 网络驱动
    if args.driver:
        cmd_options.append(f"--driver {args.driver}")

    # 子网
    if args.subnet:
        cmd_options.append(f"--subnet {args.subnet}")

    # 网关
    if args.gateway:
        cmd_options.append(f"--gateway {args.gateway}")

    # IP范围
    if args.ip_range:
        cmd_options.append(f"--ip-range {args.ip_range}")

    # 内部网络
    if args.internal:
        cmd_options.append("--internal")

    # IPv6支持
    if args.ipv6:
        cmd_options.append("--ipv6")

    # 标签
    if args.label:
        for label in args.label:
            cmd_options.append(f"--label {label}")

    # 构建完整命令
    options = " ".join(cmd_options)
    cmd = f"docker network create {options} {args.name}"

    print(f"正在创建网络: {args.name}")
    ret_code, stdout, stderr = run_command(cmd)

    if ret_code == 0:
        print(f"网络 {args.name} 已创建")
        # 打印网络ID
        if stdout:
            print(f"网络ID: {stdout.strip()}")
    else:
        print(f"创建网络失败: {stderr}")

    return ret_code


def network_remove(args):
    """删除Docker网络"""
    if not args.network:
        print("错误: 必须指定网络名称或ID")
        return 1

    # 删除单个或多个网络
    success = True
    for network in args.network:
        print(f"正在删除网络: {network}")
        ret_code, stdout, stderr = run_command(f"docker network rm {network}")

        if ret_code == 0:
            print(f"网络 {network} 已删除")
        else:
            print(f"网络 {network} 删除失败: {stderr}")
            success = False

    return 0 if success else 1


def network_connect(args):
    """连接容器到网络"""
    if not args.network:
        print("错误: 必须指定网络名称")
        return 1

    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 构建连接选项
    cmd_options = []

    # 指定IP地址
    if args.ip:
        cmd_options.append(f"--ip {args.ip}")

    # 指定IPv6地址
    if args.ipv6:
        cmd_options.append(f"--ip6 {args.ipv6}")

    # 网络别名
    if args.alias:
        for alias in args.alias:
            cmd_options.append(f"--alias {alias}")

    # 连接容器到网络
    options = " ".join(cmd_options)
    cmd = f"docker network connect {options} {args.network} {args.container}"

    print(f"正在将容器 {args.container} 连接到网络 {args.network}")
    ret_code, stdout, stderr = run_command(cmd)

    if ret_code == 0:
        print(f"容器 {args.container} 已连接到网络 {args.network}")
    else:
        print(f"连接容器到网络失败: {stderr}")

    return ret_code


def network_disconnect(args):
    """断开容器与网络的连接"""
    if not args.network:
        print("错误: 必须指定网络名称")
        return 1

    if not args.container:
        print("错误: 必须指定容器名称或ID")
        return 1

    # 断开连接选项
    force_opt = "--force" if args.force else ""

    # 断开容器与网络的连接
    cmd = f"docker network disconnect {force_opt} {args.network} {args.container}"

    print(f"正在断开容器 {args.container} 与网络 {args.network} 的连接")
    ret_code, stdout, stderr = run_command(cmd)

    if ret_code == 0:
        print(f"容器 {args.container} 已从网络 {args.network} 断开连接")
    else:
        print(f"断开容器与网络的连接失败: {stderr}")

    return ret_code


def network_inspect(args):
    """查看网络详情"""
    if not args.network:
        print("错误: 必须指定网络名称或ID")
        return 1

    # 构建format参数
    format_param = f'--format "{args.format}"' if args.format else ""

    # 执行inspect命令
    cmd = f"docker network inspect {format_param} {args.network}"
    ret_code, stdout, stderr = run_command(cmd)

    if ret_code != 0:
        print(f"查看网络详情失败: {stderr}")
        return 1

    # 尝试格式化JSON输出，如果可能的话
    if not args.format and stdout:
        try:
            network_info = json.loads(stdout)
            stdout = json.dumps(network_info, indent=2, ensure_ascii=False)
        except json.JSONDecodeError:
            pass

    print(stdout)
    return 0


def add_container_management_parsers(subparsers):
    """添加容器管理相关的子命令解析器"""
    # start子命令
    start_parser = subparsers.add_parser("start", help="启动Docker容器", add_help=True)
    start_parser.add_argument("container", nargs="+", help="容器名称或ID")
    start_parser.set_defaults(func=start_container)

    # stop子命令
    stop_parser = subparsers.add_parser("stop", help="停止Docker容器", add_help=True)
    stop_parser.add_argument("container", nargs="+", help="容器名称或ID")
    stop_parser.add_argument("-t", "--time", type=int, help="等待停止的超时时间(秒)")
    stop_parser.set_defaults(func=stop_container)

    # restart子命令
    restart_parser = subparsers.add_parser(
        "restart", help="重启Docker容器", add_help=True
    )
    restart_parser.add_argument("container", nargs="+", help="容器名称或ID")
    restart_parser.add_argument("-t", "--time", type=int, help="等待停止的超时时间(秒)")
    restart_parser.set_defaults(func=restart_container)

    # rm子命令
    rm_parser = subparsers.add_parser("rm", help="删除Docker容器", add_help=True)
    rm_parser.add_argument("container", nargs="+", help="容器名称或ID")
    rm_parser.add_argument(
        "-f", "--force", action="store_true", help="强制删除正在运行的容器"
    )
    rm_parser.add_argument(
        "-v", "--volumes", action="store_true", help="删除容器关联的匿名卷"
    )
    rm_parser.set_defaults(func=remove_container)

    # pause子命令
    pause_parser = subparsers.add_parser("pause", help="暂停Docker容器", add_help=True)
    pause_parser.add_argument("container", nargs="+", help="容器名称或ID")
    pause_parser.set_defaults(func=pause_container)

    # unpause子命令
    unpause_parser = subparsers.add_parser(
        "unpause", help="恢复Docker容器", add_help=True
    )
    unpause_parser.add_argument("container", nargs="+", help="容器名称或ID")
    unpause_parser.set_defaults(func=resume_container)

    # logs子命令
    logs_parser = subparsers.add_parser(
        "logs", help="查看Docker容器日志", add_help=True
    )
    logs_parser.add_argument("container", help="容器名称或ID")
    logs_parser.add_argument("-f", "--follow", action="store_true", help="跟踪日志输出")
    logs_parser.add_argument("--tail", help="显示最后n行日志")
    logs_parser.add_argument("--since", help="显示自某时间以来的日志")
    logs_parser.add_argument("--until", help="显示直到某时间的日志")
    logs_parser.add_argument(
        "-t", "--timestamps", action="store_true", help="显示时间戳"
    )
    logs_parser.set_defaults(func=container_logs)

    # ps子命令
    ps_parser = subparsers.add_parser("ps", help="列出Docker容器", add_help=True)
    ps_parser.add_argument(
        "-a", "--all", action="store_true", help="显示所有容器（默认只显示运行中的）"
    )
    ps_parser.add_argument("--name", help="按名称过滤容器")
    ps_parser.add_argument(
        "--status",
        choices=[
            "created",
            "restarting",
            "running",
            "removing",
            "paused",
            "exited",
            "dead",
        ],
        help="按状态过滤容器",
    )
    ps_parser.set_defaults(func=container_status)

    # inspect子命令
    inspect_parser = subparsers.add_parser(
        "inspect", help="检查Docker容器配置和状态", add_help=True
    )
    inspect_parser.add_argument("container", help="容器名称或ID")
    inspect_parser.add_argument("-f", "--format", help="使用Go模板格式化输出")
    inspect_parser.set_defaults(func=container_inspect)

    # run子命令
    run_parser = subparsers.add_parser(
        "run", help="运行一个新的Docker容器", add_help=True
    )
    run_parser.add_argument("image", help="要运行的镜像")
    run_parser.add_argument("command", nargs="?", help="要运行的命令")
    run_parser.add_argument("--name", help="为容器指定名称")
    run_parser.add_argument(
        "-p", "--port", action="append", help="端口映射 (主机端口:容器端口)"
    )
    run_parser.add_argument(
        "-v", "--volume", action="append", help="数据卷映射 (主机路径:容器路径)"
    )
    run_parser.add_argument("-e", "--env", action="append", help="环境变量 (KEY=VALUE)")
    run_parser.add_argument("-d", "--detach", action="store_true", help="后台运行容器")
    run_parser.add_argument("--rm", action="store_true", help="容器停止后自动删除")
    run_parser.add_argument(
        "-i", "--interactive", action="store_true", help="交互式模式"
    )
    run_parser.add_argument("-t", "--tty", action="store_true", help="分配伪终端")
    run_parser.add_argument("--network", help="连接到指定网络")
    run_parser.add_argument("--memory", help="内存限制 (例如: 512m, 1g)")
    run_parser.add_argument("--cpus", help="CPU限制 (例如: 0.5, 1)")
    run_parser.add_argument("--entrypoint", help="覆盖镜像的ENTRYPOINT")
    run_parser.add_argument("--workdir", help="容器中的工作目录")
    run_parser.add_argument("--user", help="用户名或UID")
    run_parser.set_defaults(func=run_container)

    # exec子命令
    exec_parser = subparsers.add_parser(
        "exec", help="在运行中的容器内执行命令", add_help=True
    )
    exec_parser.add_argument("container", help="容器名称或ID")
    exec_parser.add_argument("command", help="要执行的命令")
    exec_parser.add_argument(
        "-i", "--interactive", action="store_true", help="交互式模式"
    )
    exec_parser.add_argument("-t", "--tty", action="store_true", help="分配伪终端")
    exec_parser.add_argument("--user", help="用户名或UID")
    exec_parser.add_argument("--workdir", help="容器中的工作目录")
    exec_parser.add_argument(
        "-e", "--env", action="append", help="环境变量 (KEY=VALUE)"
    )
    exec_parser.set_defaults(func=exec_container)


def add_network_management_parsers(subparsers):
    """添加网络管理相关的子命令解析器"""
    # network子命令组
    network_parser = subparsers.add_parser(
        "network", help="Docker网络管理", add_help=True
    )
    network_subparsers = network_parser.add_subparsers(dest="network_command")

    # network ls子命令
    net_ls_parser = network_subparsers.add_parser(
        "ls", help="列出Docker网络", add_help=True
    )
    net_ls_parser.add_argument("--driver", help="按驱动过滤")
    net_ls_parser.add_argument("--name", help="按名称过滤")
    net_ls_parser.set_defaults(func=network_list)

    # network create子命令
    net_create_parser = network_subparsers.add_parser(
        "create", help="创建Docker网络", add_help=True
    )
    net_create_parser.add_argument("name", help="网络名称")
    net_create_parser.add_argument(
        "--driver", "-d", default="bridge", help="驱动类型 (默认: bridge)"
    )
    net_create_parser.add_argument("--subnet", help="子网CIDR地址")
    net_create_parser.add_argument("--gateway", help="网关地址")
    net_create_parser.add_argument("--ip-range", help="分配IP的范围")
    net_create_parser.add_argument(
        "--internal", action="store_true", help="创建内部网络"
    )
    net_create_parser.add_argument("--ipv6", action="store_true", help="启用IPv6网络")
    net_create_parser.add_argument("--label", action="append", help="设置网络元数据")
    net_create_parser.set_defaults(func=network_create)

    # network rm子命令
    net_rm_parser = network_subparsers.add_parser(
        "rm", help="删除Docker网络", add_help=True
    )
    net_rm_parser.add_argument("network", nargs="+", help="网络名称或ID")
    net_rm_parser.set_defaults(func=network_remove)

    # network connect子命令
    net_connect_parser = network_subparsers.add_parser(
        "connect", help="连接容器到网络", add_help=True
    )
    net_connect_parser.add_argument("network", help="网络名称")
    net_connect_parser.add_argument("container", help="容器名称或ID")
    net_connect_parser.add_argument("--ip", help="指定IPv4地址")
    net_connect_parser.add_argument("--ipv6", help="指定IPv6地址")
    net_connect_parser.add_argument("--alias", action="append", help="网络别名")
    net_connect_parser.set_defaults(func=network_connect)

    # network disconnect子命令
    net_disconnect_parser = network_subparsers.add_parser(
        "disconnect", help="断开容器与网络的连接", add_help=True
    )
    net_disconnect_parser.add_argument("network", help="网络名称")
    net_disconnect_parser.add_argument("container", help="容器名称或ID")
    net_disconnect_parser.add_argument(
        "-f", "--force", action="store_true", help="强制断开连接"
    )
    net_disconnect_parser.set_defaults(func=network_disconnect)

    # network inspect子命令
    net_inspect_parser = network_subparsers.add_parser(
        "inspect", help="查看网络详情", add_help=True
    )
    net_inspect_parser.add_argument("network", help="网络名称或ID")
    net_inspect_parser.add_argument("-f", "--format", help="使用Go模板格式化输出")
    net_inspect_parser.set_defaults(func=network_inspect)


def create_parser():
    """
    创建命令行参数解析器

    Returns:
        argparse.ArgumentParser对象
    """
    parser = argparse.ArgumentParser(
        prog="ads docker", description="Docker管理命令", add_help=True
    )

    subparsers = parser.add_subparsers(dest="subcommand")

    # build子命令
    build_parser = subparsers.add_parser("build", help="构建Docker镜像", add_help=True)
    build_parser.add_argument("--tag", "-t", help="镜像标签")
    build_parser.add_argument("--dockerfile", "-f", help="Dockerfile路径")
    build_parser.add_argument("--context", help="构建上下文路径")
    build_parser.add_argument(
        "--build-arg", action="append", help="构建参数(KEY=VALUE)"
    )
    build_parser.add_argument("--no-cache", action="store_true", help="不使用缓存")
    build_parser.add_argument(
        "--pull", action="store_true", help="总是尝试拉取新版本的基础镜像"
    )
    build_parser.add_argument(
        "--platform", help="指定目标平台 (例如: linux/amd64, linux/arm64)"
    )
    build_parser.add_argument("--target", help="指定多阶段构建的目标阶段")
    build_parser.add_argument(
        "--network", help="设置构建期间的网络模式 (bridge, host, none)"
    )
    build_parser.add_argument(
        "--label", action="append", help="为镜像设置元数据标签(key=value)"
    )
    build_parser.add_argument(
        "--output", "-o", help="输出目标 (格式: type=local,dest=path)"
    )
    build_parser.add_argument("--compress", action="store_true", help="压缩构建上下文")
    build_parser.add_argument(
        "--progress", choices=["auto", "plain", "tty"], help="设置进度输出类型"
    )
    build_parser.add_argument(
        "--cache-from", action="append", help="外部缓存源 (例如: user/image:tag)"
    )
    build_parser.add_argument("--cache-to", help="导出构建缓存目标")
    build_parser.add_argument(
        "--secret",
        action="append",
        help="挂载密钥到构建 (格式: id=mysecret[,src=secret-file])",
    )
    build_parser.add_argument(
        "--ssh",
        action="append",
        help="挂载SSH代理套接字或密钥 (格式: default|id=value)",
    )
    build_parser.set_defaults(func=build_image)

    # optimize子命令 - Dockerfile优化
    optimize_df_parser = subparsers.add_parser(
        "optimize-dockerfile", help="优化Dockerfile", add_help=True
    )
    optimize_df_parser.add_argument("--dockerfile", "-f", help="Dockerfile路径")
    optimize_df_parser.add_argument("--output", "-o", help="输出文件路径")
    optimize_df_parser.add_argument(
        "--no-backup", action="store_true", help="不创建备份"
    )
    optimize_df_parser.set_defaults(func=optimize_dockerfile)

    # optimize子命令 - 镜像优化
    optimize_parser = subparsers.add_parser(
        "optimize", help="优化Docker镜像", add_help=True
    )
    optimize_parser.add_argument("--image", "-i", help="要优化的镜像名称")
    optimize_parser.set_defaults(func=optimize_image)

    # info子命令
    info_parser = subparsers.add_parser("info", help="显示Docker信息", add_help=True)
    info_parser.set_defaults(func=lambda args: display_docker_info())

    # version子命令
    version_parser = subparsers.add_parser(
        "version", help="显示Docker版本信息", add_help=True
    )
    version_parser.set_defaults(func=lambda args: display_docker_version())

    # help子命令
    help_parser = subparsers.add_parser("help", help="显示帮助信息", add_help=True)
    help_parser.set_defaults(func=docker_help)

    # 添加容器管理相关命令
    add_container_management_parsers(subparsers)

    # 添加网络管理相关命令
    add_network_management_parsers(subparsers)

    return parser


def display_docker_info():
    """
    显示Docker信息（直接调用docker info命令）

    Returns:
        退出码
    """
    ret_code, stdout, stderr = run_command("docker info")
    if ret_code == 0 and stdout:
        print(stdout)
        return 0
    else:
        print("无法获取Docker信息。请确保Docker已启动并可访问。")
        if stderr:
            print(f"错误信息: {stderr}")
        return 1


def display_docker_version():
    """
    显示Docker版本信息（直接调用docker version命令）

    Returns:
        退出码
    """
    ret_code, stdout, stderr = run_command("docker version")
    if ret_code == 0 and stdout:
        print(stdout)
        return 0
    else:
        print("无法获取Docker版本信息。请确保Docker已启动并可访问。")
        if stderr:
            print(f"错误信息: {stderr}")
        return 1


def main(args):
    """
    主函数

    Args:
        args: 命令行参数

    Returns:
        退出码
    """
    # 检查Docker是否安装
    if not check_docker_installed():
        print("错误: Docker未安装或者不在PATH中")
        return 1

    parser = create_parser()

    # 无参数时显示帮助
    if not args:
        return docker_help(None)

    try:
        parsed_args = parser.parse_args(args)

        # 如果指定了子命令并且有相应的处理函数
        if hasattr(parsed_args, "func"):
            return parsed_args.func(parsed_args)
        # 对于network子命令，需要特殊处理以支持子子命令
        elif parsed_args.subcommand == "network" and hasattr(
            parsed_args, "network_command"
        ):
            if parsed_args.network_command and hasattr(parsed_args, "func"):
                return parsed_args.func(parsed_args)
            else:
                # 如果没有指定network子命令，显示network帮助
                net_parser = [
                    p
                    for p in parser._subparsers._actions
                    if isinstance(p, argparse._SubParsersAction)
                ][0]
                net_parser.choices["network"].print_help()
                return 1
        else:
            parser.print_help()
            return 1
    except Exception as e:
        logger.error(f"Docker命令执行出错: {e}", exc_info=True)
        print(f"错误: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
