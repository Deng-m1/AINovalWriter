# AI小说助手系统后端概要设计文档

## 一、系统概述

AI小说助手系统是一个基于云端的小说创作管理平台，通过AI技术辅助作者完成小说的全生命周期管理，包括创意构思、人物塑造、情节设计、内容创作和修改完善等环节。系统采用现代化的响应式架构，结合虚拟线程技术，提供高性能、可扩展的创作平台。

### 1.1 系统目标

- 提供全面的小说创作生命周期管理
- 利用AI技术辅助创作过程的各个环节
- 实现知识库检索功能，为大模型提供上下文
- 支持高并发访问和响应式交互
- 提供良好的用户体验和性能表现

### 1.2 技术选型

- **后端框架**：Spring Boot 3.2.0 + WebFlux
- **编程语言**：Java 21（支持虚拟线程）
- **数据存储**：MongoDB（单一数据库方案）
- **AI集成**：多模型适配器架构
- **向量检索**：MongoDB Atlas Vector Search
- **响应式编程**：Project Reactor
- **并发处理**：JDK 21虚拟线程

## 二、系统架构

### 2.1 整体架构

系统采用分层架构，包括表现层、应用层、领域层和基础设施层，各层之间通过接口进行解耦，保证系统的可扩展性和可维护性。

```
+------------------------------------------+
|             表现层 (Presentation)         |
|  +----------------+  +----------------+  |
|  |    Web控制器    |  |   API控制器     |  |
|  +----------------+  +----------------+  |
+------------------------------------------+
                |
+------------------------------------------+
|             应用层 (Application)          |
|  +----------------+  +----------------+  |
|  |    服务门面     |  |   事件处理器    |  |
|  +----------------+  +----------------+  |
+------------------------------------------+
                |
+------------------------------------------+
|             领域层 (Domain)               |
|  +----------------+  +----------------+  |
|  |   领域服务     |  |   领域模型      |  |
|  +----------------+  +----------------+  |
+------------------------------------------+
                |
+------------------------------------------+
|           基础设施层 (Infrastructure)     |
|  +--------+  +--------+  +--------+     |
|  | 数据访问 |  | AI集成 |  | 知识库 |     |
|  +--------+  +--------+  +--------+     |
+------------------------------------------+
```

### 2.2 核心组件

1. **响应式Web框架**：处理HTTP请求和响应，支持非阻塞I/O
2. **AI服务抽象层**：统一不同AI模型的接口，处理提示和响应
3. **知识库抽象层**：管理向量存储和检索，提供上下文
4. **数据访问抽象层**：封装MongoDB操作，提供响应式数据访问
5. **领域模型框架**：定义系统核心业务实体和逻辑

### 2.3 技术架构特点

1. **响应式编程模型**：
   - 非阻塞I/O处理
   - 基于事件驱动的异步处理
   - 支持背压机制

2. **虚拟线程应用**：
   - 高效处理大量并发连接
   - 降低线程资源消耗
   - 简化异步编程模型

3. **单一数据库策略**：
   - 使用MongoDB作为唯一数据存储
   - 利用文档模型存储小说内容和结构
   - 使用Atlas Vector Search支持向量检索

## 三、核心模块设计

### 3.1 用户管理模块

**功能职责**：
- 用户注册、登录和身份验证
- 用户配置文件管理
- 权限和角色管理

**关键组件**：
- `UserController`：处理用户相关请求
- `UserService`：用户业务逻辑处理
- `UserRepository`：用户数据访问
- `JwtService`：JWT令牌管理

**数据模型**：
```javascript
// User集合
{
  _id: ObjectId,
  username: String,
  email: String,
  passwordHash: String,
  roles: [String],
  profile: {
    displayName: String,
    bio: String,
    avatar: String
  },
  preferences: {
    theme: String,
    notifications: Object
  },
  createdAt: Date,
  updatedAt: Date
}
```

### 3.2 小说管理模块

