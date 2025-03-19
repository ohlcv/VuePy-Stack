#!/usr/bin/env node

/**
 * 环境检查脚本
 * 用于验证Python环境和Docker
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

// 颜色输出
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
};

// 日志函数
function log(message, color = colors.reset) {
    console.log(`${color}${message}${colors.reset}`);
}

// 检查是否在Docker容器内运行
function isRunningInContainer() {
    try {
        return fs.existsSync('/.dockerenv');
    } catch (error) {
        return false;
    }
}

// 检查命令是否存在
function commandExists(command) {
    try {
        execSync(`${command} --version`, { stdio: 'ignore' });
        return true;
    } catch (error) {
        return false;
    }
}

// 检查Python版本
function checkPython() {
    log('检查Python环境...', colors.blue);

    try {
        // 检查Python命令
        const pythonCommand = os.platform() === 'win32' ? 'python' : 'python3';
        const versionOutput = execSync(`${pythonCommand} --version`).toString().trim();
        log(`✓ ${versionOutput}`, colors.green);

        // 提取版本号
        const versionMatch = versionOutput.match(/(\d+)\.(\d+)\.(\d+)/);
        if (versionMatch) {
            const [, major, minor] = versionMatch;
            if (parseInt(major) < 3 || (parseInt(major) === 3 && parseInt(minor) < 10)) {
                log(`⚠ 警告: 推荐使用Python 3.10或更高版本`, colors.yellow);
            }
        }

        // 检查pip
        const pipOutput = execSync(`${pythonCommand} -m pip --version`).toString().trim();
        log(`✓ ${pipOutput}`, colors.green);

        return true;
    } catch (error) {
        log(`✗ Python检查失败: ${error.message}`, colors.red);
        log('请安装Python 3.10或更高版本', colors.yellow);
        return false;
    }
}

// 检查Docker
function checkDocker() {
    log('检查Docker环境...', colors.blue);

    // 如果在容器内运行，跳过Docker检查
    if (isRunningInContainer()) {
        log('✓ 在Docker容器内运行，跳过Docker检查', colors.green);
        return true;
    }

    try {
        if (!commandExists('docker')) {
            log('✗ Docker未安装', colors.red);
            log('请安装Docker Desktop: https://www.docker.com/products/docker-desktop', colors.yellow);
            return false;
        }

        const dockerVersion = execSync('docker --version').toString().trim();
        log(`✓ ${dockerVersion}`, colors.green);

        // 检查Docker是否运行
        execSync('docker info', { stdio: 'ignore' });
        log('✓ Docker服务正在运行', colors.green);

        // 检查Hummingbot镜像
        try {
            execSync('docker pull hummingbot/hummingbot:latest', { stdio: 'inherit' });
            log('✓ Hummingbot镜像已拉取', colors.green);
        } catch (error) {
            log(`⚠ 警告: 无法拉取Hummingbot镜像: ${error.message}`, colors.yellow);
        }

        return true;
    } catch (error) {
        log(`✗ Docker检查失败: ${error.message}`, colors.red);
        log('请确保Docker服务已启动', colors.yellow);
        return false;
    }
}

// 检查Python依赖
function checkPythonDependencies() {
    log('检查Python依赖...', colors.blue);

    // 尝试查找requirements.txt文件的多个可能位置
    const possiblePaths = [
        path.join(__dirname, '..', 'requirements.txt'),
        path.join(process.cwd(), 'requirements.txt'),
        '/app/requirements.txt' // Docker容器内的路径
    ];

    let requirementsPath = null;
    for (const p of possiblePaths) {
        if (fs.existsSync(p)) {
            requirementsPath = p;
            log(`✓ 找到requirements.txt文件: ${p}`, colors.green);
            break;
        }
    }

    if (!requirementsPath) {
        log(`✗ 未找到requirements.txt文件`, colors.red);
        return false;
    }

    try {
        const pythonCommand = os.platform() === 'win32' ? 'python' : 'python3';

        // 安装依赖
        log('安装Python依赖...', colors.cyan);
        execSync(`${pythonCommand} -m pip install -r ${requirementsPath}`, { stdio: 'inherit' });

        // 验证关键依赖
        const keyDependencies = ['docker', 'pyyaml', 'ccxt', 'loguru'];
        let allInstalled = true;

        for (const dep of keyDependencies) {
            try {
                execSync(`${pythonCommand} -c "import ${dep}"`, { stdio: 'ignore' });
                log(`✓ ${dep}已安装`, colors.green);
            } catch (error) {
                log(`✗ ${dep}安装失败`, colors.red);
                allInstalled = false;
            }
        }

        return allInstalled;
    } catch (error) {
        log(`✗ 依赖安装失败: ${error.message}`, colors.red);
        return false;
    }
}

// 创建必要的目录
function createDirectories() {
    log('创建必要的目录...', colors.blue);

    const baseDir = isRunningInContainer() ? '/app' : path.join(__dirname, '..');
    const directories = [
        path.join(baseDir, 'logs'),
        path.join(baseDir, 'data'),
        path.join(baseDir, 'strategy_files')
    ];

    for (const dir of directories) {
        try {
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
                log(`✓ 创建目录: ${dir}`, colors.green);
            } else {
                log(`✓ 目录已存在: ${dir}`, colors.green);
            }
        } catch (error) {
            log(`✗ 无法创建目录 ${dir}: ${error.message}`, colors.red);
        }
    }
}

// 主函数
async function main() {
    log('===== 加密货币网格交易系统环境检查 =====', colors.magenta);

    const inContainer = isRunningInContainer();
    if (inContainer) {
        log('⚠ 检测到在Docker容器内运行，将调整检查流程', colors.yellow);
    }

    const pythonOk = checkPython();
    const dockerOk = checkDocker(); // 现在会自动跳过容器内的Docker检查
    const dependenciesOk = pythonOk && checkPythonDependencies();

    createDirectories();

    log('\n===== 检查结果 =====', colors.magenta);
    log(`Python环境: ${pythonOk ? '✓ 正常' : '✗ 异常'}`, pythonOk ? colors.green : colors.red);
    log(`Docker环境: ${dockerOk ? '✓ 正常' : '✗ 异常'}`, dockerOk ? colors.green : colors.red);
    log(`Python依赖: ${dependenciesOk ? '✓ 正常' : '✗ 异常'}`, dependenciesOk ? colors.green : colors.red);

    if (pythonOk && dockerOk && dependenciesOk) {
        log('\n✓ 环境检查通过，可以开始使用系统', colors.green);
        process.exit(0);
    } else {
        log('\n✗ 环境检查未通过，请解决上述问题后重试', colors.red);
        process.exit(1);
    }
}

main().catch(error => {
    log(`✗ 检查过程中发生错误: ${error.message}`, colors.red);
    process.exit(1);
}); 