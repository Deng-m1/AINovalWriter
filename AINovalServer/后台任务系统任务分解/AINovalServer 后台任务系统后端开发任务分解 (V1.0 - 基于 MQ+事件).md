# **AINovalServer 后台任务系统后端开发任务分解 (V1.0 \- 基于 MQ+事件)**

**目标:** 基于 V1.6 (MQ+事件深度扩展终版) 设计文档，实现一个高可靠、高可用、可扩展、事件驱动的后台任务系统。

**核心架构:** RabbitMQ \+ Spring AMQP \+ Spring Application Events \+ MongoDB

**开发流程与步骤分解:**

### **Phase 1: 核心框架与基础定义 (Foundation & Setup)**

* **任务 1.1: 定义核心模型与枚举**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.model 包。  
    2. 定义 TaskStatus 枚举 (包含 QUEUED, RUNNING, COMPLETED, FAILED, CANCELLED, RETRYING, DEAD\_LETTER, COMPLETED\_WITH\_ERRORS)。  
    3. 定义 BackgroundTask 实体类，包含 V1.6 文档中指定的所有字段（id, userId, taskType, status, parameters (Object), progress (Object), result (Object), errorInfo, timestamps, retryCount, lastAttemptTimestamp, nextAttemptTimestamp, executionNodeId, parentTaskId, subTaskStatusSummary）。  
    4. 使用 @Document(collection \= "background\_tasks") 注解。  
    5. 添加 @Version 字段以支持乐观锁（如果选择该策略）。  
  * **产出:** TaskStatus.java, BackgroundTask.java。  
* **任务 1.2: 定义核心接口**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task 包。  
    2. 定义泛型接口 BackgroundTaskExecutable\<P, R\>，包含 execute, getTaskType, getParameterType, getResultType 及可选方法。  
    3. 定义泛型接口 TaskContext\<P\>，包含获取上下文信息和回调方法（updateProgress, logInfo, logError, submitSubTask）。  
  * **产出:** BackgroundTaskExecutable.java, TaskContext.java。  
* **任务 1.3: 定义基础 DTO 与事件类**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.dto 包，并按任务类型分子包。  
    2. 为初始的 V1 范围任务 (GenerateSummary, GenerateScene) 定义具体的 XxxParameters, XxxResult DTO 类。  
    3. 创建 com.ainovel.server.task.event.internal 包。  
    4. 定义基础的 Spring Application Event 类（TaskSubmittedEvent, TaskStartedEvent, TaskCompletedApplicationEvent, TaskFailedApplicationEvent, TaskRetryingApplicationEvent, TaskProgressApplicationEvent），继承 ApplicationEvent 并包含必要字段。  
    5. (可选) 创建 com.ainovel.server.task.event.external 包并定义 TaskExternalEvent DTO。  
  * **产出:** 初始任务的 DTO 类，内部事件类，(可选) 外部事件 DTO。  
* **任务 1.4: 配置序列化 (Jackson / Mongo Converter)**  
  * **步骤:**  
    1. 确保 Spring Boot 的 ObjectMapper Bean 配置能正确处理 Instant 类型、可选类型等。  
    2. 配置 MongoDB 的 Type Mapping 或自定义 Converter，以确保 BackgroundTask 中的 parameters, progress, result (Object 类型) 能正确序列化/反序列化为对应的 DTO 或 Map\<String, Object\>。  
  * **产出:** Jackson/Mongo Converter 配置。

### **Phase 2: 持久化层实现 (Persistence Layer Implementation)**

* **任务 2.1: 实现 MongoDB Repository**  
  * **步骤:**  
    1. 创建 com.ainovel.server.repository.BackgroundTaskRepository 接口，继承 MongoRepository 或 ReactiveMongoRepository。  
    2. 定义所需的查询方法（如 findById, findByUserId, findByParentTaskId）。  
    3. (如果不用乐观锁) 可能需要定义自定义 Repository 接口和实现，以包含使用 MongoTemplate 执行 findAndModify 的原子更新方法。  
  * **产出:** BackgroundTaskRepository.java (及可能的实现类)。  
* **任务 2.2: 实现状态数据库服务 (TaskStateService)**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.service.TaskStateService 接口及其实现类。  
    2. 注入 BackgroundTaskRepository, ObjectMapper。  
    3. 实现 V1.6 文档中定义的原子性状态管理方法 (createTask, trySetRunning, recordProgress, recordCompletion, recordFailure 等)，内部调用 Repository 并处理乐观锁或 findAndModify 逻辑。  
  * **产出:** TaskStateService.java 及其实现。

### **Phase 3: MQ 基础设施与配置 (MQ Infrastructure & Configuration)**

