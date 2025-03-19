import { defineStore } from 'pinia';
import { ref, reactive } from 'vue';

// 使用python-shell进行Python通信
const { spawn } = require('child_process');
const path = require('path');
const electron = require('electron');
const ipcRenderer = electron.ipcRenderer;

// 通过IPC与主进程通信
const callPythonMethod = async (method: string, ...args: any[]) => {
    return new Promise((resolve, reject) => {
        const requestId = Date.now().toString();

        // 监听一次性响应
        ipcRenderer.once(`python-response-${requestId}`, (_event, response) => {
            if (response.error) {
                reject(new Error(response.error));
            } else {
                resolve(response.data);
            }
        });

        // 发送请求到主进程
        ipcRenderer.send('python-request', {
            requestId,
            method,
            args
        });
    });
};

export const useStrategyStore = defineStore('strategy', () => {
    // 状态
    const strategies = ref([]);
    const trades = ref([]);
    const loading = reactive({
        strategies: false,
        trades: false,
        monitor: false
    });
    const error = ref(null);

    // 获取策略列表
    const getStrategies = async () => {
        loading.strategies = true;
        try {
            const result = await callPythonMethod('get_strategies');
            strategies.value = result || [];
            return strategies.value;
        } catch (err) {
            error.value = err.message;
            console.error('获取策略列表失败:', err);
            return [];
        } finally {
            loading.strategies = false;
        }
    };

    // 创建策略
    const createStrategy = async (strategyData) => {
        try {
            const result = await callPythonMethod('create_strategy', strategyData);
            await getStrategies();
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('创建策略失败:', err);
            throw err;
        }
    };

    // 更新策略
    const updateStrategy = async (strategyData) => {
        try {
            const result = await callPythonMethod('update_strategy', strategyData);
            await getStrategies();
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('更新策略失败:', err);
            throw err;
        }
    };

    // 启动策略
    const startStrategy = async (strategyId) => {
        try {
            const result = await callPythonMethod('start_strategy', strategyId);
            await getStrategies();
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('启动策略失败:', err);
            throw err;
        }
    };

    // 停止策略
    const stopStrategy = async (strategyId) => {
        try {
            const result = await callPythonMethod('stop_strategy', strategyId);
            await getStrategies();
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('停止策略失败:', err);
            throw err;
        }
    };

    // 删除策略
    const deleteStrategy = async (strategyId) => {
        try {
            const result = await callPythonMethod('delete_strategy', strategyId);
            await getStrategies();
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('删除策略失败:', err);
            throw err;
        }
    };

    // 获取策略订单
    const getStrategyOrders = async (strategyId) => {
        try {
            const result = await callPythonMethod('get_strategy_orders', strategyId);
            return result || [];
        } catch (err) {
            error.value = err.message;
            console.error('获取策略订单失败:', err);
            return [];
        }
    };

    // 获取交易所列表
    const getExchanges = async () => {
        try {
            const result = await callPythonMethod('get_exchanges');
            return result || [];
        } catch (err) {
            error.value = err.message;
            console.error('获取交易所列表失败:', err);
            return [];
        }
    };

    // 添加交易所
    const addExchange = async (exchangeData) => {
        try {
            const result = await callPythonMethod('add_exchange', exchangeData);
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('添加交易所失败:', err);
            throw err;
        }
    };

    // 更新交易所
    const updateExchange = async (exchangeData) => {
        try {
            const result = await callPythonMethod('update_exchange', exchangeData);
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('更新交易所失败:', err);
            throw err;
        }
    };

    // 删除交易所
    const deleteExchange = async (exchangeId) => {
        try {
            const result = await callPythonMethod('delete_exchange', exchangeId);
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('删除交易所失败:', err);
            throw err;
        }
    };

    // 测试交易所连接
    const testExchange = async (exchangeId) => {
        try {
            const result = await callPythonMethod('test_exchange', exchangeId);
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('测试交易所失败:', err);
            return { success: false, message: err.message };
        }
    };

    // 获取交易对
    const getTradingPairs = async (exchange, testnet = false) => {
        try {
            const result = await callPythonMethod('get_trading_pairs', exchange, testnet);
            return result || [];
        } catch (err) {
            error.value = err.message;
            console.error('获取交易对失败:', err);
            return [];
        }
    };

    // 获取系统设置
    const getSystemSettings = async () => {
        try {
            const result = await callPythonMethod('get_system_settings');
            return result || {};
        } catch (err) {
            error.value = err.message;
            console.error('获取系统设置失败:', err);
            return {};
        }
    };

    // 保存系统设置
    const saveSystemSettings = async (settings) => {
        try {
            const result = await callPythonMethod('save_system_settings', settings);
            return result;
        } catch (err) {
            error.value = err.message;
            console.error('保存系统设置失败:', err);
            throw err;
        }
    };

    // 获取系统信息
    const getSystemInfo = async () => {
        try {
            const result = await callPythonMethod('get_system_info');
            return result || {};
        } catch (err) {
            error.value = err.message;
            console.error('获取系统信息失败:', err);
            return {};
        }
    };

    // 检查更新
    const checkForUpdates = async () => {
        try {
            const result = await callPythonMethod('check_for_updates');
            return result || { hasUpdate: false };
        } catch (err) {
            error.value = err.message;
            console.error('检查更新失败:', err);
            return { hasUpdate: false };
        }
    };

    // 打开日志文件夹
    const openLogsFolder = async () => {
        try {
            await callPythonMethod('open_logs_folder');
            return true;
        } catch (err) {
            error.value = err.message;
            console.error('打开日志文件夹失败:', err);
            return false;
        }
    };

    // 获取监控数据
    const getMonitorData = async () => {
        loading.monitor = true;
        try {
            const result = await callPythonMethod('get_monitor_data');
            return result || { stats: {}, trades: [] };
        } catch (err) {
            error.value = err.message;
            console.error('获取监控数据失败:', err);
            return { stats: {}, trades: [] };
        } finally {
            loading.monitor = false;
        }
    };

    // 获取首页数据
    const getDashboardData = async () => {
        try {
            const result = await callPythonMethod('get_dashboard_data');
            return result || { stats: {}, recentTrades: [] };
        } catch (err) {
            error.value = err.message;
            console.error('获取首页数据失败:', err);
            return { stats: {}, recentTrades: [] };
        }
    };

    return {
        strategies,
        trades,
        loading,
        error,
        getStrategies,
        createStrategy,
        updateStrategy,
        startStrategy,
        stopStrategy,
        deleteStrategy,
        getStrategyOrders,
        getExchanges,
        addExchange,
        updateExchange,
        deleteExchange,
        testExchange,
        getTradingPairs,
        getSystemSettings,
        saveSystemSettings,
        getSystemInfo,
        checkForUpdates,
        openLogsFolder,
        getMonitorData,
        getDashboardData
    };
}); 