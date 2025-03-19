const path = require('path');
const fs = require('fs');
const log = require('electron-log');
const { ipcMain } = require('electron');
const { PythonShell } = require('python-shell');

// Python进程
let pythonShell = null;
let isProcessReady = false;
let requestQueue = [];
let isProcessing = false;

// 配置日志
log.transports.file.level = 'debug';
log.transports.console.level = 'debug';

/**
 * 启动Python进程
 */
const startPythonProcess = () => {
    log.info('启动Python进程');

    try {
        // 确定Python路径
        const pythonPath = process.env.NODE_ENV === 'development'
            ? (process.platform === 'win32' ? 'python' : 'python3') // 开发环境使用系统Python
            : getPackagedPythonPath(); // 打包环境使用捆绑的Python

        // 确定Python脚本路径
        const scriptPath = getScriptPath();

        log.info(`使用Python解释器: ${pythonPath}`);
        log.info(`使用Python脚本: ${scriptPath}`);

        // 确保脚本存在
        if (!fs.existsSync(scriptPath)) {
            throw new Error(`Python脚本不存在: ${scriptPath}`);
        }

        // 设置PythonShell选项
        const pythonOptions = {
            mode: 'json',
            pythonPath: pythonPath,
            pythonOptions: ['-u'], // 无缓冲模式，解决中文输出问题
            scriptPath: path.dirname(scriptPath),
            args: process.env.NODE_ENV === 'production' ? ['--production'] : [],
            env: {
                ...process.env,
                PYTHONIOENCODING: 'utf-8',
                PYTHONLEGACYWINDOWSSTDIO: 'utf-8',
                LANG: 'zh_CN.UTF-8',
                LC_ALL: 'zh_CN.UTF-8'
            }
        };

        // 启动Python进程
        pythonShell = new PythonShell(path.basename(scriptPath), pythonOptions);

        // 监听消息
        pythonShell.on('message', (message) => {
            log.debug(`Python消息: ${JSON.stringify(message)}`);

            // 检测进程是否就绪
            if (typeof message === 'string' && message.includes('IPC_READY')) {
                log.info('Python进程已就绪');
                isProcessReady = true;
                processQueue();
            } else if (message && message.requestId && message.result !== undefined) {
                // 找到对应的等待回调
                const pendingRequest = requestQueue.find(req => req.requestId === message.requestId);
                if (pendingRequest) {
                    pendingRequest.resolve(message.result);

                    // 从队列中移除已处理的请求
                    requestQueue = requestQueue.filter(req => req.requestId !== message.requestId);

                    // 继续处理队列
                    isProcessing = false;
                    processQueue();
                }
            }
        });

        // 监听错误
        pythonShell.on('stderr', (stderr) => {
            log.error(`Python错误: ${stderr}`);
        });

        // 监听进程退出
        pythonShell.on('error', (err) => {
            log.error(`Python进程错误: ${err.message}`);
            handleProcessTermination(1);
        });

        pythonShell.on('close', (code) => {
            log.info(`Python进程已退出，退出码: ${code || 0}`);
            handleProcessTermination(code);
        });

        return true;
    } catch (error) {
        log.error(`启动Python进程失败: ${error.message}`);
        return false;
    }
};

/**
 * 处理进程终止
 */
const handleProcessTermination = (code) => {
    isProcessReady = false;
    pythonShell = null;

    // 如果是意外退出，通知所有等待中的请求
    if (code !== 0) {
        requestQueue.forEach(req => {
            req.reject(new Error(`Python进程意外退出，退出码: ${code}`));
        });
        requestQueue = [];
    }
};

/**
 * 停止Python进程
 */
const stopPythonProcess = () => {
    if (!pythonShell) return;

    log.info('停止Python进程');
    pythonShell.end(() => {
        log.info('Python进程已关闭');
    });
    pythonShell = null;
    isProcessReady = false;
};

/**
 * 获取Python脚本路径
 */
const getScriptPath = () => {
    let scriptPath;

    if (process.env.NODE_ENV === 'development') {
        // 开发环境
        // 使用当前工作目录
        scriptPath = path.join(process.cwd(), 'src', 'python', 'main.py');
        log.info(`开发环境Python脚本路径: ${scriptPath}`);
    } else {
        // 打包环境
        if (process.platform === 'win32') {
            scriptPath = path.join(process.resourcesPath, 'python', 'main.py');
        } else {
            scriptPath = path.join(process.resourcesPath, 'python', 'main.py');
        }
    }

    return scriptPath;
};

/**
 * 获取打包后的Python解释器路径
 */
const getPackagedPythonPath = () => {
    if (process.platform === 'win32') {
        return path.join(process.resourcesPath, 'python', 'python.exe');
    } else if (process.platform === 'darwin') {
        return path.join(process.resourcesPath, 'python', 'bin', 'python3');
    } else {
        return path.join(process.resourcesPath, 'python', 'bin', 'python3');
    }
};

/**
 * 调用Python方法
 */
const callPythonMethod = (method, ...args) => {
    return new Promise((resolve, reject) => {
        const requestId = Date.now().toString();

        // 将请求添加到队列
        requestQueue.push({
            requestId,
            method,
            args,
            resolve,
            reject
        });

        // 尝试处理队列
        processQueue();
    });
};

/**
 * 处理请求队列
 */
const processQueue = () => {
    // 如果进程未就绪或已有处理中的请求，直接返回
    if (!isProcessReady || isProcessing || requestQueue.length === 0) return;

    // 获取队列中第一个请求
    const request = requestQueue[0];
    isProcessing = true;

    try {
        // 构建JSON请求
        const jsonRequest = {
            requestId: request.requestId,
            method: request.method,
            args: request.args
        };

        // 发送到Python进程
        pythonShell.send(jsonRequest);

        // 设置超时
        setTimeout(() => {
            if (requestQueue.includes(request)) {
                request.reject(new Error(`请求超时: ${request.method}`));
                requestQueue = requestQueue.filter(req => req.requestId !== request.requestId);
                isProcessing = false;
                processQueue();
            }
        }, 30000); // 30秒超时
    } catch (error) {
        log.error(`发送请求到Python进程失败: ${error.message}`);
        request.reject(error);
        requestQueue = requestQueue.filter(req => req.requestId !== request.requestId);
        isProcessing = false;
        processQueue();
    }
};

// 注册IPC处理程序
const registerIpcHandlers = () => {
    // 从渲染进程接收Python请求
    ipcMain.on('python-request', async (event, request) => {
        const { requestId, method, args } = request;

        try {
            // 调用Python方法
            const result = await callPythonMethod(method, ...args);

            // 返回结果给渲染进程
            event.sender.send(`python-response-${requestId}`, {
                data: result
            });
        } catch (error) {
            // 返回错误给渲染进程
            event.sender.send(`python-response-${requestId}`, {
                error: error.message
            });
        }
    });
};

module.exports = {
    startPythonProcess,
    stopPythonProcess,
    callPythonMethod,
    registerIpcHandlers
}; 