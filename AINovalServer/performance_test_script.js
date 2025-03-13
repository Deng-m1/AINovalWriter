/**
 * AI小说助手系统性能测试脚本
 * 
 * 使用方法：
 * 1. 安装依赖：npm install axios chalk
 * 2. 运行脚本：node performance_test_script.js
 * 
 * 环境变量：
 * - TEST_MODE=true 启用测试模式，不进行认证
 */

const axios = require('axios');
const chalk = require('chalk');

// 检查是否为测试模式
const isTestMode = process.env.TEST_MODE === 'true';

// 配置
const config = {
    baseUrl: 'http://localhost:8088/api',
    dataCount: 20,  // 生成的小说数量
    concurrentUsers: {
        query: 50,   // 查询测试的并发用户数
        create: 20    // 创建测试的并发用户数
    },
    requestsPerUser: {
        query: 10,    // 每个用户的查询请求数
        create: 5     // 每个用户的创建请求数
    },
    auth: {
        username: 'admin',
        password: 'admin123'
    }
};

// 认证信息
let authToken = '';
let csrfToken = '';

// 格式化时间
function formatDuration(ms) {
    if (ms < 1000) return `${ms}ms`;
    const seconds = Math.floor(ms / 1000);
    const remainingMs = ms % 1000;
    return `${seconds}.${remainingMs}s`;
}

// 打印结果
function printResult(title, result) {
    console.log(chalk.cyan('\n==================================='));
    console.log(chalk.cyan(`${title}`));
    console.log(chalk.cyan('==================================='));
    
    if (result.success) {
        console.log(chalk.green(`✓ ${result.message}`));
        
        if (result.totalRequests) {
            console.log(chalk.yellow(`总请求数: ${result.totalRequests}`));
            console.log(chalk.yellow(`成功请求数: ${result.successfulRequests}`));
            console.log(chalk.yellow(`总耗时: ${formatDuration(result.totalTimeMs)}`));
            console.log(chalk.yellow(`每秒请求数: ${result.requestsPerSecond}/秒`));
        }
        
        if (result.novelCount) {
            console.log(chalk.yellow(`小说数量: ${result.novelCount}`));
            console.log(chalk.yellow(`场景数量: ${result.sceneCount}`));
            console.log(chalk.yellow(`角色数量: ${result.characterCount}`));
        }
    } else {
        console.log(chalk.red(`✗ ${result.message}`));
    }
}

// 获取认证令牌
async function authenticate() {
    // 测试模式下跳过认证
    if (isTestMode) {
        console.log(chalk.blue('测试模式：跳过认证步骤'));
        return true;
    }
    
    try {
        console.log(chalk.blue('正在获取认证令牌...'));
        const loginResponse = await axios.post(
            `${config.baseUrl}/auth/login`,
            {
                username: config.auth.username,
                password: config.auth.password
            }
        );
        
        if (loginResponse.data && loginResponse.data.token) {
            authToken = loginResponse.data.token;
            console.log(chalk.green('✓ 成功获取JWT令牌'));
            
            // 获取CSRF令牌
            const csrfResponse = await axios.get(
                `${config.baseUrl}/auth/csrf`,
                {
                    headers: {
                        'Authorization': `Bearer ${authToken}`
                    }
                }
            );
            
            if (csrfResponse.headers && csrfResponse.headers['x-csrf-token']) {
                csrfToken = csrfResponse.headers['x-csrf-token'];
                console.log(chalk.green('✓ 成功获取CSRF令牌'));
            } else {
                console.log(chalk.yellow('! 未能获取CSRF令牌，将尝试继续测试'));
            }
            
            return true;
        } else {
            console.log(chalk.red('✗ 认证失败：未能获取令牌'));
            return false;
        }
    } catch (error) {
        console.log(chalk.red(`✗ 认证过程中出错: ${error.message}`));
        if (error.response) {
            console.log(chalk.red(`状态码: ${error.response.status}`));
            console.log(chalk.red(`错误信息: ${JSON.stringify(error.response.data)}`));
        }
        return false;
    }
}

// 创建带认证的请求头
function createAuthHeaders(needCsrf = false) {
    // 测试模式下不添加认证头
    if (isTestMode) {
        return {
            'Content-Type': 'application/json'
        };
    }
    
    const headers = {
        'Content-Type': 'application/json'
    };
    
    if (authToken) {
        headers['Authorization'] = `Bearer ${authToken}`;
    }
    
    if (needCsrf && csrfToken) {
        headers['X-CSRF-TOKEN'] = csrfToken;
    }
    
    return headers;
}