**功能职责**：
- 小说创建和基本信息管理
- 小说结构（卷、章节、场景）管理
- 内容编辑和版本控制

**关键组件**：
- `NovelController`：处理小说相关请求
- `NovelService`：小说业务逻辑处理
- `NovelRepository`：小说数据访问
- `StructureService`：小说结构管理

**数据模型**：
参考MongoDB数据模型设计中的小说结构模型和场景内容模型

### 3.3 AI服务模块

**功能职责**：
- AI模型集成和管理
- 内容生成和建议
- 提示工程和上下文管理
- 流式响应处理

**关键组件**：
- `AIController`：处理AI相关请求
- `AIService`：AI业务逻辑处理
- `ModelProviderFactory`：AI模型提供商工厂
- `PromptManager`：提示管理
- `StreamingResponseHandler`：流式响应处理

**接口设计**：
```java
public interface AIModelProvider {
    Flux<String> generateContent(PromptRequest request);
    Mono<Double> estimateCost(PromptRequest request);
    String getProviderName();
}
```

### 3.4 知识库模块

**功能职责**：
- 文本分块和向量化
- 向量存储和检索
- 上下文组装和优化

**关键组件**：
- `KnowledgeController`：处理知识库相关请求
- `KnowledgeService`：知识库业务逻辑处理
- `VectorStore`：向量存储接口
- `TextProcessor`：文本处理服务

**接口设计**：
```java
public interface VectorStore {
    Mono<Void> storeVector(String id, float[] vector, Map<String, Object> metadata);
    Flux<SearchResult> search(float[] queryVector, int limit);
}
```

### 3.5 角色管理模块

**功能职责**：
- 角色创建和编辑
- 角色关系管理
- 角色与场景关联

**关键组件**：
- `CharacterController`：处理角色相关请求
- `CharacterService`：角色业务逻辑处理
- `CharacterRepository`：角色数据访问
- `RelationshipService`：角色关系管理

**数据模型**：
参考MongoDB数据模型设计中的角色模型

## 四、数据模型设计

### 4.1 MongoDB集合设计

系统使用MongoDB作为唯一数据存储，主要集合包括：

1. **User集合**：存储用户信息
2. **Novel集合**：存储小说基本信息和结构
3. **Scene集合**：存储场景内容
4. **Character集合**：存储角色信息
5. **AIInteraction集合**：存储AI交互历史
6. **KnowledgeChunk集合**：存储知识块和向量表示

### 4.2 数据关系处理

由于MongoDB是文档型数据库，系统通过以下方式处理数据关系：

1. **嵌入文档**：适用于一对多关系，如小说结构中的卷和章节
2. **引用关系**：适用于多对多关系，如角色与场景的关联
3. **应用层关联**：在应用层实现复杂关系的处理和查询

### 4.3 索引策略

为保证查询性能，系统将建立以下索引：

1. **标准索引**：针对常用查询字段，如`novelId`、`userId`等
2. **复合索引**：针对多字段查询条件
3. **文本索引**：支持全文搜索功能
4. **向量索引**：支持向量相似度搜索

## 五、关键技术实现

### 5.1 响应式Web框架实现

```java
// 响应式控制器基类
public abstract class ReactiveBaseController {
    protected <T> Mono<ServerResponse> responseOf(Mono<T> result) {
        return result
            .flatMap(data -> ServerResponse.ok().bodyValue(data))
            .onErrorResume(this::handleError);
    }
    
    protected Mono<ServerResponse> handleError(Throwable error) {
        // 统一错误处理逻辑
        if (error instanceof ValidationException) {
            return ServerResponse.badRequest().bodyValue(new ErrorResponse(error.getMessage()));
        } else if (error instanceof ResourceNotFoundException) {
            return ServerResponse.notFound().build();
        } else {
            log.error("Unexpected error", error);
            return ServerResponse.status(500).bodyValue(new ErrorResponse("服务器内部错误"));
        }
    }
}
```

