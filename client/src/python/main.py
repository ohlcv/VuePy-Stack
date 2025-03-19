# -*- coding: utf-8 -*-

# -*- coding: utf-8 -*-

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import time
import yaml
import docker
from docker import errors as docker_errors
import sqlite3
import requests
import argparse
from loguru import logger
from pathlib import Path
import ccxt
import threading
import uuid

# 配置日志
log_path = Path("logs")
log_path.mkdir(exist_ok=True)
logger.remove()  # 移除默认处理器
logger.add(sys.stderr, level="INFO")  # 添加标准错误输出处理器
logger.add(
    log_path / "crypto_grid_{time}.log", rotation="10 MB", level="DEBUG"
)  # 添加文件处理器


class HummingbotManager:
    def __init__(self):
        """初始化Hummingbot管理器"""

        # 确保目录存在
        Path("logs").mkdir(exist_ok=True)
        Path("data").mkdir(exist_ok=True)
        Path("strategy_files").mkdir(exist_ok=True)

        try:
            self.docker_client = docker.from_env()
            # 验证Docker连接
            self.docker_client.ping()
            logger.info("Docker连接成功")
        except Exception as e:
            logger.error(f"Docker连接失败: {e}")
            raise RuntimeError(f"Docker连接失败: {e}")

        # 初始化数据库连接
        self.init_db()

    def init_db(self):
        """初始化SQLite数据库"""
        try:
            db_path = Path("data")
            db_path.mkdir(exist_ok=True)

            # 使用绝对路径确保在任何工作目录下都能正确访问数据库
            db_file = (db_path / "crypto_grid.db").absolute()
            logger.info(f"数据库路径: {db_file}")

            # 设置连接，启用外键约束，使用WAL模式提高并发性能
            self.conn = sqlite3.connect(
                db_file, check_same_thread=False, isolation_level=None
            )
            self.conn.execute("PRAGMA foreign_keys = ON")
            self.conn.execute("PRAGMA journal_mode = WAL")

            cursor = self.conn.cursor()
            # 创建策略表
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS strategies (
                    id TEXT PRIMARY KEY,
                    name TEXT,
                    exchange TEXT,
                    trading_pair TEXT,
                    status TEXT,
                    config TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            self.conn.commit()
            logger.info("数据库初始化成功")
        except sqlite3.Error as e:
            logger.error(f"数据库错误: {e}")
            raise RuntimeError(f"数据库初始化失败: {e}")
        except Exception as e:
            logger.error(f"数据库初始化失败: {e}")
            raise RuntimeError(f"数据库初始化失败: {e}")

    def validate_exchange_connection(self, exchange_id, api_key=None, secret=None):
        """验证交易所API连接

        Args:
            exchange_id: 交易所ID (如 'binance', 'kucoin')
            api_key: API密钥 (可选，用于验证认证)
            secret: API密钥 (可选，用于验证认证)

        Returns:
            (bool, str): (是否成功, 消息)
        """
        try:
            # 使用ccxt库验证交易所连接
            if exchange_id not in ccxt.exchanges:
                return False, f"不支持的交易所: {exchange_id}"

            # 创建交易所实例
            exchange_class = getattr(ccxt, exchange_id)
            exchange_instance = exchange_class(
                {"enableRateLimit": True, "apiKey": api_key, "secret": secret}
            )

            # 测试公共API
            markets = exchange_instance.load_markets()
            logger.info(f"成功连接到{exchange_id}交易所，获取到{len(markets)}个交易对")
            return True, f"成功连接到{exchange_id}交易所"
        except Exception as e:
            logger.error(f"交易所连接测试失败: {e}")
            return False, f"交易所连接测试失败: {e}"

    def validate_hummingbot_config(self, config_path):
        """验证Hummingbot配置文件格式是否正确

        Args:
            config_path: 配置文件路径

        Returns:
            (bool, str): (是否成功, 消息)
        """
        try:
            with open(config_path, "r") as f:
                config = yaml.safe_load(f)

            # 验证必要字段
            required_fields = ["exchange", "trading_pair"]
            for field in required_fields:
                if field not in config:
                    return False, f"配置缺少必要字段: {field}"

            # 验证交易所是否支持
            if config["exchange"] not in ccxt.exchanges:
                return False, f"不支持的交易所: {config['exchange']}"

            # 验证交易对格式
            if "-" not in config["trading_pair"]:
                return False, f"交易对格式错误，应为BASE-QUOTE格式，如BTC-USDT"

            logger.info(f"配置验证通过: {config_path}")
            return True, "配置验证通过"
        except Exception as e:
            logger.error(f"配置验证失败: {e}")
            return False, f"配置验证失败: {e}"

    def create_hummingbot(self, strategy_data):
        """创建Hummingbot容器

        Args:
            strategy_data: 策略数据字典，包含以下字段：
                - exchange: 交易所ID (必须)
                - pair: 交易对 (必须)
                - name: 策略名称 (可选)
                - gridType: 网格类型，arithmetic 或 geometric (可选)
                - upperPrice: 上限价格 (必须)
                - lowerPrice: 下限价格 (必须)
                - gridCount: 网格数量 (可选)
                - amountPerGrid: 每格金额 (可选)

        Returns:
            dict: 结果信息
        """
        try:
            # 从策略数据中提取信息
            exchange = strategy_data.get("exchange")
            pair = strategy_data.get("pair")
            name = strategy_data.get(
                "name", f"策略_{exchange}_{pair}" if exchange and pair else "未命名策略"
            )

            # 校验必要参数
            if not exchange:
                return {"success": False, "message": "缺少必要参数：交易所"}
            if not pair:
                return {"success": False, "message": "缺少必要参数：交易对"}

            # 验证价格参数
            upper_price = strategy_data.get("upperPrice")
            lower_price = strategy_data.get("lowerPrice")

            if not upper_price:
                return {"success": False, "message": "缺少必要参数：上限价格"}
            if not lower_price:
                return {"success": False, "message": "缺少必要参数：下限价格"}

            try:
                upper_price = float(upper_price)
                lower_price = float(lower_price)

                if upper_price <= lower_price:
                    return {"success": False, "message": "上限价格必须大于下限价格"}
                if upper_price <= 0 or lower_price <= 0:
                    return {"success": False, "message": "价格必须大于0"}
            except ValueError:
                return {"success": False, "message": "价格格式错误，必须为数值"}

            # 进行简单的网络连通性检查
            try:
                logger.info("检查网络连接...")
                response = requests.get("https://www.google.com", timeout=5)
                if response.status_code >= 400:
                    logger.warning(f"网络连接测试返回状态码: {response.status_code}")
            except requests.exceptions.RequestException as e:
                logger.warning(f"网络连通性检查失败，但将继续尝试操作: {e}")
                # 我们只记录警告，但不阻止后续操作，因为可能是特定网站的问题

            # 验证交易所连接
            conn_success, conn_msg = self.validate_exchange_connection(exchange)
            if not conn_success:
                return {"success": False, "message": conn_msg}

            # 生成策略ID和配置目录
            strategy_id = str(uuid.uuid4())[:8]
            config_dir = Path("strategy_files") / strategy_id
            config_dir.mkdir(parents=True, exist_ok=True)

            # 创建配置文件
            config_path = config_dir / "conf_grid.yml"

            # 从策略数据中提取网格参数
            grid_type = strategy_data.get("gridType", "arithmetic")
            grid_count = strategy_data.get("gridCount", 10)
            amount_per_grid = strategy_data.get("amountPerGrid", 10)

            # 校验网格参数
            try:
                grid_count = int(grid_count)
                if grid_count <= 1:
                    return {"success": False, "message": "网格数量必须大于1"}
            except ValueError:
                return {"success": False, "message": "网格数量格式错误，必须为整数"}

            try:
                amount_per_grid = float(amount_per_grid)
                if amount_per_grid <= 0:
                    return {"success": False, "message": "每格金额必须大于0"}
            except ValueError:
                return {"success": False, "message": "每格金额格式错误，必须为数值"}

            config = {
                "exchange": exchange,
                "trading_pair": pair,
                "grid_type": grid_type,
                "upper_price": upper_price,
                "lower_price": lower_price,
                "grid_count": grid_count,
                "amount_per_grid": amount_per_grid,
                "name": name,
            }

            # 添加策略数据中的其他参数
            for key, value in strategy_data.items():
                if key not in config and key not in [
                    "exchange",
                    "pair",
                    "upperPrice",
                    "lowerPrice",
                    "gridType",
                    "gridCount",
                    "amountPerGrid",
                    "name",
                ]:
                    config[key] = value

            logger.info(f"创建策略配置: {config}")
            with open(config_path, "w") as f:
                yaml.dump(config, f)

            # 验证配置
            valid, msg = self.validate_hummingbot_config(config_path)
            if not valid:
                return {"success": False, "message": msg}

            # 检查是否已存在同名容器
            container_name = f"hummingbot_{strategy_id}"
            existing_containers = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )

            if existing_containers:
                logger.warning(f"容器{container_name}已存在，将被移除")
                for container in existing_containers:
                    container.remove(force=True)

            # 使用latest标签
            hummingbot_image = "hummingbot/hummingbot:latest"

            # 检查镜像是否存在，如果不存在则提示用户
            try:
                # 检查镜像是否存在
                try:
                    self.docker_client.images.get(hummingbot_image)
                    logger.info(f"已找到镜像: {hummingbot_image}")
                except docker_errors.ImageNotFound:
                    # 如果镜像不存在，则提示用户
                    logger.warning(f"镜像不存在: {hummingbot_image}")
                    return {
                        "success": False,
                        "message": f"Hummingbot镜像不存在，请运行 'python src/python/main.py --pull-image' 拉取镜像",
                    }

                # 创建容器
                container = self.docker_client.containers.run(
                    hummingbot_image,
                    name=container_name,
                    detach=True,
                    volumes={str(config_dir.absolute()): "/conf"},
                )

                # 记录到数据库
                cursor = self.conn.cursor()
                cursor.execute(
                    "INSERT OR REPLACE INTO strategies VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
                    (strategy_id, name, exchange, pair, "running", json.dumps(config)),
                )
                self.conn.commit()

                # 检查容器ID是否存在
                container_id = getattr(container, "id", None)
                if container_id:
                    logger.info(
                        f"容器{container_name}创建成功，ID: {container_id[:12]}"
                    )
                else:
                    logger.info(f"容器{container_name}创建成功，无法获取ID")

                return {
                    "success": True,
                    "message": f"容器{container_name}创建成功",
                    "strategy_id": strategy_id,
                    "name": name,
                    "exchange": exchange,
                    "pair": pair,
                    "config": config,
                }
            except docker_errors.APIError as api_error:
                logger.error(f"Docker API错误: {api_error}")
                # 清理配置目录
                import shutil

                shutil.rmtree(config_dir, ignore_errors=True)
                return {
                    "success": False,
                    "message": f"创建Hummingbot容器失败: {api_error}",
                }
            except Exception as e:
                logger.error(f"创建Hummingbot容器失败: {e}")
                # 清理配置目录
                import shutil

                shutil.rmtree(config_dir, ignore_errors=True)
                return {"success": False, "message": f"创建Hummingbot容器失败: {e}"}
        except Exception as e:
            logger.error(f"创建Hummingbot容器失败: {e}")
            return {"success": False, "message": f"创建Hummingbot容器失败: {e}"}

    def get_container_status(self, strategy_id):
        """获取容器状态

        Args:
            strategy_id: 策略ID

        Returns:
            dict: 容器状态信息
        """
        try:
            container_name = f"hummingbot_{strategy_id}"
            containers = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )

            if not containers:
                return {"status": "not_found", "message": f"容器{container_name}不存在"}

            container = containers[0]
            logs = container.logs(tail=10).decode("utf-8")

            return {
                "status": container.status,
                "id": container.id[:12],
                "created": container.attrs["Created"],
                "logs": logs,
            }
        except Exception as e:
            logger.error(f"获取容器状态失败: {e}")
            return {"status": "error", "message": str(e)}

    def get_strategies(self):
        """获取所有策略

        Returns:
            list: 策略列表
        """
        try:
            cursor = self.conn.cursor()
            cursor.execute("SELECT * FROM strategies")
            rows = cursor.fetchall()

            strategies = []
            for row in rows:
                strategy = {
                    "id": row[0],
                    "name": row[1],
                    "exchange": row[2],
                    "pair": row[3],
                    "status": row[4],
                    "config": json.loads(row[5]) if row[5] else {},
                    "created_at": row[6],
                }

                # 获取容器状态
                container_status = self.get_container_status(row[0])
                strategy["container_status"] = container_status.get("status", "unknown")

                strategies.append(strategy)

            return strategies
        except Exception as e:
            logger.error(f"获取策略列表失败: {e}")
            return []

    def start_strategy(self, strategy_id):
        """启动策略容器

        Args:
            strategy_id: 策略ID

        Returns:
            dict: 结果信息
        """
        try:
            container_name = f"hummingbot_{strategy_id}"
            containers = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )

            if not containers:
                return {"success": False, "message": f"容器{container_name}不存在"}

            container = containers[0]

            if container.status == "running":
                return {"success": True, "message": f"容器{container_name}已经在运行中"}

            container.start()

            # 更新数据库状态
            cursor = self.conn.cursor()
            cursor.execute(
                "UPDATE strategies SET status = ? WHERE id = ?",
                ("running", strategy_id),
            )
            self.conn.commit()

            return {"success": True, "message": f"容器{container_name}已启动"}
        except Exception as e:
            logger.error(f"启动策略容器失败: {e}")
            return {"success": False, "message": f"启动策略容器失败: {e}"}

    def stop_strategy(self, strategy_id):
        """停止策略容器

        Args:
            strategy_id: 策略ID

        Returns:
            dict: 结果信息
        """
        try:
            container_name = f"hummingbot_{strategy_id}"
            containers = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )

            if not containers:
                return {"success": False, "message": f"容器{container_name}不存在"}

            container = containers[0]

            if container.status != "running":
                return {"success": True, "message": f"容器{container_name}已经停止"}

            container.stop()

            # 更新数据库状态
            cursor = self.conn.cursor()
            cursor.execute(
                "UPDATE strategies SET status = ? WHERE id = ?",
                ("stopped", strategy_id),
            )
            self.conn.commit()

            return {"success": True, "message": f"容器{container_name}已停止"}
        except Exception as e:
            logger.error(f"停止策略容器失败: {e}")
            return {"success": False, "message": f"停止策略容器失败: {e}"}

    def delete_strategy(self, strategy_id):
        """删除策略

        Args:
            strategy_id: 策略ID

        Returns:
            dict: 结果信息
        """
        try:
            # 先尝试停止并删除容器
            container_name = f"hummingbot_{strategy_id}"
            containers = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )

            if containers:
                container = containers[0]
                container.remove(force=True)

            # 删除策略目录
            config_dir = Path("strategy_files") / strategy_id
            if config_dir.exists():
                import shutil

                shutil.rmtree(config_dir)

            # 删除数据库记录
            cursor = self.conn.cursor()
            cursor.execute("DELETE FROM strategies WHERE id = ?", (strategy_id,))
            self.conn.commit()

            return {"success": True, "message": f"策略{strategy_id}已删除"}
        except Exception as e:
            logger.error(f"删除策略失败: {e}")
            return {"success": False, "message": f"删除策略失败: {e}"}

    def get_exchanges(self):
        """获取支持的交易所列表

        Returns:
            list: 交易所列表
        """
        try:
            exchanges = []
            for exchange_id in ccxt.exchanges:
                exchanges.append({"id": exchange_id, "name": exchange_id.capitalize()})
            return exchanges
        except Exception as e:
            logger.error(f"获取交易所列表失败: {e}")
            return []

    def get_trading_pairs(self, exchange, testnet=False):
        """获取交易所的交易对

        Args:
            exchange: 交易所ID
            testnet: 是否使用测试网

        Returns:
            list: 交易对列表
        """
        try:
            if exchange not in ccxt.exchanges:
                return []

            exchange_class = getattr(ccxt, exchange)
            exchange_instance = exchange_class(
                {"enableRateLimit": True, "options": {"defaultType": "spot"}}
            )

            if testnet and hasattr(exchange_instance, "set_sandbox_mode"):
                exchange_instance.set_sandbox_mode(True)

            markets = exchange_instance.load_markets()

            pairs = []
            for symbol in markets:
                # 使用标准格式如 BTC/USDT
                pairs.append(symbol)

            return pairs
        except Exception as e:
            logger.error(f"获取交易对失败: {e}")
            return []

    def get_monitor_data(self):
        """获取监控数据

        Returns:
            dict: 监控数据
        """
        try:
            # 在这里，我们返回一些模拟数据作为示例
            # 实际应用中，这些数据应该从Hummingbot容器或数据库中获取

            # 获取运行中的策略数量
            cursor = self.conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM strategies WHERE status = 'running'")
            running_count = cursor.fetchone()[0]

            # 模拟监控数据
            monitor_data = {
                "stats": {
                    "runningCount": running_count,
                    "todayTradesCount": 12,
                    "todayProfit": 28.56,
                    "totalProfit": 105.32,
                    "chartData": [
                        {"date": "2023-05-01", "profit": 12.5},
                        {"date": "2023-05-02", "profit": -5.2},
                        {"date": "2023-05-03", "profit": 8.7},
                        {"date": "2023-05-04", "profit": 15.3},
                        {"date": "2023-05-05", "profit": -3.1},
                        {"date": "2023-05-06", "profit": 7.6},
                        {"date": "2023-05-07", "profit": 10.2},
                    ],
                },
                "trades": [
                    {
                        "id": "1",
                        "time": "2023-05-07 10:22:45",
                        "strategyName": "网格策略_BTC_USDT",
                        "pair": "BTC/USDT",
                        "type": "买入",
                        "price": 28350.5,
                        "amount": 0.01,
                        "total": 283.505,
                        "profit": 0.0,
                    },
                    {
                        "id": "2",
                        "time": "2023-05-07 11:15:32",
                        "strategyName": "网格策略_BTC_USDT",
                        "pair": "BTC/USDT",
                        "type": "卖出",
                        "price": 28420.3,
                        "amount": 0.01,
                        "total": 284.203,
                        "profit": 0.698,
                    },
                    {
                        "id": "3",
                        "time": "2023-05-07 13:45:17",
                        "strategyName": "网格策略_ETH_USDT",
                        "pair": "ETH/USDT",
                        "type": "买入",
                        "price": 1860.2,
                        "amount": 0.05,
                        "total": 93.01,
                        "profit": 0.0,
                    },
                    {
                        "id": "4",
                        "time": "2023-05-07 14:22:08",
                        "strategyName": "网格策略_ETH_USDT",
                        "pair": "ETH/USDT",
                        "type": "卖出",
                        "price": 1871.5,
                        "amount": 0.05,
                        "total": 93.575,
                        "profit": 0.565,
                    },
                    {
                        "id": "5",
                        "time": "2023-05-07 15:10:45",
                        "strategyName": "网格策略_BTC_USDT",
                        "pair": "BTC/USDT",
                        "type": "买入",
                        "price": 28300.1,
                        "amount": 0.01,
                        "total": 283.001,
                        "profit": 0.0,
                    },
                ],
            }

            return monitor_data
        except Exception as e:
            logger.error(f"获取监控数据失败: {e}")
            return {"stats": {}, "trades": []}

    def get_dashboard_data(self):
        """获取首页数据

        Returns:
            dict: 首页数据
        """
        try:
            # 在这里，我们返回一些模拟数据作为示例
            # 获取运行中的策略数量
            cursor = self.conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM strategies WHERE status = 'running'")
            running_count = cursor.fetchone()[0]

            dashboard_data = {
                "stats": {
                    "totalStrategies": running_count,
                    "todayTrades": 5,
                    "totalProfit": 42.16,
                },
                "recentTrades": [
                    {
                        "id": "1",
                        "time": "2023-05-07 15:10:45",
                        "strategyName": "网格策略_BTC_USDT",
                        "pair": "BTC/USDT",
                        "type": "买入",
                        "price": "28300.10",
                        "amount": "0.0100",
                        "profit": "0.00",
                    },
                    {
                        "id": "2",
                        "time": "2023-05-07 14:22:08",
                        "strategyName": "网格策略_ETH_USDT",
                        "pair": "ETH/USDT",
                        "type": "卖出",
                        "price": "1871.50",
                        "amount": "0.0500",
                        "profit": "0.57",
                    },
                    {
                        "id": "3",
                        "time": "2023-05-07 13:45:17",
                        "strategyName": "网格策略_ETH_USDT",
                        "pair": "ETH/USDT",
                        "type": "买入",
                        "price": "1860.20",
                        "amount": "0.0500",
                        "profit": "0.00",
                    },
                ],
            }

            return dashboard_data
        except Exception as e:
            logger.error(f"获取首页数据失败: {e}")
            return {"stats": {}, "recentTrades": []}

    def close(self):
        """关闭资源"""
        if hasattr(self, "conn") and self.conn:
            self.conn.close()
            logger.info("数据库连接已关闭")

    def check_or_pull_hummingbot_image(self, image_tag="latest"):
        """检查Hummingbot镜像是否存在，如果不存在则拉取

        Args:
            image_tag: 镜像标签，默认为latest

        Returns:
            tuple: (bool, str) - (镜像是否可用, 消息)
        """
        hummingbot_image = f"hummingbot/hummingbot:{image_tag}"

        try:
            # 检查镜像是否存在
            self.docker_client.images.get(hummingbot_image)
            logger.info(f"镜像{hummingbot_image}已存在")
            return True, f"镜像{hummingbot_image}已存在"
        except docker_errors.ImageNotFound:
            logger.warning(f"镜像{hummingbot_image}不存在，尝试拉取...")

            # 检查是否指定了拉取镜像
            if "--pull-image" not in sys.argv:
                logger.info("未指定--pull-image参数，跳过拉取")
                return (
                    False,
                    f"镜像{hummingbot_image}不存在，请使用 --pull-image 参数拉取",
                )

            # 拉取镜像，添加重试逻辑
            max_retries = 3
            retry_delay = 2  # 初始重试延迟（秒）

            for attempt in range(max_retries):
                try:
                    logger.info(
                        f"正在拉取镜像 {hummingbot_image}，尝试 {attempt + 1}/{max_retries}"
                    )
                    # 检查网络连接
                    try:
                        response = requests.get("https://hub.docker.com", timeout=5)
                        if response.status_code >= 400:
                            logger.warning(
                                f"访问Docker Hub返回状态码: {response.status_code}"
                            )
                    except requests.exceptions.RequestException as e:
                        logger.warning(f"网络连接测试失败: {e}")
                        if (
                            "forcibly closed" in str(e).lower()
                            or "timeout" in str(e).lower()
                        ):
                            logger.error(
                                "网络连接被强制关闭或超时，可能需要检查网络设置或代理配置"
                            )
                            if attempt < max_retries - 1:
                                logger.info(f"等待 {retry_delay} 秒后重试...")
                                time.sleep(retry_delay)
                                retry_delay *= 2  # 指数退避
                                continue
                            else:
                                return False, f"网络连接问题，无法拉取镜像: {e}"

                    # 尝试拉取镜像
                    pull_result = self.docker_client.images.pull(
                        "hummingbot/hummingbot", tag=image_tag
                    )
                    if pull_result:
                        logger.info(f"成功拉取镜像{hummingbot_image}")
                        return True, f"成功拉取镜像{hummingbot_image}"
                    else:
                        logger.warning(f"镜像拉取结果为空，可能出现问题")
                        if attempt < max_retries - 1:
                            logger.info(f"等待 {retry_delay} 秒后重试...")
                            time.sleep(retry_delay)
                            retry_delay *= 2  # 指数退避
                            continue
                        else:
                            return False, "镜像拉取结果为空，请检查Docker服务状态"
                except docker_errors.APIError as api_error:
                    error_msg = str(api_error).lower()
                    if (
                        "connection" in error_msg
                        or "timeout" in error_msg
                        or "forcibly closed" in error_msg
                    ):
                        logger.warning(f"Docker API网络错误: {api_error}")
                        if attempt < max_retries - 1:
                            logger.info(f"等待 {retry_delay} 秒后重试...")
                            time.sleep(retry_delay)
                            retry_delay *= 2
                            continue
                        else:
                            return (
                                False,
                                f"Docker API网络错误，达到最大重试次数: {api_error}",
                            )
                    else:
                        logger.error(f"Docker API错误: {api_error}")
                        return False, f"Docker API错误: {api_error}"
                except requests.exceptions.ConnectionError as conn_error:
                    logger.warning(f"网络连接错误: {conn_error}")
                    if attempt < max_retries - 1:
                        logger.info(f"等待 {retry_delay} 秒后重试...")
                        time.sleep(retry_delay)
                        retry_delay *= 2
                        continue
                    else:
                        return False, f"网络连接错误，达到最大重试次数: {conn_error}"
                except Exception as pull_error:
                    logger.error(f"拉取镜像{hummingbot_image}失败: {pull_error}")
                    return False, f"拉取镜像失败: {pull_error}"

            return (
                False,
                f"拉取镜像{hummingbot_image}失败，达到最大重试次数，请检查网络连接",
            )
        except Exception as e:
            logger.error(f"检查Hummingbot镜像失败: {e}")
            return False, f"检查Hummingbot镜像失败: {e}"