// 测试步骤
async function runTests() {
    try {
        console.log(chalk.blue('开始AI小说助手系统性能测试...'));
        console.log(chalk.blue(`运行模式: ${isTestMode ? '测试模式（无认证）' : '标准模式（需认证）'}`));
        
        // 先进行认证
        const authenticated = await authenticate();
        if (!authenticated && !isTestMode) {
            console.log(chalk.red('认证失败，无法继续测试'));
            return;
        }
        
        // 清除现有数据
        console.log(chalk.blue('\n清除现有测试数据...'));
        const clearResult = await axios.delete(
            `${config.baseUrl}/performance-test/clear-data`,
            {
                headers: createAuthHeaders(true)
            }
        );
        printResult('清除测试数据', clearResult.data);
        
        // 生成测试数据
        console.log(chalk.blue('\n生成测试数据...'));
        const generateResult = await axios.post(
            `${config.baseUrl}/performance-test/generate-data?count=${config.dataCount}`,
            {},
            {
                headers: createAuthHeaders(true)
            }
        );
        printResult('生成测试数据', generateResult.data);
        
        // 获取数据库统计
        console.log(chalk.blue('\n获取数据库统计...'));
        const statsResult = await axios.get(
            `${config.baseUrl}/performance-test/stats`,
            {
                headers: createAuthHeaders()
            }
        );
        printResult('数据库统计', statsResult.data);
        
        // 小说查询性能测试
        console.log(chalk.blue('\n执行小说查询性能测试...'));
        const novelQueryResult = await axios.get(
            `${config.baseUrl}/performance-test/novel-query-test?concurrentUsers=${config.concurrentUsers.query}&requestsPerUser=${config.requestsPerUser.query}`,
            {
                headers: createAuthHeaders()
            }
        );
        printResult('小说查询性能测试', novelQueryResult.data);
        
        // 场景查询性能测试
        console.log(chalk.blue('\n执行场景查询性能测试...'));
        const sceneQueryResult = await axios.get(
            `${config.baseUrl}/performance-test/scene-query-test?concurrentUsers=${config.concurrentUsers.query}&requestsPerUser=${config.requestsPerUser.query}`,
            {
                headers: createAuthHeaders()
            }
        );
        printResult('场景查询性能测试', sceneQueryResult.data);
        
        // 小说创建性能测试
        console.log(chalk.blue('\n执行小说创建性能测试...'));
        const novelCreateResult = await axios.post(
            `${config.baseUrl}/performance-test/novel-create-test?concurrentUsers=${config.concurrentUsers.create}&requestsPerUser=${config.requestsPerUser.create}`,
            {},
            {
                headers: createAuthHeaders(true)
            }
        );
        printResult('小说创建性能测试', novelCreateResult.data);
        
        // 获取服务器状态
        console.log(chalk.blue('\n获取服务器状态...'));
        const serverStatusResult = await axios.get(
            `${config.baseUrl}/performance-test/server-status`,
            {
                headers: createAuthHeaders()
            }
        );
        console.log(chalk.cyan('\n==================================='));
        console.log(chalk.cyan('服务器状态'));
        console.log(chalk.cyan('==================================='));
        console.log(chalk.yellow(`处理器数量: ${serverStatusResult.data.availableProcessors}`));
        console.log(chalk.yellow(`最大内存: ${serverStatusResult.data.maxMemoryMB}MB`));
        console.log(chalk.yellow(`已用内存: ${serverStatusResult.data.usedMemoryMB}MB`));
        console.log(chalk.yellow(`空闲内存: ${serverStatusResult.data.freeMemoryMB}MB`));
        console.log(chalk.yellow(`Java版本: ${serverStatusResult.data.javaVersion}`));
        console.log(chalk.yellow(`操作系统: ${serverStatusResult.data.osName} ${serverStatusResult.data.osVersion}`));
        
        console.log(chalk.green('\n✓ 所有测试完成!'));
        
    } catch (error) {
        console.log(chalk.red('\n✗ 测试过程中出错:'));
        if (error.response) {
            console.log(chalk.red(`状态码: ${error.response.status}`));
            console.log(chalk.red(`错误信息: ${JSON.stringify(error.response.data)}`));
        } else {
            console.log(chalk.red(error.message));
        }
    }
}

// 运行测试
runTests(); 