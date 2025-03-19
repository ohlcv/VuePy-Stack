const { app, BrowserWindow, ipcMain, dialog } = require('electron');
// 设置Python编码环境变量，解决中文乱码问题
process.env.PYTHONIOENCODING = 'utf-8';
process.env.PYTHONLEGACYWINDOWSSTDIO = 'utf-8';
process.env.LANG = 'zh_CN.UTF-8';
process.env.LC_ALL = 'zh_CN.UTF-8';

const path = require('path');
const fs = require('fs');
const os = require('os');
const log = require('electron-log');
const { startPythonProcess, stopPythonProcess, registerIpcHandlers } = require('./python-bridge');

// 配置日志
log.transports.file.level = 'debug';
log.transports.console.level = 'debug';
log.info('应用启动');

// 全局变量
let mainWindow = null;
const isDevMode = process.env.NODE_ENV === 'development';

// 确保应用只有一个实例
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
    log.info('应用已经运行，退出当前实例');
    app.quit();
} else {
    app.on('second-instance', () => {
        // 当运行第二个实例时，聚焦到已经打开的窗口
        if (mainWindow) {
            if (mainWindow.isMinimized()) mainWindow.restore();
            mainWindow.focus();
        }
    });
}

// 创建必要的文件夹
const setupFolders = () => {
    try {
        // 确保数据目录存在
        const dataDir = path.join(app.getPath('userData'), 'data');
        if (!fs.existsSync(dataDir)) {
            fs.mkdirSync(dataDir, { recursive: true });
        }

        // 确保日志目录存在
        const logsDir = path.join(app.getPath('userData'), 'logs');
        if (!fs.existsSync(logsDir)) {
            fs.mkdirSync(logsDir, { recursive: true });
        }

        // 确保策略文件目录存在
        const strategyFilesDir = path.join(app.getPath('userData'), 'strategy_files');
        if (!fs.existsSync(strategyFilesDir)) {
            fs.mkdirSync(strategyFilesDir, { recursive: true });
        }

        log.info('文件夹设置完成');
    } catch (error) {
        log.error(`设置文件夹失败: ${error.message}`);
    }
};

// 创建主窗口
function createWindow() {
    log.info('创建主窗口');

    mainWindow = new BrowserWindow({
        width: 1200,
        height: 800,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            webSecurity: !isDevMode
        },
        show: false
    });

    // 加载页面
    if (isDevMode) {
        mainWindow.loadURL('http://localhost:3000');
        mainWindow.webContents.openDevTools();
    } else {
        mainWindow.loadFile(path.join(__dirname, '..', '..', 'dist', 'index.html'));
    }

    // 窗口准备好后显示
    mainWindow.once('ready-to-show', () => {
        mainWindow.show();
    });

    // 窗口关闭事件
    mainWindow.on('closed', () => {
        mainWindow = null;
        stopPythonProcess();
    });

    // 启动Python进程
    startPythonProcess();
}

// 检查Docker是否安装并运行
const checkDocker = async () => {
    try {
        const { exec } = require('child_process');

        return new Promise((resolve) => {
            exec('docker info', (error) => {
                if (error) {
                    log.error(`Docker检查失败: ${error.message}`);
                    dialog.showErrorBox(
                        'Docker未运行',
                        'Docker未安装或未运行。请确保Docker Desktop已安装并运行，然后重启应用。'
                    );
                    resolve(false);
                } else {
                    log.info('Docker已就绪');
                    resolve(true);
                }
            });
        });
    } catch (error) {
        log.error(`Docker检查异常: ${error.message}`);
        return false;
    }
};

// 检查环境
const checkEnvironment = async () => {
    log.info('检查环境');

    // 检查Docker
    const dockerReady = await checkDocker();
    if (!dockerReady) {
        return false;
    }

    // 设置必要的文件夹
    setupFolders();

    return true;
};

// 注册IPC处理程序
const setupIPC = () => {
    // 注册Python通信处理程序
    registerIpcHandlers();

    // 获取系统信息
    ipcMain.handle('get-system-info', () => {
        return {
            os: `${os.platform()} ${os.release()}`,
            arch: os.arch(),
            cpus: os.cpus().length,
            memory: Math.round(os.totalmem() / 1024 / 1024 / 1024),
            appVersion: app.getVersion(),
            electronVersion: process.versions.electron,
            nodeVersion: process.versions.node
        };
    });

    // 选择目录
    ipcMain.handle('select-directory', async () => {
        const result = await dialog.showOpenDialog({
            properties: ['openDirectory']
        });

        if (result.canceled) {
            return null;
        }

        return result.filePaths[0];
    });

    // 获取日志
    ipcMain.handle('get-logs', () => {
        const logsDir = path.join(app.getPath('userData'), 'logs');
        const logFiles = fs.readdirSync(logsDir).filter(file => file.endsWith('.log'));

        return logFiles.map(file => ({
            name: file,
            path: path.join(logsDir, file),
            size: fs.statSync(path.join(logsDir, file)).size,
            mtime: fs.statSync(path.join(logsDir, file)).mtime
        }));
    });

    // 读取日志
    ipcMain.handle('read-log', (event, filePath) => {
        try {
            return fs.readFileSync(filePath, 'utf8');
        } catch (error) {
            log.error(`读取日志失败: ${error.message}`);
            return null;
        }
    });
};

// 应用准备就绪
app.whenReady().then(async () => {
    log.info('应用准备就绪');

    // 检查环境
    const environmentReady = await checkEnvironment();
    if (!environmentReady) {
        log.error('环境检查失败，应用将退出');
        app.quit();
        return;
    }

    // 注册IPC处理程序
    setupIPC();

    // 创建窗口
    createWindow();

    // macOS应用激活时重新创建窗口
    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});

// 所有窗口关闭时退出应用
app.on('window-all-closed', () => {
    log.info('所有窗口已关闭');

    if (process.platform !== 'darwin') {
        app.quit();
    }
});

// 应用退出前清理
app.on('before-quit', () => {
    log.info('应用即将退出');
    stopPythonProcess();
});

// 未捕获的异常
process.on('uncaughtException', (error) => {
    log.error(`未捕获的异常: ${error.message}`);
    log.error(error.stack);

    dialog.showErrorBox('应用错误', `发生未捕获的异常: ${error.message}`);
}); 