<template>
  <a-layout class="app-layout" :class="{ 'dark-theme': isDark }">
    <!-- 侧边栏 -->
    <a-layout-sider
      v-model:collapsed="collapsed"
      collapsible
      :trigger="null"
      class="sidebar"
    >
      <div class="logo">
        <img src="../assets/logo.png" alt="CryptoGrid" />
        <h1 v-if="!collapsed">CryptoGrid</h1>
      </div>
      
      <a-menu
        v-model:selectedKeys="selectedKeys"
        :theme="isDark ? 'dark' : 'light'"
        mode="inline"
      >
        <a-menu-item key="home">
          <router-link to="/">
            <home-outlined />
            <span>{{ $t('common.dashboard') }}</span>
          </router-link>
        </a-menu-item>
        <a-menu-item key="strategies">
          <router-link to="/strategies">
            <fund-outlined />
            <span>{{ $t('common.strategies') }}</span>
          </router-link>
        </a-menu-item>
        <a-menu-item key="monitor">
          <router-link to="/monitor">
            <bar-chart-outlined />
            <span>{{ $t('common.trades') }}</span>
          </router-link>
        </a-menu-item>
        <a-menu-item key="settings">
          <router-link to="/settings">
            <setting-outlined />
            <span>{{ $t('common.settings') }}</span>
          </router-link>
        </a-menu-item>
      </a-menu>
    </a-layout-sider>
    
    <!-- 主内容区 -->
    <a-layout>
      <!-- 顶部导航 -->
      <a-layout-header class="header">
        <menu-unfold-outlined
          v-if="collapsed"
          class="trigger"
          @click="() => (collapsed = !collapsed)"
        />
        <menu-fold-outlined
          v-else
          class="trigger"
          @click="() => (collapsed = !collapsed)"
        />
        
        <div class="right-menu">
          <!-- 主题切换 -->
          <a-tooltip>
            <template #title>{{ isDark ? $t('settings.lightMode') : $t('settings.darkMode') }}</template>
            <a-button shape="circle" @click="toggleDark()">
              <template #icon>
                <component :is="isDark ? 'BulbOutlined' : 'BulbFilled'" />
              </template>
            </a-button>
          </a-tooltip>
          
          <!-- 语言切换 -->
          <a-dropdown>
            <a-button type="text">
              {{ locale === 'zh' ? '中文' : 'English' }}
              <down-outlined />
            </a-button>
            <template #overlay>
              <a-menu @click="changeLocale">
                <a-menu-item key="zh">中文</a-menu-item>
                <a-menu-item key="en">English</a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
          
          <a-badge dot>
            <bell-outlined style="font-size: 18px" />
          </a-badge>
          <a-dropdown>
            <a-avatar style="background-color: #1890ff">用户</a-avatar>
            <template #overlay>
              <a-menu>
                <a-menu-item key="0">
                  <user-outlined />
                  账户信息
                </a-menu-item>
                <a-menu-divider />
                <a-menu-item key="1">
                  <logout-outlined />
                  退出登录
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </a-layout-header>
      
      <!-- 内容区 -->
      <a-layout-content class="content">
        <router-view />
      </a-layout-content>
      
      <!-- 底部 -->
      <a-layout-footer class="footer">
        CryptoGrid &copy; {{ new Date().getFullYear() }} - {{ $t('common.welcome') }}
      </a-layout-footer>
    </a-layout>
  </a-layout>
</template>

<script lang="ts">
import { defineComponent, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useThemeMode } from './composables/useAppComposables';
import {
  HomeOutlined,
  FundOutlined,
  BarChartOutlined,
  SettingOutlined,
  MenuUnfoldOutlined,
  MenuFoldOutlined,
  BellOutlined,
  UserOutlined,
  LogoutOutlined,
  BulbOutlined,
  BulbFilled,
  DownOutlined
} from '@ant-design/icons-vue';

export default defineComponent({
  name: 'App',
  components: {
    HomeOutlined,
    FundOutlined,
    BarChartOutlined,
    SettingOutlined,
    MenuUnfoldOutlined,
    MenuFoldOutlined,
    BellOutlined,
    UserOutlined,
    LogoutOutlined,
    BulbOutlined,
    BulbFilled,
    DownOutlined
  },
  setup() {
    const collapsed = ref(false);
    const selectedKeys = ref(['home']);
    const route = useRoute();
    
    // 使用VueUse的主题模式
    const { isDark, toggleDark } = useThemeMode();
    
    // 使用Vue I18n
    const { locale } = useI18n();
    
    // 根据路由更新菜单选中项
    watch(
      () => route.path,
      (path) => {
        const key = path === '/' ? 'home' : path.substring(1);
        selectedKeys.value = [key];
      },
      { immediate: true }
    );
    
    // 切换语言
    const changeLocale = (e: any) => {
      locale.value = e.key;
    };
    
    return {
      collapsed,
      selectedKeys,
      isDark,
      toggleDark,
      locale,
      changeLocale
    };
  }
});
</script>

<style>
:root {
  --primary-color: #1890ff;
  --bg-color: #f0f2f5;
  --text-color: rgba(0, 0, 0, 0.85);
  --component-bg: #fff;
  --border-color: #d9d9d9;
}

.dark-theme {
  --primary-color: #177ddc;
  --bg-color: #141414;
  --text-color: rgba(255, 255, 255, 0.85);
  --component-bg: #1f1f1f;
  --border-color: #434343;
}

body {
  color: var(--text-color);
  background-color: var(--bg-color);
}

.app-layout {
  min-height: 100vh;
}

.sidebar .logo {
  height: 32px;
  margin: 16px;
  display: flex;
  align-items: center;
}

.sidebar .logo img {
  height: 32px;
  margin-right: 8px;
}

.sidebar .logo h1 {
  color: white;
  font-size: 18px;
  margin: 0;
}

.header {
  background: var(--component-bg);
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.trigger {
  font-size: 18px;
  cursor: pointer;
  transition: color 0.3s;
}

.trigger:hover {
  color: var(--primary-color);
}

.right-menu {
  display: flex;
  align-items: center;
  gap: 16px;
}

.content {
  margin: 24px 16px;
  padding: 24px;
  background: var(--component-bg);
  min-height: 280px;
}

.footer {
  text-align: center;
  background: var(--component-bg);
  color: var(--text-color);
}

.dark-theme .ant-layout {
  background: var(--bg-color);
}

.dark-theme .ant-layout-sider {
  background: #001529;
}
</style> 