* **任务 3.1: 添加 Spring AMQP 依赖**  
  * **步骤:** 在 pom.xml 或 build.gradle 中添加 spring-boot-starter-amqp 依赖。  
* **任务 3.2: 配置 RabbitMQ 连接**  
  * **步骤:** 在 application.yml 中配置 spring.rabbitmq.\* 连接属性。  
* **任务 3.3: 声明 RabbitMQ 拓扑结构 (代码化)**  
  * **步骤:**  
    1. 创建 com.ainovel.server.config.RabbitMQConfig 类，注解 @Configuration。  
    2. 使用 Queue, DirectExchange, TopicExchange, FanoutExchange, Binding Bean 定义 V1.6 文档中描述的所有 Exchanges, Queues (含 TTL, DLX 参数), 和 Bindings。  
    3. 注入 RabbitAdmin 以确保拓扑结构在应用启动时被创建或更新。  
  * **产出:** RabbitMQConfig.java。  
* **任务 3.4: 配置 RabbitTemplate Bean**  
  * **步骤:**  
    1. 在 RabbitMQConfig 或单独的配置类中创建 RabbitTemplate Bean。  
    2. 配置 Jackson2JsonMessageConverter。  
    3. 配置 setConfirmCallback 和 setReturnsCallback，并实现相应的处理逻辑（至少要记录日志）。  
    4. 设置 mandatory=true (配合 Return Callback)。  
    5. 设置默认 deliveryMode 为 PERSISTENT。  
  * **产出:** RabbitTemplate Bean 配置。  
* **任务 3.5: 配置 RabbitListener Container Factory Bean**  
  * **步骤:**  
    1. 在 RabbitMQConfig 或单独配置类中创建 SimpleRabbitListenerContainerFactory Bean。  
    2. 设置 acknowledgeMode \= AcknowledgeMode.MANUAL。  
    3. 设置 messageConverter。  
    4. 配置 concurrency, maxConcurrency, prefetchCount。  
    5. (推荐) 配置使用虚拟线程的 taskExecutor。  
    6. (可选) 配置 ErrorHandler。  
  * **产出:** SimpleRabbitListenerContainerFactory Bean 配置。  
* **任务 3.6: (如果使用 Delayed Plugin) 添加插件依赖并配置**  
  * **步骤:** 添加 rabbitmq-delayed-message-exchange 相关依赖，并在声明 Exchange 时使用 ExchangeBuilder.delayed()。

### **Phase 4: 任务生产者实现 (Task Producer Implementation)**

* **任务 4.1: 实现 TaskMessageProducer**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.producer.TaskMessageProducer 类，注解 @Service 或 @Component。  
    2. 注入配置好的 RabbitTemplate。  
    3. 实现 sendTask(taskId, userId, taskType, paramsDTO) 方法，包含序列化、设置消息头 (messageId, correlationId 等)、调用 rabbitTemplate.convertAndSend 的逻辑。  
    4. 实现 ConfirmCallback 和 ReturnsCallback 的处理逻辑（记录日志，可能触发失败事件）。  
  * **产出:** TaskMessageProducer.java。  
* **任务 4.2: 实现 TaskSubmissionService**  
  * **步骤:**  
    1. 创建 com.ainovel.server.service.impl.TaskSubmissionServiceImpl (或集成到现有业务 Service)。  
    2. 注入 TaskStateService, ApplicationEventPublisher。  
    3. 实现 submitTask 方法，包含调用 TaskStateService.createTask 和发布 TaskSubmittedEvent 的逻辑，并使用 @Transactional。  
  * **产出:** TaskSubmissionService 实现。  
* **任务 4.3: (可选) 实现 TaskSubmittedEvent 监听器**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.listener.TaskSubmissionListener。  
    2. 注解 @Component, @EventListener。  
    3. 注入 TaskMessageProducer。  
    4. 实现 onTaskSubmitted(TaskSubmittedEvent event) 方法，调用 TaskMessageProducer.sendTask。  
  * **产出:** TaskSubmissionListener.java。

### **Phase 5: 任务消费者与执行器核心实现 (Consumer & Executor Core Implementation)**

* **任务 5.1: 实现 TaskExecutorService**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.service.TaskExecutorService 接口及实现。  
    2. 注入 List\<BackgroundTaskExecutable\<?, ?\>\>，并在构造函数或 @PostConstruct 中构建 Map\<String, BackgroundTaskExecutable\<?, ?\>\>。  
    3. 实现 findExecutor(taskType)。  
    4. 实现 executeTask(executable, context) 方法，包含调用 executable.execute() 和**异常分类**逻辑，返回包含结果或分类后异常的 ExecutionResult。  
  * **产出:** TaskExecutorService.java 及其实现。  
