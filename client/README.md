# 加密货币网格交易系统

## 项目简介

加密货币网格交易系统是一个集成的交易解决方案，旨在简化加密货币的网格交易策略实施。该系统结合了现代Web技术和量化交易工具，提供了用户友好的界面来管理复杂的交易策略。

### 核心功能

- **网格交易策略**: 自动在价格波动时买入低价和卖出高价
- **多交易所支持**: 兼容多个加密货币交易所的API
- **实时市场数据**: 展示实时价格和市场深度信息
- **策略可视化**: 直观展示网格交易策略和执行情况
- **交易历史记录**: 跟踪和分析所有交易活动
- **资产管理**: 监控和管理多个加密货币资产
- **风险控制**: 内置止损和资金管理功能

## 技术架构

- **前端**: Vue.js 3 + Electron
- **后端**: Python
- **数据存储**: SQLite
- **交易引擎**: Hummingbot (Docker容器)
- **图表**: TradingView图表集成

## 快速开始

### 系统要求

- Node.js 14+
- Python 3.8+
- Docker
- Git

### 安装步骤

1. 克隆仓库:
   ```bash
   git clone https://github.com/yourusername/crypto-grid-mvp.git
   cd crypto-grid-mvp
   ```

2. 安装依赖:
   ```bash
   ./start.sh setup
   ```

3. 启动系统:
   ```bash
   ./start.sh run
   ```

## 使用指南

### 基本命令

以下是系统支持的主要命令:

- **启动系统**:
  ```bash
  ./start.sh run [dev|prod]
  ```

- **检查系统状态**:
  ```bash
  ./start.sh status
  ```

- **停止系统**:
  ```bash
  ./start.sh stop
  ```

- **本地测试**:
  ```bash
  ./start.sh local [--debug]
  ```

- **检查依赖**:
  ```bash
  ./start.sh check-deps
  ```

- **打包应用**:
  ```bash
  ./start.sh package
  ```

- **修复中文编码问题**:
  ```bash
  ./start.sh fix-encoding
  ```

### 获取帮助

可以使用以下命令获取详细帮助信息:

```bash
./start.sh help
```

或者获取特定命令的帮助:

```bash
./start.sh help-run
./start.sh help-docker
```

## 中文编码问题解决方案

在Windows环境下运行时，可能会遇到中文显示为乱码的问题。系统提供了专门的解决方案：

1. **自动修复**:
   ```bash
   ./start.sh fix-encoding
   ```
   这将自动配置必要的环境变量、修改相关脚本以确保正确处理中文。

2. **手动加载环境变量**:
   ```bash
   source .env.encoding
   ```

更多关于中文编码问题的详细信息和解决方案，请参阅 [中文编码问题解决方案](docs/中文编码问题解决方案.md)。

## 目录结构

```
crypto-grid-mvp/
├── client/                # 前端应用
│   ├── src/               # 源代码
│   │   ├── assets/        # 静态资源
│   │   ├── components/    # Vue组件
│   │   ├── main/          # Electron主进程
│   │   ├── python/        # Python后端
│   │   └── renderer/      # Electron渲染进程
│   ├── public/            # 公共资源
│   └── package.json       # 依赖配置
├── scripts/               # 脚本文件
│   ├── docker-commands.sh # Docker管理
│   ├── run-system.sh      # 系统启动
│   ├── local-test.sh      # 本地测试
│   └── help.sh            # 帮助信息
├── docs/                  # 文档
├── logs/                  # 日志目录
├── data/                  # 数据存储
├── strategy_files/        # 策略配置
├── docker-compose.yml     # Docker配置
├── start.sh               # 主启动脚本
└── README.md              # 项目说明
```

## 故障排除

如果遇到问题:

1. 检查日志文件 (`logs/` 目录)
2. 运行 `./start.sh check-deps` 验证依赖
3. 确认 Docker 正在运行并且有正确的权限
4. 如果遇到中文编码问题，运行 `./start.sh fix-encoding`

## 贡献

欢迎贡献代码、提出问题或建议改进。请遵循以下步骤:

1. Fork项目
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启Pull Request

## 许可证

该项目基于 MIT 许可证。详见 [LICENSE](LICENSE) 文件。 