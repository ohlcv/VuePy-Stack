const { defineConfig } = require('vite');
const vue = require('@vitejs/plugin-vue');
const path = require('path');

// https://vitejs.dev/config/
module.exports = defineConfig({
    plugins: [vue()],
    base: './', // 使用相对路径，这对于 Electron 应用很重要
    build: {
        outDir: 'dist', // 输出目录
        emptyOutDir: true, // 构建前清空输出目录
        rollupOptions: {
            input: {
                main: path.resolve(__dirname, 'index.html')
            }
        }
    },
    resolve: {
        alias: {
            '@': path.resolve(__dirname, 'src/renderer'),
            '/assets': path.resolve(__dirname, 'public/assets'), // 添加 assets 别名
        }
    },
    server: {
        port: 3000
    },
    publicDir: 'public', // 指定公共资源目录
}); 