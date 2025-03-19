#!/usr/bin/env node

/**
 * 系统流程测试脚本
 * 用于验证整个系统流程
 */

const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
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

// 运行命令并返回Promise
function runCommand(command, args, options = {}) {
    return new Promise((resolve, reject) => {
        log(`运行命令: ${command} ${args.join(' ')}`, colors.blue);

        const proc = spawn(command, args, {
            stdio: options.silent ? 'ignore' : 'inherit',
            ...options
        });

        let stdout = '';
        let stderr = '';

        if (proc.stdout) {
            proc.stdout.on('data', (data) => {
                stdout += data.toString();
                if (!options.silent) {
                    process.stdout.write(data);
                }
            });
        }

        if (proc.stderr) {
            proc.stderr.on('data', (data) => {
                stderr += data.toString();
                if (!options.silent) {
                    process.stderr.write(data);
                }
            });
        }

        proc.on('close', (code) => {
            if (code === 0) {
                resolve({ code, stdout, stderr });
            } else {
                reject(new Error(`命令执行失败，退出码: ${code}\n${stderr}`));
            }
        });

        proc.on('error', (err) => {
            reject(err);
        });
    });
}

// 测试Python环境
async function testPythonEnvironment() {
    log('\n===== 测试Python环境 =====', colors.magenta);

    try {
        const pythonCommand = os.platform() === 'win32' ? 'python' : 'python3';

        // 测试Python版本
        const { stdout } = await runCommand(pythonCommand, ['--version'], { silent: true });
        log(`Python版本: ${stdout.trim()}`, colors.green);

        // 测试SQLite连接
        const sqliteTestCode = `
import sqlite3
conn = sqlite3.connect(':memory:')
cursor = conn.cursor()
cursor.execute('CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)')
cursor.execute('INSERT INTO test VALUES (1, "测试成功")')
cursor.execute('SELECT * FROM test')
print(cursor.fetchall())
conn.close()
print("SQLite测试成功")
`;

        const tempFile = path.join(os.tmpdir(), 'sqlite_test.py');
        fs.writeFileSync(tempFile, sqliteTestCode);

        await runCommand(pythonCommand, [tempFile]);
        fs.unlinkSync(tempFile);

        log('✓ Python环境测试通过', colors.green);
        return true;
    } catch (error) {
        log(`✗ Python环境测试失败: ${error.message}`, colors.red);
        return false;
    }
}

// 测试Docker环境
async function testDockerEnvironment() {
    log('\n===== 测试Docker环境 =====', colors.magenta);

    try {
        // 检查Docker版本
        await runCommand('docker', ['--version']);

        // 测试运行简单容器
        await runCommand('docker', ['run', '--rm', 'hello-world']);

        // 检查Hummingbot镜像
        const { stdout } = await runCommand('docker', ['images', 'hummingbot/hummingbot', '--format', '{{.Repository}}:{{.Tag}}'], { silent: true });

        if (stdout.includes('hummingbot/hummingbot')) {
            log(`✓ 找到Hummingbot镜像: ${stdout.trim()}`, colors.green);
        } else {
            log('⚠ 未找到Hummingbot镜像，尝试拉取...', colors.yellow);
            await runCommand('docker', ['pull', 'hummingbot/hummingbot:latest']);
        }

        log('✓ Docker环境测试通过', colors.green);
        return true;
    } catch (error) {
        log(`✗ Docker环境测试失败: ${error.message}`, colors.red);
        return false;
    }
}

// 测试Hummingbot配置
async function testHummingbotConfig() {
    log('\n===== 测试Hummingbot配置 =====', colors.magenta);

    try {
        const pythonCommand = os.platform() === 'win32' ? 'python' : 'python3';
        const configTestCode = `
import yaml
import os
from pathlib import Path

# 创建测试目录
test_dir = Path("test_strategy")
test_dir.mkdir(exist_ok=True)

# 创建配置文件
config = {
    'template': 'pure_market_making',
    'exchange': 'binance',
    'market': 'BTC-USDT',
    'bid_spread': 0.01,
    'ask_spread': 0.01,
    'order_amount': 0.01
}

# 写入配置文件
config_path = test_dir / "conf_test.yml"
with open(config_path, 'w') as f:
    yaml.dump(config, f)

print(f"配置文件已创建: {config_path}")

# 验证配置文件
with open(config_path, 'r') as f:
    loaded_config = yaml.safe_load(f)

# 检查必要字段
required_fields = ['exchange', 'market', 'bid_spread', 'ask_spread']
missing_fields = [field for field in required_fields if field not in loaded_config]

if missing_fields:
    print(f"配置缺少必要字段: {', '.join(missing_fields)}")
    exit(1)
else:
    print("配置验证通过")
`;

        const tempFile = path.join(os.tmpdir(), 'config_test.py');
        fs.writeFileSync(tempFile, configTestCode);

        await runCommand(pythonCommand, [tempFile]);
        fs.unlinkSync(tempFile);

        // 清理测试目录
        if (fs.existsSync('test_strategy')) {
            fs.rmSync('test_strategy', { recursive: true, force: true });
        }

        log('✓ Hummingbot配置测试通过', colors.green);
        return true;
    } catch (error) {
        log(`✗ Hummingbot配置测试失败: ${error.message}`, colors.red);
        return false;
    }
}

