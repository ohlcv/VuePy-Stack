<template>
  <a-layout class="app-layout">
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
        theme="dark"
        mode="inline"
      >
        <a-menu-item key="home">
          <router-link to="/">
            <home-outlined />
            <span>首页</span>
          </router-link>
        </a-menu-item>
        <a-menu-item key="strategies">
          <router-link to="/strategies">
            <fund-outlined />
            <span>策略管理</span>
          </router-link>
        </a-menu-item>
        <a-menu-item key="monitor">
          <router-link to="/monitor">
            <bar-chart-outlined />
            <span>交易监控</span>
          </router-link>
        </a-menu-item>
        <a-menu-item key="settings">
          <router-link to="/settings">
            <setting-outlined />
            <span>系统设置</span>
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
        CryptoGrid &copy; {{ new Date().getFullYear() }} - 加密货币网格交易系统
      </a-layout-footer>
    </a-layout>
  </a-layout>
</template>

<script lang="ts">
import { defineComponent, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import {
  HomeOutlined,
  FundOutlined,
  BarChartOutlined,
  SettingOutlined,
  MenuUnfoldOutlined,
  MenuFoldOutlined,
  BellOutlined,
  UserOutlined,
  LogoutOutlined
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
    LogoutOutlined
  },
  setup() {
    const collapsed = ref(false);
    const selectedKeys = ref(['home']);
    const route = useRoute();
    
    // 根据路由更新菜单选中项
    watch(
      () => route.path,
      (path) => {
        const key = path === '/' ? 'home' : path.substring(1);
        selectedKeys.value = [key];
      },
      { immediate: true }
    );
    
    return {
      collapsed,
      selectedKeys
    };
  }
});
</script>

<style>
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
  background: #fff;
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
  color: #1890ff;
}

.right-menu {
  display: flex;
  align-items: center;
  gap: 16px;
}

.content {
  margin: 24px 16px;
  padding: 24px;
  background: #fff;
  min-height: 280px;
}

.footer {
  text-align: center;
}
</style> 