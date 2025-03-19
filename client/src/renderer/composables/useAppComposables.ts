import { useDark, useToggle, useLocalStorage, usePreferredDark, useMediaQuery } from '@vueuse/core'

/**
 * 深色/浅色模式管理
 * 使用本地存储记住用户的主题偏好
 */
export function useThemeMode() {
    // 检测系统偏好
    const prefersDark = usePreferredDark()
    // 创建深色模式状态，并保存到本地存储
    const isDark = useDark({
        storageKey: 'theme-mode',
        initialValue: prefersDark.value ? 'dark' : 'light',
    })
    const toggleDark = useToggle(isDark)

    return {
        isDark,
        toggleDark
    }
}

/**
 * 语言管理
 * 将用户的语言偏好保存到本地存储
 */
export function useLanguage() {
    const language = useLocalStorage('app-language', 'zh')

    const setLanguage = (lang: string) => {
        language.value = lang
    }

    return {
        language,
        setLanguage
    }
}

/**
 * 响应式设备检测
 * 用于自适应布局
 */
export function useDeviceDetection() {
    const isMobile = useMediaQuery('(max-width: 768px)')
    const isTablet = useMediaQuery('(min-width: 769px) and (max-width: 1024px)')
    const isDesktop = useMediaQuery('(min-width: 1025px)')

    return {
        isMobile,
        isTablet,
        isDesktop
    }
}

/**
 * 本地存储的应用配置
 */
export function useAppSettings() {
    const apiKeys = useLocalStorage('api-keys', {
        binance: '',
        coinbase: '',
        okx: ''
    })

    const strategyDefaults = useLocalStorage('strategy-defaults', {
        gridCount: 10,
        profitTarget: 0.05, // 5%
        stopLoss: 0.1 // 10%
    })

    return {
        apiKeys,
        strategyDefaults
    }
} 