// 测试网络连接
async function testNetworkConnection() {
    log('\n===== 测试网络连接 =====', colors.magenta);

    try {
        const pythonCommand = os.platform() === 'win32' ? 'python' : 'python3';
        const networkTestCode = `
import requests
import json
import sys

def test_exchange_api(exchange):
    """测试交易所API连接"""
    try:
        if exchange == 'binance':
            url = 'https://api.binance.com/api/v3/ping'
        elif exchange == 'kucoin':
            url = 'https://api.kucoin.com/api/v1/timestamp'
        else:
            print(f"不支持的交易所: {exchange}")
            return False
            
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        print(f"成功连接到{exchange} API: {response.text}")
        return True
    except Exception as e:
        print(f"连接{exchange} API失败: {e}")
        return False

# 测试主要交易所
exchanges = ['binance', 'kucoin']
results = {}

for exchange in exchanges:
    results[exchange] = test_exchange_api(exchange)

# 输出结果
print(json.dumps(results))

# 检查是否全部成功
if all(results.values()):
    sys.exit(0)
else:
    sys.exit(1)
`;

        const tempFile = path.join(os.tmpdir(), 'network_test.py');
        fs.writeFileSync(tempFile, networkTestCode);

        await runCommand(pythonCommand, [tempFile]);
        fs.unlinkSync(tempFile);

        log('✓ 网络连接测试通过', colors.green);
        return true;
    } catch (error) {
        log(`✗ 网络连接测试失败: ${error.message}`, colors.red);
        log('⚠ 这可能是由于网络问题或交易所API暂时不可用', colors.yellow);
        return false;
    }
}

// 测试Python脚本
async function testPythonScript() {
    log('\n===== 测试Python脚本 =====', colors.magenta);

    try {
        const pythonDir = path.join(__dirname, '..', 'src', 'python');

        // 确保Python目录存在
        if (!fs.existsSync(pythonDir)) {
            log(`✗ Python目录不存在: ${pythonDir}`, colors.red);
            return false;
        }

        const pythonCommand = os.platform() === 'win32' ? 'python' : 'python3';

        // 测试main.py (如果存在)
        const mainPyPath = path.join(pythonDir, 'main.py');
        if (fs.existsSync(mainPyPath)) {
            await runCommand(pythonCommand, [mainPyPath]);
            log('✓ main.py测试通过', colors.green);
        } else {
            log(`⚠ main.py不存在: ${mainPyPath}`, colors.yellow);
        }

        // 测试hummingbot_manager.py (如果存在)
        const managerPyPath = path.join(pythonDir, 'hummingbot_manager.py');
        if (fs.existsSync(managerPyPath)) {
            // 创建一个简单的测试脚本
            const testCode = `
import sys
import os
sys.path.append('${pythonDir.replace(/\\/g, '\\\\')}')
import hummingbot_manager

# 只测试导入，不执行任何操作
print("hummingbot_manager导入成功")
`;

            const tempFile = path.join(os.tmpdir(), 'manager_test.py');
            fs.writeFileSync(tempFile, testCode);

            await runCommand(pythonCommand, [tempFile]);
            fs.unlinkSync(tempFile);

            log('✓ hummingbot_manager.py测试通过', colors.green);
        } else {
            log(`⚠ hummingbot_manager.py不存在: ${managerPyPath}`, colors.yellow);
        }

        log('✓ Python脚本测试通过', colors.green);
        return true;
    } catch (error) {
        log(`✗ Python脚本测试失败: ${error.message}`, colors.red);
        return false;
    }
}

// 主函数
async function main() {
    log('===== 加密货币网格交易系统流程测试 =====', colors.magenta);

    // 创建必要的目录
    const directories = [
        path.join(__dirname, '..', 'logs'),
        path.join(__dirname, '..', 'data'),
        path.join(__dirname, '..', 'strategy_files')
    ];

    for (const dir of directories) {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
    }

    // 运行测试
    const results = {
        python: await testPythonEnvironment(),
        docker: await testDockerEnvironment(),
        config: await testHummingbotConfig(),
        network: await testNetworkConnection(),
        script: await testPythonScript()
    };

    // 输出结果
    log('\n===== 测试结果 =====', colors.magenta);
    log(`Python环境: ${results.python ? '✓ 通过' : '✗ 失败'}`, results.python ? colors.green : colors.red);
    log(`Docker环境: ${results.docker ? '✓ 通过' : '✗ 失败'}`, results.docker ? colors.green : colors.red);
    log(`Hummingbot配置: ${results.config ? '✓ 通过' : '✗ 失败'}`, results.config ? colors.green : colors.red);
    log(`网络连接: ${results.network ? '✓ 通过' : '✗ 失败'}`, results.network ? colors.green : colors.red);
    log(`Python脚本: ${results.script ? '✓ 通过' : '✗ 失败'}`, results.script ? colors.green : colors.red);

    // 总结
    const allPassed = Object.values(results).every(Boolean);
    if (allPassed) {
        log('\n✓ 所有测试通过，系统流程验证成功', colors.green);
        process.exit(0);
    } else {
        log('\n✗ 部分测试失败，请检查上述错误', colors.red);
        process.exit(1);
    }
}

main().catch(error => {
    log(`✗ 测试过程中发生错误: ${error.message}`, colors.red);
    process.exit(1);
}); 