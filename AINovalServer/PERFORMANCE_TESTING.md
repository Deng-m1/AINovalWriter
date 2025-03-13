# AI小说助手系统性能测试指南

本文档提供了AI小说助手系统性能测试的详细说明，包括测试工具的使用方法、测试场景和结果分析。

## 1. 测试工具

### 1.1 Postman集合

我们提供了一个完整的Postman集合，包含所有性能测试接口：

- 文件位置：`AINoval_Performance_Tests.postman_collection.json`
- 导入方法：在Postman中点击"Import" -> 选择该文件

集合包含以下测试分组：
- 认证（用于获取JWT令牌和CSRF令牌）
- 数据生成与管理
- 性能测试
- 系统监控
- 小说管理接口
- 场景管理接口
- AI交互接口

**使用认证的步骤：**
1. 首先执行"登录获取Token"请求，系统会自动将JWT令牌保存到环境变量
2. 然后执行"获取CSRF令牌"请求，获取CSRF令牌
3. 之后所有请求都会自动使用这些令牌

### 1.2 自动化测试脚本

我们还提供了一个Node.js自动化测试脚本，可以一键执行所有性能测试：

- 文件位置：`performance_test_script.js`
- 使用方法：
  ```bash
  # 安装依赖
  npm install axios chalk
  
  # 运行测试（标准模式，需要认证）
  node performance_test_script.js
  
  # 运行测试（测试模式，无需认证）
  TEST_MODE=true node performance_test_script.js
  ```

**脚本认证配置：**
脚本会自动处理认证流程，默认使用以下配置：
```javascript
auth: {
    username: 'admin',
    password: 'admin123'
}
```
如需修改认证信息，请编辑脚本中的这一部分。

### 1.3 快速启动脚本

为了方便测试，我们提供了快速启动脚本，可以一键启动测试环境：

- Windows: `start-performance-test.bat`
- Linux/Mac: `start-performance-test.sh`

这些脚本会：
1. 以性能测试配置启动应用程序（使用`performance-test`配置文件）
2. 等待应用程序启动完成
3. 以测试模式启动性能测试脚本（无需认证）

使用方法：
```bash
# Windows
start-performance-test.bat

# Linux/Mac
chmod +x start-performance-test.sh
./start-performance-test.sh
```

## 2. 测试场景

### 2.1 数据生成测试

测试系统生成和存储大量测试数据的能力：

- 接口：`POST /performance-test/generate-data?count={count}`
- 参数：`count` - 要生成的小说数量
- 测试指标：数据生成速度、数据库写入性能
- 认证要求：需要JWT令牌和CSRF令牌（在测试模式下无需认证）

### 2.2 小说查询性能测试

测试系统在高并发下查询小说的性能：

- 接口：`GET /performance-test/novel-query-test?concurrentUsers={users}&requestsPerUser={requests}`
- 参数：
  - `concurrentUsers` - 并发用户数
  - `requestsPerUser` - 每个用户的请求数
- 测试指标：响应时间、吞吐量、成功率
- 认证要求：需要JWT令牌（在测试模式下无需认证）

### 2.3 场景查询性能测试

测试系统在高并发下查询场景的性能：

- 接口：`GET /performance-test/scene-query-test?concurrentUsers={users}&requestsPerUser={requests}`
- 参数：同上
- 测试指标：同上
- 认证要求：需要JWT令牌（在测试模式下无需认证）

### 2.4 小说创建性能测试

测试系统在高并发下创建小说的性能：

- 接口：`POST /performance-test/novel-create-test?concurrentUsers={users}&requestsPerUser={requests}`
- 参数：同上
- 测试指标：同上
- 认证要求：需要JWT令牌和CSRF令牌（在测试模式下无需认证）

### 2.5 系统监控

实时监控系统资源使用情况：

- 接口：`GET /performance-test/server-status`
- 接口：`GET /performance-test/monitor` (SSE流式接口)
- 测试指标：CPU使用率、内存使用、JVM状态
- 认证要求：需要JWT令牌（在测试模式下无需认证）

## 3. 测试配置

### 3.1 测试环境

- 服务器：[服务器配置，如CPU、内存等]
- 数据库：MongoDB [版本]
- JVM：Java [版本]，配置 `-Xmx4g -Xms2g`
- 操作系统：[操作系统信息]
- 安全配置：使用JWT认证和CSRF保护（可在测试模式下禁用）

### 3.2 测试参数

