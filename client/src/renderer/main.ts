import { createApp } from 'vue';
import App from './App.vue';
import Antd from 'ant-design-vue';
import 'ant-design-vue/dist/reset.css';
import { createPinia } from 'pinia';
import router from './router';

// 创建Vue应用
const app = createApp(App);

// 使用插件
app.use(Antd);
app.use(createPinia());
app.use(router);

// 挂载应用
app.mount('#app'); 