\# 后端 AI 功能（场景摘要互转）及提示词管理 \- 需求文档

\#\# 1\. 项目背景与目标

\*\*背景:\*\* AINovalWriter 项目旨在利用 AI 提升小说创作效率。当前已具备基础编辑、AI 聊天、用户及 AI 配置管理等功能。  
\*\*目标:\*\* 本次迭代旨在增强 AI 辅助创作能力，新增以下核心功能：  
    1\.  \*\*场景内容 AI 生成摘要:\*\* 根据用户选定的场景内容，自动生成简洁的摘要。  
    2\.  \*\*摘要内容 AI 生成场景:\*\* 根据用户提供的摘要或大纲要点，自动生成相应的场景内容草稿。  
    3\.  \*\*用户级提示词管理:\*\* 允许用户为不同的 AI 功能点自定义 Prompt，提高生成内容的可控性和个性化程度。

\*\*核心价值:\*\*  
\* 提高创作效率：快速生成摘要便于回顾，快速生成场景草稿减少从零开始的负担。  
\* 提升内容质量：利用 RAG 结合上下文，生成更贴合小说背景的摘要和场景。  
\* 增强用户控制：允许用户通过自定义 Prompt 微调 AI 的生成风格和侧重点。

\#\# 2\. 功能范围

本次迭代主要涉及后端 (\`AINovalServer\`) 的以下功能点：

\* \*\*用户提示词模板管理:\*\*  
    \* 数据模型设计与存储。  
    \* 提供 CRUD API 用于前端管理用户自定义提示词。  
    \* 提供默认提示词机制。  
\* \*\*场景生成摘要服务:\*\*  
    \* API 接口定义。  
    \* 集成 RAG 获取上下文。  
    \* 结合用户/默认提示词调用 LLM 生成摘要。  
\* \*\*摘要生成场景服务:\*\*  
    \* API 接口定义。  
    \* 集成 RAG 获取上下文。  
    \* 结合用户/默认提示词调用 LLM 生成场景内容。  
\* \*\*服务层逻辑编排:\*\*  
    \* 整合现有服务（用户、AI 配置、向量库、LLM Provider）实现新功能。

\#\# 3\. 详细需求

\#\#\# 3.1 用户提示词模板管理 (User Prompt Template Management)

\*\*3.1.1 数据模型\*\*

\* \*\*新增实体:\*\* \`UserPromptTemplate\`  
    \* \`id\`: String (唯一标识符)  
    \* \`userId\`: String (关联 \`User\` 实体的 ID)  
    \* \`novelId\`: String (可选，未来可支持小说级别的 Prompt) \- \*\*初期可不实现\*\*  
    \* \`featureType\`: Enum (标识该 Prompt 应用的功能点，如 \`SCENE\_TO\_SUMMARY\`, \`SUMMARY\_TO\_SCENE\`)  
    \* \`promptText\`: String (用户自定义的提示词模板内容，可包含占位符如 \`{context}\`, \`{input}\`)  
    \* \`createdAt\`: Instant  
    \* \`updatedAt\`: Instant  
\* \*\*存储:\*\* 使用 MongoDB，创建 \`UserPromptTemplateRepository\`。  
\* \*\*FeatureType Enum 定义:\*\*  
    \`\`\`java  
    public enum AIFeatureType {  
        SCENE\_TO\_SUMMARY, // 场景生成摘要  
        SUMMARY\_TO\_SCENE, // 摘要生成场景  
        // 未来可扩展其他功能点，如角色生成、大纲优化等  
    }  
    \`\`\`

\*\*3.1.2 默认提示词\*\*

\* \*\*存储:\*\* 在 \`application.yml\` 或独立的资源文件 (e.g., \`prompts/default-prompts.yml\`) 中定义各 \`AIFeatureType\` 的默认提示词模板。  
    \* 示例 (\`application.yml\`):  
        \`\`\`yaml  
        ainovel:  
          ai:  
            default-prompts:  
              scene-to-summary: "请根据以下小说场景内容，生成一段简洁的摘要。\\n场景内容:\\n{input}\\n参考信息:\\n{context}"  
              summary-to-scene: "请根据以下摘要/大纲，结合参考信息，生成一段详细的小说场景。\\n摘要/大纲:\\n{input}\\n参考信息:\\n{context}"  
        \`\`\`  
\* \*\*加载:\*\* 由 \`PromptService\` 或新增的 \`UserPromptService\` 负责加载和提供默认提示词。

\*\*3.1.3 Service 层 (\`PromptService\` 或 \`UserPromptService\`)\*\*

\* \*\*\`getPrompt(userId, featureType)\`:\*\*  
    \* 根据 \`userId\` 和 \`featureType\` 查询 \`UserPromptTemplate\`。  
    \* 如果找到用户自定义 Prompt，返回其 \`promptText\`。  
    \* 如果未找到，加载并返回对应 \`featureType\` 的默认 \`promptText\`。  
    \* 需要处理 \`userId\` 为 null 或 \`featureType\` 无效的情况。  
\* \*\*\`saveOrUpdatePrompt(userId, featureType, promptText)\`:\*\*  
    \* 根据 \`userId\` 和 \`featureType\` 查找记录。  
    \* 如果存在，更新 \`promptText\` 和 \`updatedAt\`。  
    \* 如果不存在，创建新的 \`UserPromptTemplate\` 记录。  
\* \*\*\`deletePrompt(userId, featureType)\`:\*\*  
    \* 根据 \`userId\` 和 \`featureType\` 删除对应的 \`UserPromptTemplate\` 记录。

\*\*3.1.4 API 接口 (\`UserPromptController\` 或扩展 \`UserController\`)\*\*

\* \*\*\`GET /api/users/me/prompts\`\*\*: 获取当前登录用户的所有自定义提示词。  
    \* 响应: \`List\<UserPromptTemplateDto\>\`  
\* \*\*\`GET /api/users/me/prompts/{featureType}\`\*\*: 获取当前登录用户指定功能的提示词（如果自定义了则返回自定义，否则返回默认）。  
    \* 路径参数: \`featureType\` (Enum: \`SCENE\_TO\_SUMMARY\`, \`SUMMARY\_TO\_SCENE\`)  
    \* 响应: \`PromptTemplateDto { featureType, promptText }\`  
\* \*\*\`PUT /api/users/me/prompts/{featureType}\`\*\*: 创建或更新当前登录用户指定功能的自定义提示词。  
    \* 路径参数: \`featureType\`  
    \* 请求体: \`UpdatePromptRequest { promptText: String }\`  
    \* 响应: \`PromptTemplateDto\` (更新后的)  
\* \*\*\`DELETE /api/users/me/prompts/{featureType}\`\*\*: 删除当前登录用户指定功能的自定义提示词（恢复为默认）。  
    \* 路径参数: \`featureType\`  
    \* 响应: \`204 No Content\`

\*\*3.1.5 DTOs\*\*

\* \`UserPromptTemplateDto\`: 包含 \`featureType\` 和 \`promptText\`。  
\* \`UpdatePromptRequest\`: 包含 \`promptText\`。

\#\#\# 3.2 场景生成摘要 (Scene-to-Summary)

\*\*3.2.1 API 接口 (\`NovelAIController\` 或新 Controller)\*\*

\* \*\*\`POST /api/ai/scenes/{sceneId}/summarize\`\*\*  
    \* 路径参数: \`sceneId\` (需要生成摘要的场景 ID)  
    \* 请求体: \`SummarizeSceneRequest\` (可选，可包含如 \`maxLength\`, \`style\` 等参数) \- \*\*初期可为空\*\*  
    \* 响应: \`SummarizeSceneResponse { summary: String }\` (包含生成的摘要文本)  
    \* \*\*权限:\*\* 需要用户登录，且对该 \`sceneId\` 有读取权限。

\*\*3.2.2 DTOs\*\*

\* \`SummarizeSceneRequest\`: (初期可为空)  
\* \`SummarizeSceneResponse\`: \`{ summary: String }\`

\*\*3.2.3 Service 层 (\`NovelAIServiceImpl\`)\*\*

\* \*\*\`summarizeScene(userId, sceneId, request)\`:\*\*  
    1\.  \*\*获取场景内容:\*\* 调用 \`SceneService.getSceneById(sceneId)\` 获取场景 \`Scene\` 对象及其内容 \`content\`。验证 \`userId\` 权限。  
    2\.  \*\*获取上下文 (RAG):\*\*  
        \* 调用 \`NovelRagAssistant.retrieveRelevantContext(novelId, sceneId, "SUMMARIZATION")\` (需要扩展 \`NovelRagAssistant\`)。  
        \* 上下文可能包括：小说基础设定、主要角色简介、当前章节梗概、该场景在章节中的位置等。具体内容需进一步设计和实验。  
        \* \*注意:\* RAG 检索需要考虑性能和成本。  
    3\.  \*\*获取提示词模板:\*\* 调用 \`PromptService.getPrompt(userId, AIFeatureType.SCENE\_TO\_SUMMARY)\` 获取用户或默认的 Prompt 模板。  
    4\.  \*\*构建最终 Prompt:\*\*  
        \* 将获取到的上下文 \`context\` 和场景内容 \`content\` 填入提示词模板的占位符（如 \`{context}\`, \`{input}\`）。  
        \* 可加入系统指令，如 "你是一个专业的小说编辑..."。  
    5\.  \*\*获取用户 AI 配置:\*\* 调用 \`UserAIModelConfigService.getDefaultConfig(userId)\` 获取用户默认的 AI 模型配置。  
    6\.  \*\*调用 LLM:\*\*  
        \* 根据 AI 配置选择对应的 \`AIModelProvider\` (如 \`GeminiLangChain4jModelProvider\`)。  
        \* 调用 \`aiModelProvider.generate(finalPrompt, modelParameters)\`。  
        \* 处理可能的流式响应（如果模型支持且需要）。\*\*初期可先实现非流式。\*\*  
    7\.  \*\*处理并返回结果:\*\*  
        \* 从 LLM 响应中提取生成的摘要文本。  
        \* 进行必要的后处理（如去除多余空格）。  
        \* 封装到 \`SummarizeSceneResponse\` 中返回。  
    8\.  \*\*错误处理:\*\* 捕获并处理场景不存在、无权限、RAG 失败、Prompt 获取失败、AI 模型调用失败等异常，返回标准错误响应。

\#\#\# 3.3 摘要生成场景 (Summary-to-Scene)

\*\*3.3.1 API 接口 (\`NovelAIController\` 或新 Controller)\*\*

\* \*\*\`POST /api/ai/novels/{novelId}/scenes/generate-from-summary\`\*\*  
    \* 路径参数: \`novelId\` (场景所属的小说 ID)  
    \* 请求体: \`GenerateSceneFromSummaryRequest { summary: String; chapterId?: String; position?: Integer; styleInstructions?: String }\`  
        \* \`summary\`: 用于生成场景的摘要或大纲。  
        \* \`chapterId\` (可选): 场景计划归属的章节 ID。  
        \* \`position\` (可选): 场景在章节或小说中的大致位置（用于 RAG 参考）。  
        \* \`styleInstructions\` (可选): 用户附加的风格指令。  
    \* 响应: \`GenerateSceneFromSummaryResponse { generatedContent: String }\` (包含生成的场景内容文本)  
    \* \*\*权限:\*\* 需要用户登录，且对该 \`novelId\` 有写入权限。

\*\*3.3.2 DTOs\*\*

\* \`GenerateSceneFromSummaryRequest\`: \`{ summary: String; chapterId?: String; position?: Integer; styleInstructions?: String }\`  
\* \`GenerateSceneFromSummaryResponse\`: \`{ generatedContent: String }\`

\*\*3.3.3 Service 层 (\`NovelAIServiceImpl\`)\*\*

\* \*\*\`generateSceneFromSummary(userId, novelId, request)\`:\*\*  
    1\.  \*\*获取小说信息:\*\* 调用 \`NovelService.getNovelById(novelId)\`。验证 \`userId\` 权限。  
    2\.  \*\*获取上下文 (RAG):\*\*  
        \* 调用 \`NovelRagAssistant.retrieveRelevantContext(novelId, request.chapterId, request.position, "SCENE\_GENERATION")\` (需要扩展 \`NovelRagAssistant\`)。  
        \* 上下文应尽可能丰富：小说类型、风格、核心设定、主要人物列表及简介、目标章节（如果提供 \`chapterId\`）的上下文、前后场景的摘要或内容片段等。  
    3\.  \*\*获取提示词模板:\*\* 调用 \`PromptService.getPrompt(userId, AIFeatureType.SUMMARY\_TO\_SCENE)\`。  
    4\.  \*\*构建最终 Prompt:\*\*  
        \* 将获取到的上下文 \`context\` 和请求中的 \`summary\` 及 \`styleInstructions\` 填入提示词模板占位符。  
        \* 可加入系统指令，如 "你是一个富有创意的小说家..."。  
    5\.  \*\*获取用户 AI 配置:\*\* 调用 \`UserAIModelConfigService.getDefaultConfig(userId)\`。  
    6\.  \*\*调用 LLM:\*\*  
        \* 选择 \`AIModelProvider\`。  
        \* 调用 \`aiModelProvider.generate(finalPrompt, modelParameters)\`。  
        \* \*\*考虑流式响应:\*\* 生成场景内容可能较长，建议优先考虑实现流式响应 (\`Flux\<String\>\`) 以提升前端体验。API 接口也需相应调整。  
    7\.  \*\*处理并返回结果:\*\*  
        \* 拼接流式响应（如果使用流式）或直接获取完整响应。  
        \* 进行后处理。  
        \* 封装到 \`GenerateSceneFromSummaryResponse\` 中返回。  
    8\.  \*\*错误处理:\*\* 同 3.2.3.8。

\#\# 4\. 非功能性需求

\* \*\*性能:\*\* RAG 检索和 LLM 调用应在合理时间内完成。对于长内容生成，应优先考虑流式响应。  
\* \*\*可扩展性:\*\* 提示词管理和 AI 功能点应易于扩展，方便未来增加新的 AI 辅助功能。  
\* \*\*错误处理:\*\* 提供清晰的错误信息给前端。  
\* \*\*安全性:\*\* 所有 API 必须经过身份验证和授权检查。

\#\# 5\. 依赖与影响

\* \*\*前端:\*\* 需要前端开发配合实现用户设置界面（管理 Prompt）、触发 AI 功能的按钮/菜单，以及展示生成结果的侧边编辑区。  
\* \*\*后端:\*\*  
    \* 需要修改或新增 Controller, Service, Repository, DTO, Entity。  
    \* 可能需要扩展 \`NovelRagAssistant\` 以支持更精细化的上下文检索。  
    \* 需要定义和加载默认提示词。  
    \* 需要确保 \`UserAIModelConfig\` 功能完善可用。

\#\# 6\. 里程碑与计划 (初步)

\* \*\*Sprint 1:\*\*  
    \* 完成 \`UserPromptTemplate\` 数据模型设计与 Repository 实现。  
    \* 实现 \`PromptService\` 的基础功能（加载默认、获取/保存/删除用户 Prompt）。  
    \* 完成用户提示词管理的 API 接口及 DTO 定义。  
    \* 完成场景生成摘要功能的 Service 层骨架和 API 定义。  
\* \*\*Sprint 2:\*\*  
    \* 实现场景生成摘要功能的 RAG 上下文获取逻辑。  
    \* 实现场景生成摘要功能的 Prompt 构建和 LLM 调用逻辑。  
    \* 完成场景生成摘要功能的端到端测试。  
    \* 完成摘要生成场景功能的 Service 层骨架和 API 定义（含流式响应考虑）。  
\* \*\*Sprint 3:\*\*  
    \* 实现摘要生成场景功能的 RAG 上下文获取逻辑。  
    \* 实现摘要生成场景功能的 Prompt 构建和 LLM 调用逻辑（优先流式）。  
    \* 完成摘要生成场景功能的端到端测试。  
    \* 前后端联调与 Bug 修复。

\*\*(注: 此计划为初步估计，具体排期需根据团队资源和优先级进一步细化)\*\*  