默认测试参数如下，可根据实际情况调整：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 测试数据量 | 20部小说 | 每部小说包含多个场景和角色 |
| 查询测试并发用户数 | 50 | 同时查询的用户数 |
| 查询测试每用户请求数 | 10 | 每个用户发送的请求数 |
| 创建测试并发用户数 | 20 | 同时创建小说的用户数 |
| 创建测试每用户请求数 | 5 | 每个用户发送的请求数 |

### 3.3 安全配置

系统使用以下安全机制：

- **JWT认证**：所有API请求都需要在请求头中包含有效的JWT令牌
  ```
  Authorization: Bearer <token>
  ```

- **CSRF保护**：所有修改数据的请求（POST/PUT/DELETE）需要包含CSRF令牌
  ```
  X-CSRF-TOKEN: <token>
  ```

### 3.4 测试模式

为了方便测试，系统提供了测试模式，可以禁用安全验证：

1. **使用测试配置文件**：
   - 启动应用时使用`performance-test`配置文件：
     ```
     mvn spring-boot:run -Dspring-boot.run.profiles=performance-test
     ```
   - 这将激活`TestSecurityConfig`，禁用JWT验证和CSRF保护

2. **使用测试模式脚本**：
   - 设置环境变量`TEST_MODE=true`运行测试脚本：
     ```
     TEST_MODE=true node performance_test_script.js
     ```
   - 这将跳过认证步骤，不添加认证头

3. **使用快速启动脚本**：
   - 运行`start-performance-test.bat`或`start-performance-test.sh`
   - 这将自动配置并启动测试环境

## 4. 测试结果分析

### 4.1 性能指标

| 测试场景 | 并发用户数 | 每用户请求数 | 总请求数 | 成功率 | 平均响应时间 | 吞吐量(TPS) |
|---------|------------|-------------|---------|--------|-------------|------------|
| 小说查询 | 50 | 10 | 500 | 100% | <200ms | >100/s |
| 场景查询 | 50 | 10 | 500 | 100% | <150ms | >120/s |
| 小说创建 | 20 | 5 | 100 | 100% | <300ms | >30/s |

### 4.2 资源使用情况

- CPU使用率峰值：[数值]%
- 内存使用峰值：[数值]MB
- GC频率：[数值]
- 数据库连接数峰值：[数值]

### 4.3 性能瓶颈分析

根据测试结果，系统的主要性能瓶颈在于：

1. [瓶颈1]：[分析和解决方案]
2. [瓶颈2]：[分析和解决方案]
3. [瓶颈3]：[分析和解决方案]

### 4.4 优化建议

基于测试结果，我们提出以下优化建议：

1. **数据库优化**：
   - 添加适当的索引
   - 优化查询语句
   - 考虑分片或读写分离

2. **应用层优化**：
   - 增加缓存层
   - 优化响应式流处理
   - 调整线程池配置

3. **基础设施优化**：
   - 增加服务器资源
   - 调整JVM参数
   - 考虑水平扩展

4. **安全性能优化**：
   - 考虑使用JWT缓存减少验证开销
   - 优化CSRF令牌生成和验证逻辑
   - 评估是否所有接口都需要CSRF保护

## 5. 持续性能监控

为了确保系统在生产环境中保持良好性能，建议实施以下持续监控措施：

1. 使用Prometheus和Grafana监控系统指标
2. 设置关键性能指标的告警阈值
3. 定期执行性能测试，对比历史数据
4. 在每次重大版本发布前进行全面性能测试

## 6. 附录

### 6.1 测试数据示例

```json
{
  "novel": {
    "id": "sample-id",
    "title": "示例小说",
    "description": "这是一个示例小说",
    "author": {
      "id": "author-id",
      "username": "测试作者"
    }
  }
}
```

### 6.2 常见问题排查

1. **测试失败**：检查服务器和数据库连接
2. **性能下降**：检查数据库索引和查询计划
3. **内存泄漏**：分析堆转储，检查对象引用
4. **认证问题**：
   - "An expected CSRF token cannot be found" - 确保请求包含有效的CSRF令牌，或使用测试模式
   - "Invalid JWT token" - 检查JWT令牌是否有效或已过期，或使用测试模式
   - "Access denied" - 检查用户权限和认证信息，或使用测试模式

### 6.3 相关资源

- [Spring WebFlux性能调优指南](https://docs.spring.io/spring-framework/reference/web/webflux/reactive-spring.html)
- [MongoDB性能最佳实践](https://www.mongodb.com/docs/manual/core/query-optimization/)
- [JVM调优参考](https://docs.oracle.com/en/java/javase/17/gctuning/introduction-garbage-collection-tuning.html)
- [Spring Security文档](https://docs.spring.io/spring-security/reference/index.html) 