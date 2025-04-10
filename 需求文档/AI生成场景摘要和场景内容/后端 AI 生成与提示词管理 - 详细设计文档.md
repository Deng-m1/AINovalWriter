\# 后端 AI 功能（场景摘要互转）及提示词管理 \- 详细设计文档

\*\*版本:\*\* 1.0  
\*\*日期:\*\* 2025-04-07

\#\# 1\. 引言

\#\#\# 1.1 背景与目标  
本文档基于《后端 AI 功能（场景摘要互转）及提示词管理 \- 需求文档》(ID: \`backend\_ai\_features\_prd\`)，旨在为新增的 AI 生成功能（场景生成摘要、摘要生成场景）和用户提示词管理功能提供详细的技术设计方案。

\#\#\# 1.2 设计目标  
\* \*\*高并发 (High Concurrency):\*\* 系统能够高效处理大量并发用户的 AI 请求，特别是 I/O 密集型的 RAG 和 LLM 调用。  
\* \*\*高抽象 (High Abstraction):\*\* 各模块职责清晰，接口定义明确，易于理解和替换实现。  
\* \*\*高可用 (High Availability):\*\* 系统具备容错能力，对外部依赖（数据库、向量库、LLM API）的故障有弹性，保证核心服务的持续可用。  
\* \*\*易维护 (Maintainability):\*\* 代码结构清晰，遵循规范，易于调试、修改和理解。  
\* \*\*可扩展 (Extensibility):\*\* 方便未来增加新的 AI 功能点、集成新的 AI 模型或向量数据库。

\#\#\# 1.3 术语定义  
\* \*\*LLM:\*\* Large Language Model (大语言模型)  
\* \*\*RAG:\*\* Retrieval-Augmented Generation (检索增强生成)  
\* \*\*Prompt:\*\* 提示词  
\* \*\*Vector Store:\*\* 向量存储/数据库  
\* \*\*SSE:\*\* Server-Sent Events (服务器发送事件，用于流式响应)

\#\# 2\. 系统架构概览

新功能将融入现有的 \`AINovalServer\` Spring Boot (WebFlux) 应用中。核心交互流程如下：

\`\`\`mermaid  
sequenceDiagram  
    participant C as Client (Frontend)  
    participant GW as API Gateway / Controller  
    participant S\_NovelAI as NovelAIService  
    participant S\_Prompt as UserPromptService  
    participant S\_RAG as RagService  
    participant S\_AIConfig as UserAIConfigService  
    participant P\_AI as AIModelProvider  
    participant VDB as Vector Store Client  
    participant DB as MongoDB Client

    C-\>\>+GW: POST /api/ai/scenes/{id}/summarize (或 generate)  
    GW-\>\>+S\_NovelAI: summarizeScene(userId, sceneId, ...)  
    S\_NovelAI-\>\>+DB: 获取 Scene 内容  
    DB--\>\>-S\_NovelAI: Scene 对象  
    S\_NovelAI-\>\>+S\_RAG: retrieveRelevantContext(...)  
    S\_RAG-\>\>+VDB: 查询向量库  
    VDB--\>\>-S\_RAG: 相关文档块  
    S\_RAG-\>\>+DB: (可选)查询元数据/其他文本  
    DB--\>\>-S\_RAG: 补充信息  
    S\_RAG--\>\>-S\_NovelAI: 格式化后的 Context 字符串  
    S\_NovelAI-\>\>+S\_Prompt: getPrompt(userId, featureType)  
    S\_Prompt-\>\>+DB: 查询 UserPromptTemplate  
    alt 用户自定义 Prompt 存在  
        DB--\>\>S\_Prompt: 用户 Prompt  
    else 用户自定义 Prompt 不存在  
        DB--\>\>S\_Prompt: 未找到  
        S\_Prompt--\>\>S\_Prompt: 加载默认 Prompt (含缓存)  
    end  
    S\_Prompt--\>\>-S\_NovelAI: Prompt 模板  
    S\_NovelAI-\>\>S\_NovelAI: 构建最终 Prompt (模板+Context+Input)  
    S\_NovelAI-\>\>+S\_AIConfig: getDefaultConfig(userId)  
    S\_AIConfig-\>\>+DB: 查询 UserAIModelConfig  
    DB--\>\>-S\_AIConfig: AI 配置  
    S\_AIConfig--\>\>-S\_NovelAI: 用户默认 AI 配置  
    S\_NovelAI-\>\>+P\_AI: generate(finalPrompt, config) (或 generateStream)  
    P\_AI-\>\>P\_AI: (内部)调用外部 LLM API (带 Resilience)  
    P\_AI--\>\>-S\_NovelAI: 生成结果 (Mono\<String\> 或 Flux\<String\>)  
    S\_NovelAI--\>\>-GW: 结果 (Mono\<ResponseDTO\> 或 Flux\<ServerSentEvent\>)  
    GW--\>\>-C: 响应 (JSON 或 text/event-stream)

## **3\. 详细设计**

### **3.1 数据模型 (com.ainovel.server.domain.model)**

* **UserPromptTemplate** 实体:  
  * 定义如 PRD 3.1.1 所述。  
  * **MongoDB 索引:**  
    * { "userId": 1, "featureType": 1 } (唯一索引，确保用户对同一功能只有一个自定义 Prompt)  
    * { "userId": 1 } (可选，加速按用户查询)

### **3.2 提示词管理模块 (com.ainovel.server.service.prompt, com.ainovel.server.repository, com.ainovel.server.web.controller)**

**3.2.1 UserPromptTemplateRepository (Interface)**

* 继承 ReactiveMongoRepository\<UserPromptTemplate, String\>。  
* 定义查询方法: Mono\<UserPromptTemplate\> findByUserIdAndFeatureType(String userId, AIFeatureType featureType);  
* 定义删除方法: Mono\<Void\> deleteByUserIdAndFeatureType(String userId, AIFeatureType featureType);  
* 定义查询用户所有模板方法: Flux\<UserPromptTemplate\> findByUserId(String userId);

**3.2.2 UserPromptService (Interface)**

package com.ainovel.server.service.prompt;

import com.ainovel.server.domain.model.AIFeatureType;  
import reactor.core.publisher.Flux;  
import reactor.core.publisher.Mono;

public interface UserPromptService {  
    /\*\* 获取指定用户和功能的提示词模板 (优先用户自定义，否则返回默认) \*/  
    Mono\<String\> getPromptTemplate(String userId, AIFeatureType featureType);

    /\*\* 获取指定用户的所有自定义提示词 \*/  
    Flux\<UserPromptTemplate\> getUserCustomPrompts(String userId);

    /\*\* 保存或更新用户自定义提示词 \*/  
    Mono\<UserPromptTemplate\> saveOrUpdateUserPrompt(String userId, AIFeatureType featureType, String promptText);

    /\*\* 删除用户自定义提示词 (恢复默认) \*/  
    Mono\<Void\> deleteUserPrompt(String userId, AIFeatureType featureType);

    /\*\* (内部使用) 获取指定功能的默认提示词 \*/  
    Mono\<String\> getDefaultPromptTemplate(AIFeatureType featureType);  
}

**3.2.3 UserPromptServiceImpl (Implementation)**

* **依赖注入:** UserPromptTemplateRepository, @Value (用于注入默认提示词配置), CacheManager (或自定义 Cache)。  
* **默认提示词加载:**  
  * 在构造函数或 @PostConstruct 方法中从配置 (ainovel.ai.default-prompts) 加载默认提示词到 Map\<AIFeatureType, String\>。  
  * 实现 getDefaultPromptTemplate 方法，直接从 Map 返回。  
* **缓存:**  
  * 使用 Spring Cache (@Cacheable, @CachePut, @CacheEvict) 或 Caffeine 实现对 getPromptTemplate 结果的缓存。  
  * 缓存 Key: userId \+ ":" \+ featureType。  
  * saveOrUpdateUserPrompt 和 deleteUserPrompt 需要清除对应 Key 的缓存。  
  * 默认提示词可在加载后永久缓存。  
* **getPromptTemplate** 实现:  
  1. 调用 repository.findByUserIdAndFeatureType(userId, featureType)。  
  2. .map(UserPromptTemplate::getPromptText) 获取用户自定义文本。  
  3. .switchIfEmpty(getDefaultPromptTemplate(featureType)) 如果为空则获取默认模板。  
* **saveOrUpdateUserPrompt** 实现:  
  1. 调用 repository.findByUserIdAndFeatureType(userId, featureType)。  
  2. .flatMap(existing \-\> { ... update existing ...; return repository.save(existing); })  
  3. .switchIfEmpty(Mono.defer(() \-\> { ... create new ...; return repository.save(newTemplate); }))  
  4. 成功后清除缓存。  
* **deleteUserPrompt** 实现:  
  1. 调用 repository.deleteByUserIdAndFeatureType(userId, featureType)。  
  2. 成功后清除缓存。

**3.2.4 UserPromptController (Controller)**

* **路径:** /api/users/me/prompts  
* **依赖注入:** UserPromptService。  
* **认证:** 所有接口需要用户认证，使用 @AuthenticationPrincipal CurrentUser currentUser 获取用户信息。  
* **GET /**: 调用 service.getUserCustomPrompts(currentUser.getId())，映射到 UserPromptTemplateDto 返回 Flux\<UserPromptTemplateDto\>。  
* **GET /{featureType}**: 调用 service.getPromptTemplate(currentUser.getId(), featureType)，包装成 PromptTemplateDto 返回 Mono\<PromptTemplateDto\>。  
* **PUT /{featureType}**:  
  * 接收 Mono\<UpdatePromptRequest\> 请求体。  
  * 调用 service.saveOrUpdateUserPrompt(currentUser.getId(), featureType, request.getPromptText())。  
  * 映射结果到 PromptTemplateDto 返回 Mono\<PromptTemplateDto\>。  
* **DELETE /{featureType}**: 调用 service.deleteUserPrompt(currentUser.getId(), featureType)，返回 Mono\<Void\> (对应 204 No Content)。

**3.2.5 DTOs (com.ainovel.server.web.dto.prompt)**

* UserPromptTemplateDto { featureType: AIFeatureType, promptText: String }  
* PromptTemplateDto { featureType: AIFeatureType, promptText: String }  
* UpdatePromptRequest { @NotBlank promptText: String } (添加校验)

### **3.3 AI 生成核心模块 (com.ainovel.server.service.ai)**

**3.3.1 NovelAIService (Interface Enhancement)**

package com.ainovel.server.service;

// ... 其他方法 ...

import com.ainovel.server.web.dto.ai.\*; // 假设 DTO 在此包下  
import reactor.core.publisher.Flux;  
import reactor.core.publisher.Mono;

public interface NovelAIService {  
    // ... other methods ...

    /\*\* 为指定场景生成摘要 \*/  
    Mono\<SummarizeSceneResponse\> summarizeScene(String userId, String sceneId, SummarizeSceneRequest request);

    /\*\* 根据摘要生成场景内容 (流式) \*/  
    Flux\<String\> generateSceneFromSummaryStream(String userId, String novelId, GenerateSceneFromSummaryRequest request);

    /\*\* 根据摘要生成场景内容 (非流式，可选备用) \*/  
    Mono\<GenerateSceneFromSummaryResponse\> generateSceneFromSummary(String userId, String novelId, GenerateSceneFromSummaryRequest request);  
}

**3.3.2 NovelAIServiceImpl (Implementation Enhancement)**

* **依赖注入:** SceneService, NovelService, RagService (新), UserPromptService, UserAIModelConfigService, AIModelProviderFactory (或 Map\<String, AIModelProvider\>)。  
* **summarizeScene** 实现:  
  1. **权限与数据获取 (Reactive Chain):**  
     sceneService.getSceneById(sceneId)  
         .flatMap(scene \-\> {  
             // 权限校验: if (\!scene.getUserId().equals(userId)) return Mono.error(AccessDeniedException);  
             // 获取 NovelId  
             String novelId \= scene.getNovelId();  
             // 并行获取 RAG 上下文和 Prompt 模板  
             Mono\<String\> contextMono \= ragService.retrieveRelevantContext(novelId, sceneId, AIFeatureType.SCENE\_TO\_SUMMARY);  
             Mono\<String\> promptTemplateMono \= userPromptService.getPromptTemplate(userId, AIFeatureType.SCENE\_TO\_SUMMARY);  
             // 返回包含场景、上下文、模板的 Tuple  
             return Mono.zip(Mono.just(scene), contextMono, promptTemplateMono);  
         })  
         .flatMap(tuple \-\> {  
             Scene scene \= tuple.getT1();  
             String context \= tuple.getT2();  
             String promptTemplate \= tuple.getT3();  
             // 构建 Prompt  
             String finalPrompt \= buildFinalPrompt(promptTemplate, context, scene.getContent());  
             // 获取 AI 配置并调用 LLM  
             return userAIModelConfigService.getDefaultConfig(userId)  
                 .flatMap(aiConfig \-\> {  
                     AIModelProvider provider \= aiModelProviderFactory.getProvider(aiConfig.getProvider()); // 获取对应 Provider  
                     return provider.generate(finalPrompt, aiConfig.getModelParameters()); // 调用非流式 generate  
                 })  
                 .map(summary \-\> new SummarizeSceneResponse(summary)); // 封装结果  
         })  
         // 错误处理: .onErrorResume(...) 映射特定异常到 ErrorResponse  
         // 超时: .timeout(Duration.ofSeconds(config.getTimeout()))

  2. **buildFinalPrompt**: 内部方法，负责填充模板占位符。  
* **generateSceneFromSummaryStream** 实现 (流式):  
  1. **权限与数据获取 (类似 summarizeScene):** 获取 Novel 信息，并行获取 RAG 上下文和 Prompt 模板。  
  2. **构建 Prompt:** 结合 request.getSummary(), request.getStyleInstructions(), RAG context 和模板。  
  3. **获取 AI 配置:** userAIModelConfigService.getDefaultConfig(userId)。  
  4. **调用 LLM (流式):**  
     aiModelProviderFactory.getProvider(aiConfig.getProvider())  
         .generateStream(finalPrompt, aiConfig.getModelParameters()); // 调用流式 generateStream

  5. **返回 Flux\<String\>:** 直接返回 Provider 返回的文本流。  
  6. **错误处理:** 使用 onErrorResume 处理流中的错误。  
* **generateSceneFromSummary** 实现 (非流式, 可选):  
  * 调用 generateSceneFromSummaryStream(...)。  
  * 使用 .collect(Collectors.joining()) 将 Flux\<String\> 聚合成 Mono\<String\>。  
  * 封装到 GenerateSceneFromSummaryResponse 返回。

**3.3.3 AIModelProviderFactory (或类似机制)**

* 负责根据 AI 配置中的 provider 字符串（如 "gemini", "openai"）获取对应的 AIModelProvider Bean 实例。可以使用 Map\<String, AIModelProvider\> 注入所有 Provider，然后根据 key 获取。

### **3.4 RAG 模块 (com.ainovel.server.service.rag)**

**3.4.1 RagService (Interface \- 新建或整合入 NovelRagAssistant)**

package com.ainovel.server.service.rag;

import com.ainovel.server.domain.model.AIFeatureType;  
import reactor.core.publisher.Mono;

public interface RagService {  
    /\*\*  
     \* 根据小说、场景/章节/位置信息以及目标 AI 功能，检索相关上下文。  
     \* @param novelId 小说 ID  
     \* @param contextId 可选，如 sceneId  
     \* @param positionHint 可选，如章节 ID 或位置信息  
     \* @param featureType 目标 AI 功能类型  
     \* @return 格式化后的上下文文本 Mono\<String\>  
     \*/  
    Mono\<String\> retrieveRelevantContext(String novelId, String contextId, Object positionHint, AIFeatureType featureType);  
}

**3.4.2 RagServiceImpl (Implementation)**

* **依赖注入:** VectorStore, KnowledgeChunkRepository, NovelService, SceneService, MetadataService (如果需要)。  
* **retrieveRelevantContext** 实现:  
  1. **确定检索策略:** 根据 featureType 决定检索逻辑：  
     * SCENE\_TO\_SUMMARY:  
       * 检索查询: 可能是场景内容本身的部分关键信息或结合场景元数据。  
       * 检索目标: 小说设定、角色简介、章节概要。  
       * 可能需要从 NovelService 获取小说元信息。  
     * SUMMARY\_TO\_SCENE:  
       * 检索查询: 输入的 summary 或其 embedding。  
       * 检索目标: 小说设定、角色、风格示例、前后场景摘要/内容。  
       * 需要从 NovelService, SceneService 获取更多信息。  
  2. **执行向量检索:** 调用 vectorStore.search(...) 获取相似的 KnowledgeChunk。  
  3. **获取补充信息:** (可选) 根据检索到的 Chunk ID 或元数据，从 KnowledgeChunkRepository 或其他 Service 获取完整的文本或补充信息。  
  4. **格式化上下文:** 将检索到的信息、查询到的元数据等整合成一个适合 LLM 理解的文本字符串。  
  5. **错误处理:** 处理向量库查询失败、数据获取失败等情况，可以返回空字符串或默认上下文。

### **3.5 AI 模型 Provider 模块 (com.ainovel.server.service.ai)**

**3.5.1 AIModelProvider** (Interface **Enhancement)**

package com.ainovel.server.service.ai;

import reactor.core.publisher.Flux;  
import reactor.core.publisher.Mono;  
import java.util.Map; // For model parameters

public interface AIModelProvider {  
    /\*\* 获取 Provider 名称 (e.g., "gemini", "openai") \*/  
    String getProviderName();

    /\*\* 非流式生成 \*/  
    Mono\<String\> generate(String prompt, Map\<String, Object\> modelParameters);

    /\*\* 流式生成 \*/  
    Flux\<String\> generateStream(String prompt, Map\<String, Object\> modelParameters);

    /\*\* (可选) 验证 API Key 或配置 \*/  
    Mono\<Boolean\> validateConfig(Map\<String, Object\> config);

    /\*\* (可选) 获取支持的模型列表 \*/  
    Flux\<String\> listModels(Map\<String, Object\> config);  
}

**3.5.2 各 Provider 实现类 (e.g., GeminiLangChain4jModelProvider)**

* **实现 generateStream:** 使用对应的 Langchain4j StreamingChatLanguageModel 或 StreamingLanguageModel。  
* **Resilience:** 在调用外部 HTTP Client (由 Langchain4j 内部管理或自定义) 时应用 Resilience4j 配置（通过 WebClient Builder 或 AOP）。配置 Timeout, Retry, CircuitBreaker 策略。  
  * 配置应放在 application.yml 中，按 provider 或全局配置。  
* **错误映射:** 将特定于 Provider 的 API 异常映射为内部定义的通用 AI 异常（如 AIModelInvocationException）。

### **3.6 API 层 (com.ainovel.server.web.controller)**

**3.6.1 NovelAIController (或新 AIGenerationController)**

* **依赖注入:** NovelAIService。  
* **POST /api/ai/scenes/{sceneId}/summarize**:  
  * 调用 novelAIService.summarizeScene(...)。  
  * 返回 Mono\<SummarizeSceneResponse\>。  
* **POST /api/ai/novels/{novelId}/scenes/generate-from-summary**:  
  * 调用 novelAIService.generateSceneFromSummaryStream(...)。  
  * **返回类型:** Flux\<ServerSentEvent\<String\>\>。需要将 Flux\<String\> 转换为 SSE 格式。  
    @PostMapping(value \= "/novels/{novelId}/scenes/generate-from-summary", produces \= MediaType.TEXT\_EVENT\_STREAM\_VALUE)  
    public Flux\<ServerSentEvent\<String\>\> generateSceneStream(  
            @AuthenticationPrincipal CurrentUser currentUser,  
            @PathVariable String novelId,  
            @RequestBody Mono\<GenerateSceneFromSummaryRequest\> requestMono) {  
        return requestMono.flatMapMany(request \-\>  
                novelAIService.generateSceneFromSummaryStream(currentUser.getId(), novelId, request)  
                        .map(contentChunk \-\> ServerSentEvent.\<String\>builder()  
                                .event("message") // 事件类型  
                                .data(contentChunk) // 数据块  
                                .build())  
                        // 可选：发送心跳事件防止超时  
                        // .mergeWith(Flux.interval(Duration.ofSeconds(15)).map(i \-\> ServerSentEvent.\<String\>builder().comment("keepalive").build()))  
                        .onErrorResume(e \-\> { // 处理流中的错误，发送错误事件  
                            log.error("Error generating scene stream", e);  
                            return Flux.just(ServerSentEvent.\<String\>builder()  
                                    .event("error")  
                                    .data("{\\"error\\": \\"" \+ e.getMessage() \+ "\\"}") // 发送 JSON 错误信息  
                                    .build());  
                        })  
                        // 可选：发送完成事件  
                        .concatWith(Flux.just(ServerSentEvent.\<String\>builder().event("complete").data("").build()))  
        );  
    }

* **安全性:** 使用 @AuthenticationPrincipal 注入用户信息，并在 Service 层进行权限校验。

## **4\. 并发与异步策略**

* **核心框架:** 强制使用 **Spring WebFlux** 和 **Project Reactor** 处理所有涉及 I/O 的操作（HTTP 请求、数据库访问、向量库访问）。  
* **线程模型:** 优先使用 Reactor 的 Schedulers (boundedElastic 用于潜在阻塞调用，parallel 用于 CPU 密集型转换）。**避免**在 Reactive 流中直接使用 Thread.sleep() 或其他阻塞调用。如果必须集成阻塞库且无法包装，考虑 Mono.fromCallable(...).subscribeOn(Schedulers.boundedElastic())。**不优先推荐**显式使用 Virtual Threads，除非有特定场景证明其优于 Reactor Scheduler。  
* **资源池:** 配置合理的连接池大小 (MongoDB, WebClient/HttpClient for LLMs, Vector Store Client)。

## **5\. 高可用与弹性策略**

* **Resilience4j:**  
  * **Timeout:** 为所有外部 HTTP 调用（LLM API）和数据库/向量库调用配置超时 (@Timeout 注解或 WebClient 配置)。  
  * **Retry:** 为可能出现瞬时故障的操作（网络抖动、LLM API 临时不可用）配置重试 (@Retry 或 WebClient Filter)。仅重试幂等操作或可安全重试的操作。  
  * **Circuit Breaker:** 为关键外部依赖（尤其是 LLM API）配置断路器 (@CircuitBreaker)，防止雪崩效应。配置失败率阈值、慢调用阈值、半开状态等。  
* **配置:** Resilience 策略参数（超时时间、重试次数、断路器阈值）应在 application.yml 中配置，方便调整。  
* **健康检查:** 实现 /actuator/health 端点，并包含对 MongoDB、Vector Store (如果 Client 支持) 的健康检查。

## **6\. 数据库设计**

* **UserPromptTemplate** 索引: 见 3.1.1。

## **7\. 配置 (application.yml)**

ainovel:  
  ai:  
    default-prompts:  
      scene-to-summary: "..."  
      summary-to-scene: "..."  
    rag:  
      \# RAG 相关配置，如检索数量 k  
      retrieval-k: 5  
    \# Resilience 配置 (示例)  
    resilience:  
      timeout-

