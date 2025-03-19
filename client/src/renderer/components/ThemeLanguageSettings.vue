<template>
  <div class="settings-panel">
    <h2>{{ t('settings.theme') }}</h2>
    <a-switch
      v-model:checked="isDark"
      :checkedChildren="$t('settings.darkMode')"
      :unCheckedChildren="$t('settings.lightMode')"
      @change="toggleDark()"
    />

    <h2 class="mt-4">{{ t('settings.language') }}</h2>
    <a-radio-group v-model:value="currentLanguage" @change="onLanguageChange">
      <a-radio-button value="zh">中文</a-radio-button>
      <a-radio-button value="en">English</a-radio-button>
    </a-radio-group>

    <div class="device-info mt-4">
      <p>{{ isMobile ? '移动设备' : isTablet ? '平板设备' : '桌面设备' }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useThemeMode, useDeviceDetection } from '../composables/useAppComposables';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

// 使用VueUse提供的主题和设备检测功能
const { isDark, toggleDark } = useThemeMode();
const { isMobile, isTablet, isDesktop } = useDeviceDetection();

// 使用Vue I18n
const { t, locale } = useI18n();

// 当前语言
const currentLanguage = computed({
  get: () => locale.value,
  set: (value) => {
    locale.value = value;
  }
});

// 语言变更处理
const onLanguageChange = (e: any) => {
  currentLanguage.value = e.target.value;
  // 可以在此处添加语言切换后的其他逻辑
};
</script>

<style scoped>
.settings-panel {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
}
.mt-4 {
  margin-top: 20px;
}
.device-info {
  padding: 10px;
  background-color: #f0f0f0;
  border-radius: 4px;
}
</style> 