### 5.2 虚拟线程配置

```java
@Configuration
public class VirtualThreadConfig {
    
    @Bean
    public Executor taskExecutor() {
        return Executors.newVirtualThreadPerTaskExecutor();
    }
    
    @Bean
    public ReactorResourceFactory reactorResourceFactory() {
        ReactorResourceFactory factory = new ReactorResourceFactory();
        factory.setUseGlobalResources(false);
        factory.setShutdownQuietPeriod(Duration.ofMillis(100));
        factory.setShutdownTimeout(Duration.ofMillis(200));
        return factory;
    }
}
```

### 5.3 AI服务实现

```java
@Service
public class AIService {
    private final Map<String, AIModelProvider> providers;
    private final PromptManager promptManager;
    private final KnowledgeService knowledgeService;
    
    public Flux<String> generateContent(String modelName, ContentRequest request) {
        return Mono.just(request)
            .flatMap(this::enrichWithContext)
            .map(promptManager::buildPrompt)
            .flatMapMany(prompt -> getProvider(modelName).generateContent(prompt));
    }
    
    private Mono<ContentRequest> enrichWithContext(ContentRequest request) {
        if (!request.isContextEnabled()) {
            return Mono.just(request);
        }
        
        return knowledgeService.retrieveRelevantContext(request.getQuery(), request.getNovelId())
            .map(context -> request.withContext(context));
    }
    
    private AIModelProvider getProvider(String modelName) {
        AIModelProvider provider = providers.get(modelName);
        if (provider == null) {
            throw new IllegalArgumentException("不支持的AI模型: " + modelName);
        }
        return provider;
    }
}
```

### 5.4 知识库检索实现

```java
@Service
public class MongoDBVectorStore implements VectorStore {
    private final ReactiveMongoTemplate mongoTemplate;
    
    @Override
    public Flux<SearchResult> search(float[] queryVector, int limit) {
        Document searchStage = new Document("$search", new Document("knnBeta", new Document()
            .append("vector", queryVector)
            .append("path", "vectorEmbedding.vector")
            .append("k", limit)
            .append("similarity", "cosine")));
        
        Document projectStage = new Document("$project", new Document()
            .append("_id", 1)
            .append("content", 1)
            .append("metadata", 1)
            .append("score", new Document("$meta", "searchScore")));
        
        return mongoTemplate.aggregate(
            Aggregation.newAggregation(
                Aggregation.stage(searchStage),
                Aggregation.stage(projectStage)
            ),
            "knowledgeChunk",
            Document.class
        ).map(this::documentToSearchResult);
    }
    
    private SearchResult documentToSearchResult(Document doc) {
        // 转换文档为SearchResult对象
        return new SearchResult(
            doc.getObjectId("_id").toString(),
            doc.getString("content"),
            doc.get("metadata", Document.class),
            doc.getDouble("score")
        );
    }
}
```

### 5.5 响应式MongoDB数据访问

```java
@Repository
public class ReactiveMongoNovelRepository implements NovelRepository {
    private final ReactiveMongoTemplate mongoTemplate;
    
    @Override
    public Mono<Novel> save(Novel novel) {
        if (novel.getId() == null) {
            novel.setCreatedAt(new Date());
        }
        novel.setUpdatedAt(new Date());
        return mongoTemplate.save(novel);
    }
    
    @Override
    public Mono<Novel> findById(String id) {
        return mongoTemplate.findById(id, Novel.class);
    }
    
    @Override
    public Flux<Novel> findByAuthorId(String authorId) {
        Query query = new Query(Criteria.where("author._id").is(new ObjectId(authorId)));
        return mongoTemplate.find(query, Novel.class);
    }
    
    @Override
    public Mono<Void> deleteById(String id) {
        return mongoTemplate.remove(Query.query(Criteria.where("_id").is(new ObjectId(id))), Novel.class)
            .then();
    }
}
```

## 六、API设计

### 6.1 RESTful API设计原则