class IPCHandler:
    """IPC通信处理类，用于与Electron通信"""

    def __init__(self):
        """初始化IPC处理器"""
        self.manager = None
        logger.info("IPCHandler 初始化")

    def start_manager(self):
        """启动Hummingbot管理器"""
        try:
            logger.info("开始初始化 HummingbotManager")
            self.manager = HummingbotManager()
            logger.info("HummingbotManager 初始化成功")
            return {"success": True, "message": "管理器启动成功"}
        except Exception as e:
            logger.error(f"启动管理器失败: {e}")
            return {"success": False, "message": str(e)}

    def handle_request(self, request_str):
        """处理IPC请求

        Args:
            request_str: JSON格式的请求字符串

        Returns:
            str: JSON格式的响应字符串
        """
        try:
            logger.debug(f"收到请求: {request_str}")
            request = json.loads(request_str)
            request_id = request.get("requestId")
            method = request.get("method")
            args = request.get("args", [])

            if not self.manager and method != "init":
                logger.info("管理器未初始化，正在自动初始化...")
                self.manager = HummingbotManager()

            logger.info(f"处理方法调用: {method}, 参数: {args}")
            result = self.dispatch_method(method, args)
            logger.debug(f"方法 {method} 执行结果: {result}")

            response = {"requestId": request_id, "result": result}
            response_json = json.dumps(response)
            logger.debug(
                f"返回响应: {response_json[:200]}..."
            )  # 只记录响应的前200个字符，避免日志过大
            return response_json
        except json.JSONDecodeError as e:
            logger.error(f"JSON解析失败: {e}, 原始请求: {request_str}")
            error_response = {"requestId": None, "error": f"无效的JSON格式: {e}"}
            return json.dumps(error_response)
        except Exception as e:
            logger.error(f"处理IPC请求失败: {e}")
            error_response = {
                "requestId": (
                    request.get("requestId") if "request" in locals() else None
                ),
                "error": str(e),
            }
            return json.dumps(error_response)

    def dispatch_method(self, method, args):
        """分发方法调用

        Args:
            method: 方法名
            args: 参数列表

        Returns:
            任意类型: 方法调用结果
        """
        # 初始化方法不需要管理器实例
        if method == "init":
            logger.info("调用init方法")
            return self.start_manager()

        # 其他方法需要管理器实例
        if not self.manager:
            logger.error("管理器未初始化")
            raise RuntimeError("管理器未初始化")

        # 根据方法名分发
        if method == "get_strategies":
            logger.info("调用get_strategies方法")
            return self.manager.get_strategies()
        elif method == "create_strategy":
            logger.info(f"调用create_strategy方法，参数: {args[0]}")
            return self.manager.create_hummingbot(args[0])
        elif method == "start_strategy":
            logger.info(f"调用start_strategy方法，策略ID: {args[0]}")
            return self.manager.start_strategy(args[0])
        elif method == "stop_strategy":
            logger.info(f"调用stop_strategy方法，策略ID: {args[0]}")
            return self.manager.stop_strategy(args[0])
        elif method == "delete_strategy":
            logger.info(f"调用delete_strategy方法，策略ID: {args[0]}")
            return self.manager.delete_strategy(args[0])
        elif method == "get_exchanges":
            logger.info("调用get_exchanges方法")
            return self.manager.get_exchanges()
        elif method == "get_trading_pairs":
            testnet = args[1] if len(args) > 1 else False
            logger.info(
                f"调用get_trading_pairs方法，交易所: {args[0]}, 测试网: {testnet}"
            )
            return self.manager.get_trading_pairs(args[0], testnet)
        elif method == "get_monitor_data":
            logger.info("调用get_monitor_data方法")
            return self.manager.get_monitor_data()
        elif method == "get_dashboard_data":
            logger.info("调用get_dashboard_data方法")
            return self.manager.get_dashboard_data()
        elif method == "validate_exchange_connection":
            logger.info(f"调用validate_exchange_connection方法，交易所: {args[0]}")
            api_key = args[1] if len(args) > 1 else None
            secret = args[2] if len(args) > 2 else None
            return self.manager.validate_exchange_connection(args[0], api_key, secret)
        elif method == "check_or_pull_hummingbot_image":
            logger.info("调用check_or_pull_hummingbot_image方法")
            tag = args[0] if args else "latest"
            success, msg = self.manager.check_or_pull_hummingbot_image(tag)
            return {"success": success, "message": msg}
        else:
            logger.error(f"未知方法: {method}")
            raise ValueError(f"未知方法: {method}")