* **任务 5.2: 实现 TaskConsumer 骨架**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.consumer.TaskConsumer 类，注解 @Component。  
    2. 创建 @RabbitListener 方法 handleTaskMessage(Message message, Channel channel)。  
    3. 注入 TaskExecutorService, ApplicationEventPublisher, ObjectMapper, RabbitTemplate (用于重试/死信)。  
    4. 实现方法骨架：获取 deliveryTag, try-catch-finally, 解析消息头和消息体，调用 findExecutor。  
  * **产出:** TaskConsumer.java (骨架)。  
* **任务 5.3: 实现消费者幂等性检查**  
  * **步骤:** 在 handleTaskMessage 方法开始处，调用 TaskStateService.trySetRunning(taskId)，如果返回 false，则 ACK 并 return。  
  * **集成:** 将此逻辑加入 TaskConsumer。

### **Phase 6: 事件处理机制实现 (Event Handling Implementation)**

* **任务 6.1: 在 Consumer 和 Service 中发布 Spring Events**  
  * **步骤:**  
    1. 在 TaskConsumer 的 handleTaskMessage 方法中，根据执行流程在恰当位置注入 ApplicationEventPublisher 并调用 publishEvent 发布 TaskStartedEvent, TaskCompletedEvent, TaskFailedEvent, TaskRetryingEvent。  
    2. 在 BackgroundTaskExecutable 实现中，通过 TaskContext 调用 updateProgress，在 TaskContext 实现中发布 TaskProgressApplicationEvent。  
    3. 在 TaskSubmissionService 中发布 TaskSubmittedEvent。  
  * **集成:** 修改相关组件以包含事件发布逻辑。  
* **任务 6.2: 实现 StateAggregatorService**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.listener.StateAggregatorService。  
    2. 注解 @Service, (可选 @Async 处理方法)。  
    3. 注入 TaskStateService。  
    4. 创建多个 @EventListener 方法，分别监听不同的内部任务事件。  
    5. 在每个监听方法中，实现幂等性检查（推荐基于 Event ID）。  
    6. 调用 TaskStateService 的原子更新方法更新 MongoDB 状态。  
    7. 实现子任务状态聚合逻辑（如果采用子任务模型）。  
  * **产出:** StateAggregatorService.java。  
* **任务 6.3: 实现 ExternalEventBridge**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.listener.ExternalEventBridge。  
    2. 注解 @Component, @EventListener (监听需要外部广播的内部事件)。  
    3. 注入 TaskEventPublisher。  
    4. 实现事件转换逻辑（内部 Event \-\> 外部 DTO）。  
    5. 调用 TaskEventPublisher.publishExternalEvent。  
  * **产出:** ExternalEventBridge.java。  
* **任务 6.4: 实现 ExternalEventPublisher**  
  * **步骤:**  
    1. 创建 com.ainovel.server.task.producer.TaskEventPublisher。  
    2. 注解 @Service。  
    3. 注入 RabbitTemplate, ObjectMapper。  
    4. 实现 publishExternalEvent 方法，发送消息到 tasks.events.exchange。  
  * **产出:** TaskEventPublisher.java。

### **Phase 7: 重试与死信逻辑实现 (Retry & Dead Letter Implementation)**

* **任务 7.1: 在 TaskConsumer 中完善失败处理和重试判断**  
  * **步骤:** 根据 TaskExecutorService.executeTask 返回的 ExecutionResult 中的异常类型，结合 retryCount 和 maxAttempts 配置，判断是可重试、不可重试还是达到上限。  
  * **集成:** 完善 TaskConsumer.handleTaskMessage 中的 catch 和结果处理逻辑。  
* **任务 7.2: 实现重试路由/发布逻辑 (推荐 Delayed Plugin)**  
  * **步骤:**  
    1. 在 TaskConsumer 处理可重试失败且未达上限时：  
    2. 计算延迟 delayMillis。  
    3. 构造带有 x-delay 和递增后 x-retry-count 头的新消息属性。  
    4. 调用 rabbitTemplate.convertAndSend 将消息重新发布回 tasks.exchange。  
    5. ACK 原消息。  
  * **集成:** 将此逻辑加入 TaskConsumer。  
* **任务 7.3: 实现死信 NACK 逻辑**  
  * **步骤:** 在 TaskConsumer 处理不可重试失败或达到重试上限时，调用 channel.basicNack(deliveryTag, false, false)。  
  * **集成:** 将此逻辑加入 TaskConsumer。  
