# Electron-Vue-Python 应用框架

这是一个集成了Electron、Vue 3和Python的跨平台桌面应用开发框架。本框架提供了一套完整的启动脚本和环境配置工具，方便开发者快速搭建基于这三种技术的应用。本仓库中的加密货币网格交易系统仅作为框架使用示例，开发者可以基于此框架开发各种类型的应用。

## 特性

- **跨平台支持**：基于Electron，可在Windows、macOS和Linux上运行
- **现代化UI**：使用Vue 3 + TypeScript构建响应式用户界面
- **Python后端**：集成Python作为后端引擎，可利用丰富的Python生态系统
- **容器化部署**：内置Docker支持，便于开发和部署
- **完善的脚本工具**：提供一系列脚本用于环境设置、构建和部署
- **多语言支持**：内置中文编码问题解决方案
- **打包分发**：支持打包为可执行文件，方便分发

## 系统要求

- **Node.js** 14+
- **Python** 3.10+
- **Docker** (如需容器化运行)
- **Git** (用于版本控制)

## 启动脚本系统

本框架的核心是一套完善的启动脚本系统，入口为`start.sh`。这些脚本提供了全面的环境配置、应用启动、打包和部署功能。

### 启动脚本功能概览

```
./start.sh [选项]
```

#### 主要选项:
- `setup` - 设置开发环境（安装依赖）
- `run` - 构建并启动系统（默认开发模式）
- `stop` - 停止并移除所有Docker容器
- `status` - 显示所有容器状态

#### Docker相关选项:
- `build` - 构建所有容器
- `up` - 启动Docker容器（不构建）
- `down` - 停止并移除所有Docker容器
- `restart` - 重启所有服务
- `logs [服务名]` - 查看服务日志
- `prune` - 清理Docker系统

#### 特殊命令:
- `sources` - 配置npm和pip的源（官方源或国内源）
- `fix-network` - 修复Docker网络连接问题
- `fix-encoding` - 修复Windows环境下的中文编码问题

#### 打包和部署:
- `package` - 打包应用为.exe文件
- `deploy` - 部署到生产环境

### 环境配置详解

框架提供了全自动的环境配置过程，只需运行：

```bash
./start.sh setup
```

此命令会:
1. 检测系统类型（Windows/Linux/macOS）
2. 检查并安装必要的Python依赖
3. 检查Docker环境并配置网络
4. 配置npm和pip源（支持国内加速源）
5. 设置开发环境变量

### 国际化与中文支持

本框架特别处理了Windows环境下的中文编码问题，提供`fix-encoding`命令自动修复可能的编码问题：

```bash
./start.sh fix-encoding
```

## 目录结构

```
project/
├── client/               # 客户端代码
│   ├── src/              # 源代码
│   │   ├── main/         # Electron主进程
│   │   ├── renderer/     # Vue 3前端
│   │   └── python/       # Python后端
│   ├── assets/           # 资源文件
│   ├── scripts/          # 客户端脚本
│   └── Dockerfile        # 客户端Docker配置
├── scripts/              # 系统脚本
│   ├── setup-environment.sh  # 环境设置脚本
│   ├── run-system.sh     # 系统运行脚本
│   └── ...               # 其他功能脚本
├── docs/                 # 文档
├── start.sh              # 主启动脚本
└── docker-compose.yml    # Docker组合配置
```

## 开发指南

### 1. 设置环境

```bash
# 克隆仓库
git clone <repository-url>
cd <repository-name>

# 设置环境
./start.sh setup
```

### 2. 启动开发服务器

```bash
./start.sh run
```

### 3. 打包应用

```bash
./start.sh package
```

## 基于此框架开发新应用

本框架可用于开发各种类型的应用，不仅限于加密货币交易系统：

1. 修改`client/src/`目录下的Vue组件和Python脚本
2. 调整`client/package.json`中的应用信息
3. 根据需要编辑`docker-compose.yml`添加所需服务
4. 使用`start.sh`脚本管理开发和部署过程

## 常见问题解决

- **中文显示问题**: 使用`./start.sh fix-encoding`修复
- **npm包下载慢**: 使用`./start.sh sources`切换到国内源
- **Docker网络问题**: 使用`./start.sh fix-network`诊断和修复

## 贡献指南

欢迎贡献代码、报告问题或提出建议。请遵循以下步骤：

1. Fork本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建Pull Request

## 许可证

[MIT License](LICENSE)

## 致谢

- [Electron](https://www.electronjs.org/)
- [Vue.js](https://vuejs.org/)
- [Python](https://www.python.org/)
- 所有贡献者与支持者 