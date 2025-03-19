import { createI18n } from 'vue-i18n'

// 中文语言包
const zh = {
    common: {
        welcome: '欢迎使用加密货币网格交易系统',
        dashboard: '仪表盘',
        strategies: '策略管理',
        trades: '交易记录',
        settings: '系统设置'
    },
    dashboard: {
        overview: '系统概览',
        performance: '绩效指标',
        activeStrategies: '活跃策略',
        recentTrades: '最近交易'
    },
    strategies: {
        create: '创建策略',
        edit: '编辑策略',
        delete: '删除策略',
        name: '策略名称',
        status: '状态',
        symbol: '交易对',
        gridCount: '网格数量',
        upperPrice: '上限价格',
        lowerPrice: '下限价格'
    },
    settings: {
        language: '语言设置',
        theme: '主题设置',
        apiSettings: 'API设置',
        darkMode: '深色模式',
        lightMode: '浅色模式'
    }
}

// 英文语言包
const en = {
    common: {
        welcome: 'Welcome to Crypto Grid Trading System',
        dashboard: 'Dashboard',
        strategies: 'Strategies',
        trades: 'Trades',
        settings: 'Settings'
    },
    dashboard: {
        overview: 'System Overview',
        performance: 'Performance Metrics',
        activeStrategies: 'Active Strategies',
        recentTrades: 'Recent Trades'
    },
    strategies: {
        create: 'Create Strategy',
        edit: 'Edit Strategy',
        delete: 'Delete Strategy',
        name: 'Strategy Name',
        status: 'Status',
        symbol: 'Trading Pair',
        gridCount: 'Grid Count',
        upperPrice: 'Upper Price',
        lowerPrice: 'Lower Price'
    },
    settings: {
        language: 'Language Settings',
        theme: 'Theme Settings',
        apiSettings: 'API Settings',
        darkMode: 'Dark Mode',
        lightMode: 'Light Mode'
    }
}

const i18n = createI18n({
    legacy: false, // 使用Composition API模式
    locale: 'zh',  // 默认语言
    fallbackLocale: 'en', // 回退语言
    messages: {
        zh,
        en
    }
})

export default i18n 