- 使用HTTP方法表示操作类型（GET, POST, PUT, DELETE）
- 使用URL路径表示资源
- 使用查询参数进行过滤和分页
- 使用HTTP状态码表示操作结果
- 支持JSON格式的请求和响应

### 6.2 主要API端点

#### 用户管理API

```
POST   /api/auth/register       - 用户注册
POST   /api/auth/login          - 用户登录
GET    /api/users/me            - 获取当前用户信息
PUT    /api/users/me            - 更新用户信息
```

#### 小说管理API

```
GET    /api/novels              - 获取小说列表
POST   /api/novels              - 创建新小说
GET    /api/novels/{id}         - 获取小说详情
PUT    /api/novels/{id}         - 更新小说信息
DELETE /api/novels/{id}         - 删除小说

GET    /api/novels/{id}/structure       - 获取小说结构
PUT    /api/novels/{id}/structure       - 更新小说结构
GET    /api/novels/{id}/scenes/{sceneId} - 获取场景内容
PUT    /api/novels/{id}/scenes/{sceneId} - 更新场景内容
```

#### AI服务API

```
POST   /api/ai/generate         - 生成内容
POST   /api/ai/suggest          - 获取创作建议
POST   /api/ai/revise           - 修改内容
GET    /api/ai/models           - 获取可用AI模型
```

#### 知识库API

```
GET    /api/knowledge/search    - 搜索相关内容
POST   /api/knowledge/index     - 索引内容
```

#### 角色管理API

```
GET    /api/novels/{id}/characters      - 获取角色列表
POST   /api/novels/{id}/characters      - 创建新角色
GET    /api/novels/{id}/characters/{charId} - 获取角色详情
PUT    /api/novels/{id}/characters/{charId} - 更新角色信息
DELETE /api/novels/{id}/characters/{charId} - 删除角色
```

### 6.3 WebSocket API

系统还将提供WebSocket API，用于实时通信和流式响应：

```
WS    /ws/ai/stream            - AI流式响应
WS    /ws/collaboration/{novelId} - 协作编辑
```

## 七、性能优化策略

### 7.1 数据库优化

1. **索引优化**：
   - 为常用查询字段创建索引
   - 使用复合索引减少查询次数
   - 定期分析和优化索引

2. **数据模型优化**：
   - 合理使用嵌入和引用
   - 避免过深的嵌套结构
   - 适当冗余以减少关联查询

3. **查询优化**：
   - 使用投影限制返回字段
   - 使用聚合管道优化复杂查询
   - 实现分页和限制结果集大小

### 7.2 缓存策略

1. **多级缓存**：
   - 内存缓存（应用内缓存）
   - Redis缓存（分布式缓存）
   - 浏览器缓存（客户端缓存）

2. **缓存内容**：
   - 小说结构和元数据
   - 常用查询结果
   - AI响应和知识库检索结果

3. **缓存更新策略**：
   - 基于时间的过期策略
   - 基于事件的失效策略
   - 写入时更新缓存

### 7.3 响应式优化

1. **非阻塞I/O**：
   - 使用响应式MongoDB驱动
   - 使用WebClient进行非阻塞HTTP调用
   - 避免阻塞操作

2. **背压处理**：
   - 实现请求限流
   - 使用缓冲策略
   - 优化订阅者处理能力

3. **资源管理**：
   - 合理配置线程池
   - 监控和调整连接池
   - 实现超时和熔断机制

## 八、安全设计

### 8.1 认证与授权

1. **JWT认证**：
   - 基于JWT的无状态认证
   - 令牌过期和刷新机制
   - 安全的令牌存储

2. **角色基础授权**：
   - 基于角色的访问控制
   - 细粒度权限管理
   - API级别的权限检查

3. **OAuth2集成**：
   - 支持第三方登录
   - 授权码流程
   - 资源服务器保护

### 8.2 数据安全

1. **敏感数据加密**：
   - 密码哈希存储
   - 敏感信息加密
   - 传输层加密(TLS)

