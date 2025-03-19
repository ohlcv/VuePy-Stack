#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import yaml
import docker
import sqlite3
from pathlib import Path
from loguru import logger


class HummingbotManager:
    """Hummingbot容器管理器"""

    def __init__(self, config_dir="strategy_files", db_path="data/crypto_grid.db"):
        """初始化Hummingbot管理器

        Args:
            config_dir: 配置文件目录
            db_path: 数据库路径
        """
        self.config_dir = Path(config_dir)
        self.config_dir.mkdir(parents=True, exist_ok=True)

        # 初始化Docker客户端
        try:
            self.docker_client = docker.from_env()
            self.docker_client.ping()
            logger.info("Docker连接成功")
        except Exception as e:
            logger.error(f"Docker连接失败: {e}")
            raise RuntimeError(f"Docker连接失败: {e}")

        # 初始化数据库
        db_dir = Path(db_path).parent
        db_dir.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(db_path)
        self._init_db()

    def _init_db(self):
        """初始化数据库表"""
        cursor = self.conn.cursor()
        cursor.execute(
            """
        CREATE TABLE IF NOT EXISTS containers (
            id TEXT PRIMARY KEY,
            name TEXT,
            strategy_id TEXT,
            exchange TEXT,
            trading_pair TEXT,
            status TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
        )
        self.conn.commit()

    def create_config(self, strategy_id, exchange, trading_pair, **params):
        """创建Hummingbot配置文件

        Args:
            strategy_id: 策略ID
            exchange: 交易所
            trading_pair: 交易对
            **params: 其他参数

        Returns:
            Path: 配置文件路径
        """
        strategy_dir = self.config_dir / strategy_id
        strategy_dir.mkdir(parents=True, exist_ok=True)

        # 基本配置
        config = {
            "template": "pure_market_making",
            "exchange": exchange,
            "market": trading_pair,
            "bid_spread": params.get("bid_spread", 0.01),
            "ask_spread": params.get("ask_spread", 0.01),
            "order_amount": params.get("order_amount", 0.01),
            "order_refresh_time": params.get("order_refresh_time", 10),
            "max_order_age": params.get("max_order_age", 1800),
            "order_refresh_tolerance_pct": params.get(
                "order_refresh_tolerance_pct", 0.2
            ),
            "filled_order_delay": params.get("filled_order_delay", 60),
            "inventory_skew_enabled": params.get("inventory_skew_enabled", False),
            "inventory_target_base_pct": params.get("inventory_target_base_pct", 50),
            "inventory_range_multiplier": params.get("inventory_range_multiplier", 1),
            "enable_external_price_source": params.get(
                "enable_external_price_source", False
            ),
            "external_price_source_type": params.get(
                "external_price_source_type", "binance"
            ),
            "external_price_source_exchange": params.get(
                "external_price_source_exchange", "binance"
            ),
            "external_price_source_market": params.get(
                "external_price_source_market", trading_pair
            ),
            "external_price_source_feed": params.get(
                "external_price_source_feed", "mid_price"
            ),
        }

        # 写入配置文件
        config_path = strategy_dir / "conf_pure_mm.yml"
        with open(config_path, "w") as f:
            yaml.dump(config, f, default_flow_style=False)

        logger.info(f"配置文件已创建: {config_path}")
        return config_path

    def validate_config(self, config_path):
        """验证配置文件

        Args:
            config_path: 配置文件路径

        Returns:
            (bool, str): (是否有效, 消息)
        """
        try:
            with open(config_path, "r") as f:
                config = yaml.safe_load(f)

            # 检查必要字段
            required_fields = [
                "exchange",
                "market",
                "bid_spread",
                "ask_spread",
                "order_amount",
            ]
            for field in required_fields:
                if field not in config:
                    return False, f"配置缺少必要字段: {field}"

            # 验证数值字段
            numeric_fields = [
                "bid_spread",
                "ask_spread",
                "order_amount",
                "order_refresh_time",
                "max_order_age",
            ]
            for field in numeric_fields:
                if field in config and not isinstance(config[field], (int, float)):
                    return False, f"字段{field}必须是数值类型"

            return True, "配置验证通过"
        except Exception as e:
            return False, f"配置验证失败: {e}"

    def create_container(self, strategy_id, exchange, trading_pair, **params):
        """创建并启动Hummingbot容器

        Args:
            strategy_id: 策略ID
            exchange: 交易所
            trading_pair: 交易对
            **params: 其他参数

        Returns:
            (bool, str): (是否成功, 消息)
        """
        try:
            # 创建配置
            config_path = self.create_config(
                strategy_id, exchange, trading_pair, **params
            )

            # 验证配置
            valid, msg = self.validate_config(config_path)
            if not valid:
                return False, msg

            # 检查是否已存在同名容器
            container_name = f"hummingbot_{strategy_id}"
            existing = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )
            if existing:
                logger.warning(f"容器{container_name}已存在，将被移除")
                for container in existing:
                    container.remove(force=True)

            # 创建容器
            strategy_dir = self.config_dir / strategy_id
            volumes = {str(strategy_dir.absolute()): {"bind": "/conf", "mode": "rw"}}

            # 使用Docker SDK创建容器
            container = self.docker_client.containers.run(
                "hummingbot/hummingbot:latest",
                name=container_name,
                detach=True,
                volumes=volumes,
                environment={
                    "CONFIG_FILE_NAME": "conf_pure_mm.yml",
                    "CONFIG_PASSWORD": "",
                },
            )

            # 记录到数据库
            cursor = self.conn.cursor()
            cursor.execute(
                "INSERT OR REPLACE INTO containers VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
                (
                    container.id,
                    container_name,
                    strategy_id,
                    exchange,
                    trading_pair,
                    "running",
                ),
            )
            self.conn.commit()

            logger.info(f"容器{container_name}创建成功，ID: {container.id[:12]}")
            return True, f"容器{container_name}创建成功"
        except Exception as e:
            logger.error(f"创建容器失败: {e}")
            return False, f"创建容器失败: {e}"

    def get_container_status(self, strategy_id):
        """获取容器状态

        Args:
            strategy_id: 策略ID

        Returns:
            dict: 状态信息
        """
        container_name = f"hummingbot_{strategy_id}"
        try:
            containers = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )
            if not containers:
                return {"status": "not_found", "message": f"容器{container_name}不存在"}

            container = containers[0]
            logs = container.logs(tail=20).decode("utf-8")

            # 获取容器详细信息
            info = {
                "id": container.id[:12],
                "name": container.name,
                "status": container.status,
                "created": container.attrs["Created"],
                "logs": logs,
            }

            # 从数据库获取策略信息
            cursor = self.conn.cursor()
            cursor.execute("SELECT * FROM containers WHERE id=?", (container.id,))
            row = cursor.fetchone()
            if row:
                info["strategy_id"] = row[2]
                info["exchange"] = row[3]
                info["trading_pair"] = row[4]

            return info
        except Exception as e:
            logger.error(f"获取容器状态失败: {e}")
            return {"status": "error", "message": str(e)}

    def stop_container(self, strategy_id):
        """停止容器

        Args:
            strategy_id: 策略ID

        Returns:
            (bool, str): (是否成功, 消息)
        """
        container_name = f"hummingbot_{strategy_id}"
        try:
            containers = self.docker_client.containers.list(
                filters={"name": container_name}
            )
            if not containers:
                return False, f"容器{container_name}不存在或已停止"

            container = containers[0]
            container.stop()

            # 更新数据库
            cursor = self.conn.cursor()
            cursor.execute(
                "UPDATE containers SET status=? WHERE id=?", ("stopped", container.id)
            )
            self.conn.commit()

            logger.info(f"容器{container_name}已停止")
            return True, f"容器{container_name}已停止"
        except Exception as e:
            logger.error(f"停止容器失败: {e}")
            return False, f"停止容器失败: {e}"

    def remove_container(self, strategy_id):
        """移除容器

        Args:
            strategy_id: 策略ID

        Returns:
            (bool, str): (是否成功, 消息)
        """
        container_name = f"hummingbot_{strategy_id}"
        try:
            containers = self.docker_client.containers.list(
                all=True, filters={"name": container_name}
            )
            if not containers:
                return False, f"容器{container_name}不存在"

            container = containers[0]
            container.remove(force=True)

            # 更新数据库
            cursor = self.conn.cursor()
            cursor.execute("DELETE FROM containers WHERE id=?", (container.id,))
            self.conn.commit()

            logger.info(f"容器{container_name}已移除")
            return True, f"容器{container_name}已移除"
        except Exception as e:
            logger.error(f"移除容器失败: {e}")
            return False, f"移除容器失败: {e}"

    def list_containers(self):
        """列出所有容器

        Returns:
            list: 容器列表
        """
        try:
            containers = self.docker_client.containers.list(
                all=True, filters={"name": "hummingbot_"}
            )
            result = []

            for container in containers:
                info = {
                    "id": container.id[:12],
                    "name": container.name,
                    "status": container.status,
                    "created": container.attrs["Created"],
                }

                # 从数据库获取策略信息
                cursor = self.conn.cursor()
                cursor.execute("SELECT * FROM containers WHERE id=?", (container.id,))
                row = cursor.fetchone()
                if row:
                    info["strategy_id"] = row[2]
                    info["exchange"] = row[3]
                    info["trading_pair"] = row[4]

                result.append(info)

            return result
        except Exception as e:
            logger.error(f"列出容器失败: {e}")
            return []

    def close(self):
        """关闭资源"""
        if hasattr(self, "conn") and self.conn:
            self.conn.close()
            logger.info("数据库连接已关闭")