* **任务 7.4: 实现死信处理 API**  
  * **步骤:**  
    1. 创建 DeadLetterController。  
    2. 实现查询 tasks.dlq.queue 消息的 API (可能需要 RabbitMQ Management API 或自定义消费者读取)。  
    3. 实现手动将 DLQ 消息重新发布到 tasks.exchange 的 API。  
  * **产出:** DeadLetterController.java 及相关服务。

### **Phase 8: 具体业务任务实现 (Specific Task Implementation)**

* **任务 8.1: 实现 GenerateSummaryTask**  
  * **步骤:**  
    1. 定义 GenerateSummaryParameters, GenerateSummaryResult DTO。  
    2. 创建 GenerateSummaryTaskExecutable 实现 BackgroundTaskExecutable\<GenerateSummaryParameters, GenerateSummaryResult\>。  
    3. 注入 AIService, RateLimiterService。  
    4. 实现 execute 方法：调用限流，调用 AIService.generateSummary，处理异常分类。  
  * **产出:** 相关 DTO 和 Executable 类。  
* **任务 8.2: 实现 GenerateSceneTask**  
  * **步骤:** 类似任务 8.1。  
  * **产出:** 相关 DTO 和 Executable 类。  
* **任务 8.3: 实现 BatchGenerateSummaryTask (采用子任务模型)**  
  * **步骤:**  
    1. 定义 BatchGenerateSummaryParameters (含 sceneIds), BatchGenerateSummaryResult (可能为空或摘要信息), BatchGenerateSummaryProgress (含 total, success, failed 计数)。  
    2. 创建 BatchGenerateSummaryTaskExecutable。  
    3. 实现 execute 方法：循环 sceneIds，为每个 ID 构造 GenerateSummaryParameters，调用 context.submitSubTask("GenerateSummaryTask", ...)。  
    4. (状态聚合由 StateAggregatorService 处理)。  
  * **产出:** 相关 DTO 和 Executable 类。  
* **任务 8.4: 实现 BatchGenerateSceneTask (采用子任务模型)**  
  * **步骤:** 类似任务 8.3。  
  * **产出:** 相关 DTO 和 Executable 类。  
* **任务 8.5: (未来) 设计和实现 ImportNovelTask**  
  * **步骤:** 分析导入流程，可能分解为 ParseFile, GenerateSummaries (批量), Vectorize 等子任务，设计相应的 Executable 和 DTO。

### **Phase 9: 支持性组件与高可用性 (Supporting Components & High Availability)**

* **任务 9.1: 实现 RateLimiterService**  
  * **步骤:** 选择内存或分布式实现，提供 acquirePermit 方法。  
  * **产出:** RateLimiterService.java。  
* **任务 9.2: 集成 RateLimiterService**  
  * **步骤:** 在需要调用外部受限 API 的 BackgroundTaskExecutable 实现中注入并调用 RateLimiterService。  
* **任务 9.3: 配置日志记录 (MDC, 格式)**  
  * **步骤:** 配置 Logback/Log4j2，设置 MDC，定义包含追踪信息的日志格式。  
* **任务 9.4: 配置监控指标 (Micrometer)**  
  * **步骤:** 添加 Actuator 依赖，配置 Micrometer，(可选) 在代码中手动注册自定义指标。  
* **任务 9.5: 实现优雅停机逻辑**  
  * **步骤:** 实现 ContextClosedEvent 监听器，调用 RabbitListenerEndpointRegistry.stop() 并添加等待逻辑。

### **Phase 10: 集成、测试与文档 (Integration, Testing & Documentation)**

* **任务 10.1: 编写单元测试**  
  * **步骤:** 为 Service, Producer, Consumer (Mock MQ), Listener, Executable 编写 JUnit 测试。  
* **任务 10.2: 编写集成测试 (Testcontainers)**  
  * **步骤:** 创建集成测试类，使用 Testcontainers 启动 RabbitMQ 和 MongoDB，覆盖 V1.6 文档中描述的核心流程和边界场景。  
* **任务 10.3: 编写/更新架构文档**  
  * **步骤:** 维护本文档 (V1.6)，确保其准确反映最终实现。包含 MQ 拓扑图。  
* **任务 10.4: 编写/更新开发者指南**  
  * **步骤:** 提供添加新任务的详细步骤和本地开发环境设置说明。  
* **任务 10.5: 编写/更新 API 文档**  
  * **步骤:** 使用 OpenAPI/Swagger 注解 Controller，生成 API 文档。

**建议执行顺序:** 严格按照 Phase 1 到 Phase 10 的顺序执行，其中 Phase 8 可以根据业务优先级并行实现不同的任务类型，Phase 9 的各项可以在核心流程稳定后逐步加入，Phase 10 的测试和文档应贯穿始终。