2. **输入验证**：
   - 请求参数验证
   - 防止注入攻击
   - 内容安全策略

3. **API安全**：
   - 请求限流
   - CORS配置
   - CSRF防护

### 8.3 审计与日志

1. **安全审计**：
   - 用户活动日志
   - 敏感操作记录
   - 异常行为检测

2. **日志管理**：
   - 结构化日志
   - 日志级别控制
   - 日志聚合和分析

## 九、监控与运维

### 9.1 监控指标

1. **系统指标**：
   - CPU和内存使用率
   - 线程数和连接数
   - 响应时间和吞吐量

2. **业务指标**：
   - API调用频率
   - 错误率和成功率
   - 用户活跃度

3. **AI相关指标**：
   - AI响应时间
   - Token消耗量
   - 缓存命中率

### 9.2 告警机制

1. **阈值告警**：
   - 基于指标阈值的告警
   - 趋势分析告警
   - 异常检测告警

2. **通知渠道**：
   - 邮件通知
   - 短信通知
   - 集成第三方通知服务

### 9.3 部署策略

1. **容器化部署**：
   - Docker容器封装
   - Kubernetes编排
   - 自动扩缩容

2. **CI/CD流程**：
   - 自动化构建
   - 自动化测试
   - 自动化部署

3. **环境管理**：
   - 开发环境
   - 测试环境
   - 生产环境

## 十、开发计划

### 10.1 边验证边开发策略

系统采用"边验证边开发"的方法论，通过构建可复用、可扩展的架构组件，快速形成MVP项目：

1. **增量式架构构建**：每个Sprint都交付可工作的产品增量
2. **垂直切片功能开发**：按照端到端的功能切片进行开发
3. **持续集成与部署**：频繁集成代码并部署到测试环境
4. **可复用组件设计**：设计高内聚、低耦合的组件
5. **基于证据的决策**：根据实际验证结果调整技术方案

### 10.2 Sprint计划

1. **Sprint 1**：核心架构与小说创建（2周）
2. **Sprint 2**：AI辅助写作与模型集成（2周）
3. **Sprint 3**：小说结构管理与内容编辑（2周）
4. **Sprint 4**：知识库与上下文感知（2周）
5. **Sprint 5**：角色管理与MVP完善（2周）

### 10.3 技术验证重点

1. **响应式架构与虚拟线程**：验证性能和资源利用率
2. **AI模型对接与对话**：验证响应质量和成本效益
3. **MongoDB知识库管理和检索**：验证检索性能和扩展性
4. **MongoDB单一数据库方案**：验证数据模型和查询性能

## 十一、风险管理

| 风险 | 可能性 | 影响 | 缓解策略 |
|------|--------|------|----------|
| 响应式编程复杂性 | 高 | 中 | 提供培训，创建示例代码，实施代码审查 |
| AI模型成本过高 | 中 | 高 | 实现缓存，优化提示，监控成本 |
| MongoDB向量搜索限制 | 高 | 高 | 早期验证，准备替代方案 |
| 虚拟线程不稳定 | 中 | 中 | 隔离使用，监控性能，准备回退方案 |
| 开发速度不及预期 | 中 | 高 | 优先级管理，增量交付，范围控制 |

## 十二、总结

AI小说助手系统后端采用现代化的响应式架构，结合JDK 21虚拟线程和MongoDB单一数据库方案，为小说创作提供全面的AI辅助功能。系统设计注重可扩展性、性能和用户体验，通过分层架构和抽象接口实现组件解耦和功能扩展。

系统将通过"边验证边开发"的方法论，在5个Sprint内构建MVP，同时验证关键技术假设。核心技术验证包括响应式架构与虚拟线程、AI模型集成、MongoDB知识库管理和检索性能。

通过合理的架构设计、性能优化策略和风险管理计划，系统将能够提供高性能、可扩展的小说创作平台，帮助作者更高效地完成创作过程。