# 全局IPC处理器
ipc_handler = None


def start_ipc_server():
    """启动IPC服务器，用于处理来自Electron的请求"""
    global ipc_handler

    logger.info("正在启动IPC服务器...")
    ipc_handler = IPCHandler()

    # 通知Electron进程Python已准备就绪
    logger.info("向Electron发送就绪信号")
    print("IPC_READY")
    sys.stdout.flush()

    logger.info("开始监听来自Electron的请求...")
    # 从标准输入读取请求
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            # 处理请求
            logger.debug(f"接收到请求行: {line[:100]}...")  # 只记录请求的前100个字符
            response = ipc_handler.handle_request(line)

            # 发送响应
            logger.debug(f"发送响应: {response[:100]}...")  # 只记录响应的前100个字符
            print(response)
            sys.stdout.flush()
        except Exception as e:
            logger.error(f"处理IPC请求失败: {e}")
            error_response = {"error": str(e)}
            print(json.dumps(error_response))
            sys.stdout.flush()

        logger.debug("请求处理完成，等待下一个请求...")


if __name__ == "__main__":
    # 解析命令行参数
    parser = argparse.ArgumentParser(description="CryptoGrid Python引擎")
    parser.add_argument("--ipc", action="store_true", help="启动IPC服务器")
    parser.add_argument("command", nargs="?", help="命令: create, status, cleanup")
    parser.add_argument("args", nargs="*", help="命令参数")
    parser.add_argument(
        "--pull-image", action="store_true", help="强制拉取最新的Hummingbot镜像"
    )
    parser.add_argument("--debug", action="store_true", help="启用调试日志")
    parser.add_argument("--log-file", help="日志文件路径")

    args = parser.parse_args()

    # 配置日志级别
    if args.debug:
        logger.remove()  # 移除默认处理器
        logger.add(sys.stderr, level="DEBUG")  # 添加标准错误输出处理器
        if args.log_file:
            logger.add(args.log_file, rotation="10 MB", level="DEBUG")
        else:
            logger.add(
                log_path / "crypto_grid_debug_{time}.log",
                rotation="10 MB",
                level="DEBUG",
            )

    # 打印版本和环境信息
    logger.info("CryptoGrid Python引擎 v1.0.0")
    logger.info(f"Python版本: {sys.version}")
    logger.info(f"操作系统: {os.name} {sys.platform}")
    logger.info(f"命令行参数: {args}")

    try:
        if args.ipc:
            # 启动IPC服务器
            logger.info("启动IPC服务器模式")
            start_ipc_server()
        elif args.command:
            # 初始化管理器
            logger.info("初始化Hummingbot管理器")
            try:
                manager = HummingbotManager()
                logger.info("Hummingbot管理器初始化成功")
            except Exception as e:
                logger.error(f"初始化Hummingbot管理器失败: {e}")
                print(json.dumps({"success": False, "message": f"初始化失败: {e}"}))
                sys.exit(1)

            # 如果指定了拉取镜像，首先拉取最新镜像
            if args.pull_image:
                logger.info("正在拉取最新的Hummingbot镜像...")
                try:
                    success, msg = manager.check_or_pull_hummingbot_image("latest")
                    if success:
                        logger.info(f"镜像拉取成功: {msg}")
                    else:
                        logger.error(f"镜像拉取失败: {msg}")
                        print(
                            json.dumps(
                                {"success": False, "message": f"镜像拉取失败: {msg}"}
                            )
                        )
                        sys.exit(1)
                except Exception as e:
                    logger.error(f"拉取镜像过程中发生错误: {e}")
                    print(
                        json.dumps({"success": False, "message": f"拉取镜像错误: {e}"})
                    )
                    sys.exit(1)

            # 处理命令
            if args.command == "create" and len(args.args) >= 2:
                # 创建策略
                exchange, pair = args.args[0], args.args[1]
                logger.info(f"正在创建策略: {exchange} {pair}")

                # 获取可选参数
                strategy_data = {
                    "exchange": exchange,
                    "pair": pair,
                    "name": f"策略_{exchange}_{pair}",
                }

                # 添加额外参数（如果提供）
                if len(args.args) > 2:
                    try:
                        extra_args = json.loads(args.args[2])
                        strategy_data.update(extra_args)
                    except json.JSONDecodeError:
                        logger.warning(f"无法解析额外参数: {args.args[2]}")

                result = manager.create_hummingbot(strategy_data)
                print(json.dumps(result))
            elif args.command == "status" and len(args.args) >= 1:
                # 获取策略状态
                strategy_id = args.args[0]
                logger.info(f"正在获取策略状态: {strategy_id}")
                result = manager.get_container_status(strategy_id)
                print(json.dumps(result))
            elif args.command == "list":
                # 获取所有策略
                logger.info("正在获取所有策略")
                result = manager.get_strategies()
                print(json.dumps(result))
            elif args.command == "start" and len(args.args) >= 1:
                # 启动策略
                strategy_id = args.args[0]
                logger.info(f"正在启动策略: {strategy_id}")
                result = manager.start_strategy(strategy_id)
                print(json.dumps(result))
            elif args.command == "stop" and len(args.args) >= 1:
                # 停止策略
                strategy_id = args.args[0]
                logger.info(f"正在停止策略: {strategy_id}")
                result = manager.stop_strategy(strategy_id)
                print(json.dumps(result))
            elif args.command == "delete" and len(args.args) >= 1:
                # 删除策略
                strategy_id = args.args[0]
                logger.info(f"正在删除策略: {strategy_id}")
                result = manager.delete_strategy(strategy_id)
                print(json.dumps(result))
            elif args.command == "exchanges":
                # 获取交易所列表
                logger.info("正在获取交易所列表")
                result = manager.get_exchanges()
                print(json.dumps(result))
            elif args.command == "pairs" and len(args.args) >= 1:
                # 获取交易对列表
                exchange = args.args[0]
                testnet = len(args.args) > 1 and args.args[1].lower() == "true"
                logger.info(f"正在获取交易对列表: {exchange}, 测试网: {testnet}")
                result = manager.get_trading_pairs(exchange, testnet)
                print(json.dumps(result))
            elif args.command == "cleanup":
                # 清理资源
                logger.info("正在清理资源")
                manager.close()
                print(json.dumps({"success": True, "message": "资源已清理"}))
            elif args.command == "validate" and len(args.args) >= 1:
                # 验证交易所连接
                exchange = args.args[0]
                api_key = args.args[1] if len(args.args) > 1 else None
                secret = args.args[2] if len(args.args) > 2 else None
                logger.info(f"正在验证交易所连接: {exchange}")
                success, msg = manager.validate_exchange_connection(
                    exchange, api_key, secret
                )
                print(json.dumps({"success": success, "message": msg}))
            elif args.command == "monitor":
                # 获取监控数据
                logger.info("正在获取监控数据")
                result = manager.get_monitor_data()
                print(json.dumps(result))
            elif args.command == "dashboard":
                # 获取首页数据
                logger.info("正在获取首页数据")
                result = manager.get_dashboard_data()
                print(json.dumps(result))
            else:
                logger.warning(f"无效的命令: {args.command} {args.args}")
                print(json.dumps({"success": False, "message": "无效的命令"}))
                print(
                    "用法: python main.py [--ipc | --pull-image | --debug] [command] [args...]"
                )
                print("命令:")
                print("  - create <exchange> <pair> [extraParamsJson]  创建策略")
                print("  - status <strategy_id>                        获取策略状态")
                print("  - list                                        获取所有策略")
                print("  - start <strategy_id>                         启动策略")
                print("  - stop <strategy_id>                          停止策略")
                print("  - delete <strategy_id>                        删除策略")
                print("  - exchanges                                   获取交易所列表")
                print("  - pairs <exchange> [testnet]                  获取交易对列表")
                print("  - validate <exchange> [api_key] [secret]      验证交易所连接")
                print("  - monitor                                     获取监控数据")
                print("  - dashboard                                   获取首页数据")
                print("  - cleanup                                     清理资源")
        else:
            logger.info("Python引擎已启动，但未指定命令")
            print("Python引擎已启动")
            print(
                "用法: python main.py [--ipc | --pull-image | --debug] [command] [args...]"
            )
            print("命令:")
            print("  - create <exchange> <pair> [extraParamsJson]  创建策略")
            print("  - status <strategy_id>                        获取策略状态")
            print("  - list                                        获取所有策略")
            print("  - start <strategy_id>                         启动策略")
            print("  - stop <strategy_id>                          停止策略")
            print("  - delete <strategy_id>                        删除策略")
            print("  - exchanges                                   获取交易所列表")
            print("  - pairs <exchange> [testnet]                  获取交易对列表")
            print("  - validate <exchange> [api_key] [secret]      验证交易所连接")
            print("  - monitor                                     获取监控数据")
            print("  - dashboard                                   获取首页数据")
            print("  - cleanup                                     清理资源")
    except KeyboardInterrupt:
        logger.info("收到Ctrl+C，正在退出...")
        # 确保资源被清理
        if "manager" in locals() and manager:
            try:
                manager.close()
            except Exception as e:
                logger.error(f"清理资源时发生错误: {e}")
    except Exception as e:
        logger.error(f"执行过程中发生错误: {e}")
        print(json.dumps({"success": False, "message": f"执行错误: {e}"}))
        sys.exit(1)
    finally:
        logger.info("Python引擎退出")
