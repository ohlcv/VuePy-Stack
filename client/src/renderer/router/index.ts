import { createRouter, createWebHashHistory } from 'vue-router';

// 定义路由
const routes = [
    {
        path: '/',
        name: 'Home',
        component: () => import('../views/Home.vue')
    },
    {
        path: '/strategies',
        name: 'Strategies',
        component: () => import('../views/Strategies.vue')
    },
    {
        path: '/monitor',
        name: 'Monitor',
        component: () => import('../views/Monitor.vue')
    },
    {
        path: '/settings',
        name: 'Settings',
        component: () => import('../views/Settings.vue')
    }
];

// 创建路由实例
const router = createRouter({
    history: createWebHashHistory(),
    routes
});

export default router; 