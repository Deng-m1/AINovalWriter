package com.ainovel.server.service.impl;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.PromptTemplate;
import com.ainovel.server.service.PromptService;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

// Add AIFeatureType if not already imported, assuming it's in a common location
import com.ainovel.server.domain.model.AIFeatureType;

/**
 * 提示词服务实现类 负责管理各种类型的提示词模板
 */
@Slf4j
@Service
public class PromptServiceImpl implements PromptService {

    private final ReactiveMongoTemplate mongoTemplate;

    // 默认提示词模板
    private static final Map<String, String> DEFAULT_TEMPLATES = new HashMap<>();

    static {
        // 初始化默认提示词模板
        DEFAULT_TEMPLATES.put("plot", "请为我的小说提供情节建议。我正在写一个场景，需要有创意的情节发展。");
        DEFAULT_TEMPLATES.put("character", "请为我的小说提供角色互动建议。我需要让角色之间的对话和互动更加生动。");
        DEFAULT_TEMPLATES.put("dialogue", "请为我的小说提供对话建议。我需要让角色的对话更加自然和有特点。");
        DEFAULT_TEMPLATES.put("description", "请为我的小说提供场景描述建议。我需要让环境描写更加生动和有氛围感。");
        DEFAULT_TEMPLATES.put("revision", "请帮我修改以下内容，按照指示进行调整：\n\n{{content}}\n\n修改指示：{{instruction}}\n\n请提供修改后的完整内容。");
        DEFAULT_TEMPLATES.put("character_generation", "请根据以下描述，为我的小说创建一个详细的角色：\n\n{{description}}\n\n请提供角色的姓名、外貌、性格、背景故事、动机和特点等信息。");
        DEFAULT_TEMPLATES.put("plot_generation", "请根据以下描述，为我的小说创建一个详细的情节：\n\n{{description}}\n\n请提供情节的起因、发展、高潮和结局，以及可能的转折点和悬念。");
        DEFAULT_TEMPLATES.put("setting_generation", "请根据以下描述，为我的小说创建一个详细的世界设定：\n\n{{description}}\n\n请提供这个世界的地理、历史、文化、社会结构、规则和特殊元素等信息。");
        DEFAULT_TEMPLATES.put("next_outlines_generation", "你是一位专业的小说创作顾问，擅长为作者提供多样化的剧情发展选项。请根据以下信息，为作者生成 {{numberOfOptions}} 个不同的剧情大纲选项，每个选项应该是对当前故事的合理延续。\n\n小说当前进展：{{context}}\n\n{{authorGuidance}}\n\n请为每个选项提供以下内容：\n1. 一个简短但吸引人的标题\n2. 剧情概要（200-300字）\n3. 主要事件（3-5个关键点）\n4. 涉及的角色\n5. 冲突或悬念\n\n格式要求：\n选项1：[标题]\n[剧情概要]\n主要事件：\n- [事件1]\n- [事件2]\n- [事件3]\n涉及角色：[角色列表]\n冲突/悬念：[冲突或悬念描述]\n\n选项2：[标题]\n...\n\n注意事项：\n- 每个选项应该有明显的差异，提供真正不同的故事发展方向\n- 保持与已有故事的连贯性和一致性\n- 考虑角色动机和故事内在逻辑\n- 提供有创意但合理的发展方向\n- 确保每个选项都有足够的戏剧冲突和情感张力");
        
        // 新增设定生成相关提示词模板
        DEFAULT_TEMPLATES.put("setting_item_generation", "你是一个专业的小说设定分析专家。你的任务是从提供的文本中提取并生成小说设定项。" +
            "每个对象必须代表一个不同的设定项，并且必须包含\'name\'（字符串）、\'type\'（字符串，必须是提供的有效类型之一）和\'description\'（字符串）。" +
            "可选字段是\'attributes\'（Map<String, String>）和\'tags\'（List<String>）。" +
            "确保输出是有效的JSON对象列表。如果找不到某种类型的设定，请不要包含它。");

        // 新增：下一章剧情大纲生成提示词模板
        DEFAULT_TEMPLATES.put("next_chapter_outline_generation", "你是一位专业的小说创作顾问，擅长为作者的下一章内容提供一个详细的剧情发展构思。" +
            "你的目标是基于提供的小说背景信息、最近章节的完整内容以及作者的特定指导，创作出一个详细的、仅覆盖一章内容的剧情大纲。" +
            "请仔细研读\"上一章节完整内容\"，以确保你的建议在文风、文笔和情节发展上与原文保持一致性和连贯性。" +
            "剧情大纲应该足够详细，能够支撑起一个完整章节的写作，并明确指出故事将如何在本章内发展和可能的小高潮。" +
            "不要生成超出单章范围的剧情。" +
            "\n\n小说当前进展摘要：\n{{contextSummary}}" +
            "\n\n上一章节完整内容：\n{{previousChapterContent}}" +
            "\n\n作者的创作方向引导：\n{{authorGuidance}}" +
            "\n\n请严格按照以下格式返回你的剧情大纲，确保是纯文本，不包含任何列表符号 (如 '*' 或 '-') 或其他 Markdown 格式：" +
            "\n标题：[此处填写简洁且引人入胜的标题，点明本章核心内容]" +
            "\n剧情概要：[此处填写详细的本章剧情概要，描述主要情节脉络、发展和转折，预计300-500字]" +
            "\n\n请确保你的构思独特且合理，同时忠于已有的故事设定和角色塑造。");

        // 新增: "根据摘要生成场景" 的系统提示词
        DEFAULT_TEMPLATES.put(AIFeatureType.SUMMARY_TO_SCENE.name() + "_SYSTEM",
                "你是一位富有创意的小说家。请根据用户提供的摘要、上下文信息和风格要求，生成详细的小说场景内容。" +
                "你的任务是只输出生成的场景内容本身，不包含任何标题、小标题、格式标记（如Markdown）、或其他解释性文字。" +
                "\n\n可用的占位符说明：\n" +
                "- {{summary}}/{{input}}/{{content}}: 章节摘要内容，是生成场景的主要依据\n" +
                "- {{context}}: 相关的上下文信息，包括RAG检索结果和前序章节内容\n" +
                "- {{styleInstructions}}/{{style}}/{{instruction}}: 用户提供的风格和特殊要求");

        // 新增: "根据摘要生成场景" 的基础用户提示词模板
        // UserPromptService 会优先查找用户自定义版本，如果找不到，则回退到这个基础版本
        DEFAULT_TEMPLATES.put(AIFeatureType.SUMMARY_TO_SCENE.name(),
                "摘要:\n{{summary}}\n\n相关上下文:\n{{context}}\n\n风格要求:\n{{styleInstructions}}\n\n" +
                "请根据以上摘要和上下文信息，创作一个完整的场景。确保场景内容与摘要和上下文保持一致，" +
                "同时符合风格要求。你需要将摘要中简要描述的内容具体化，加入细节、对话、情感和环境描写。");
    }

    @Autowired
    public PromptServiceImpl(ReactiveMongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }

    @Override
    public Mono<String> getSuggestionPrompt(String suggestionType) {
        log.info("获取建议提示词，类型: {}", suggestionType);

        return getPromptTemplate(suggestionType)
                .switchIfEmpty(Mono.defer(() -> {
                    // 如果数据库中没有找到，使用默认模板
                    String defaultTemplate = DEFAULT_TEMPLATES.getOrDefault(suggestionType,
                            "请为我的小说提供" + suggestionType + "方面的建议。");

                    // 保存默认模板到数据库
                    return savePromptTemplate(suggestionType, defaultTemplate)
                            .thenReturn(defaultTemplate);
                }));
    }
    
    /**
     * 获取结构化的设定生成提示词，用于支持JSON Schema的模型
     * 
     * @param settingTypes 设定类型列表（逗号分隔）
     * @param maxSettingsPerType 每种类型最大生成数量
     * @param additionalInstructions 用户的额外指示
     * @return 结构化的系统和用户提示词
     */
    @Override
    public Mono<Map<String, String>> getStructuredSettingPrompt(String settingTypes, int maxSettingsPerType, String additionalInstructions) {
        Map<String, String> prompts = new HashMap<>();
        
        // 系统提示词
        prompts.put("system", "你是一个专业的小说设定分析专家。你的任务是从提供的文本中提取并生成小说设定项。" +
            "每个对象必须代表一个不同的设定项，并且必须包含'name'（字符串）、'type'（字符串，必须是提供的有效类型之一）和'description'（字符串）。" +
            "可选字段是'attributes'（Map<String, String>）和'tags'（List<String>）。" +
            "确保输出是有效的JSON对象列表。如果找不到某种类型的设定，请不要包含它。");
        
        // 用户提示词模板
        String userPromptTemplate = "小说上下文:{{contextText}}\n\n" +
            "请求的设定类型: {{settingTypes}}\n" +
            "为每种请求的类型从小说上下文中生成大约 {{maxSettingsPerType}} 个项目。\n" +
            "用户的附加说明: {{additionalInstructions}}";
        
        // 填充用户提示词模板
        String userPrompt = userPromptTemplate
            .replace("{{settingTypes}}", settingTypes)
            .replace("{{maxSettingsPerType}}", String.valueOf(maxSettingsPerType))
            .replace("{{additionalInstructions}}", additionalInstructions == null ? "" : additionalInstructions);
        
        prompts.put("user", userPrompt);
        
        return Mono.just(prompts);
    }
    
    /**
     * 获取常规的设定生成提示词，用于不支持JSON Schema的模型
     * 
     * @param contextText 小说上下文文本
     * @param settingTypes 设定类型列表（逗号分隔）
     * @param maxSettingsPerType 每种类型最大生成数量
     * @param additionalInstructions 用户的额外指示
     * @return 完整的提示词
     */
    @Override
    public Mono<String> getGeneralSettingPrompt(String contextText, String settingTypes, int maxSettingsPerType, String additionalInstructions) {
        StringBuilder promptBuilder = new StringBuilder();
        promptBuilder.append("你是一个专业的小说设定分析专家。请从以下小说内容中提取并生成小说设定项。\n\n");
        promptBuilder.append("小说内容:\n").append(contextText).append("\n\n");
        promptBuilder.append("请求的设定类型: ").append(settingTypes).append("\n");
        promptBuilder.append("为每种请求的类型生成大约 ").append(maxSettingsPerType).append(" 个项目。\n");
        
        if (additionalInstructions != null && !additionalInstructions.isEmpty()) {
            promptBuilder.append("附加说明: ").append(additionalInstructions).append("\n\n");
        }
        
        promptBuilder.append("请以JSON数组格式返回结果。每个对象必须包含以下字段:\n");
        promptBuilder.append("- name: 设定项名称 (字符串)\n");
        promptBuilder.append("- type: 设定类型 (字符串，必须是请求的类型之一)\n");
        promptBuilder.append("- description: 详细描述 (字符串)\n");
        promptBuilder.append("可选字段:\n");
        promptBuilder.append("- attributes: 属性映射 (键值对)\n");
        promptBuilder.append("- tags: 标签列表 (字符串数组)\n\n");
        promptBuilder.append("示例输出格式:\n");
        promptBuilder.append("[{\"name\": \"魔法剑\", \"type\": \"ITEM\", \"description\": \"一把会发光的剑\", \"attributes\": {\"color\": \"blue\"}, \"tags\": [\"magic\", \"weapon\"]}]\n\n");
        promptBuilder.append("确保输出是有效的JSON数组。你的输出必须是纯JSON格式，不需要任何额外的说明文字。");
        
        return Mono.just(promptBuilder.toString());
    }

    @Override
    public Mono<String> getRevisionPrompt() {
        return getPromptTemplate("revision")
                .switchIfEmpty(Mono.defer(() -> {
                    String defaultTemplate = DEFAULT_TEMPLATES.get("revision");
                    return savePromptTemplate("revision", defaultTemplate)
                            .thenReturn(defaultTemplate);
                }));
    }

    @Override
    public Mono<String> getCharacterGenerationPrompt() {
        return getPromptTemplate("character_generation")
                .switchIfEmpty(Mono.defer(() -> {
                    String defaultTemplate = DEFAULT_TEMPLATES.get("character_generation");
                    return savePromptTemplate("character_generation", defaultTemplate)
                            .thenReturn(defaultTemplate);
                }));
    }

    @Override
    public Mono<String> getPlotGenerationPrompt() {
        return getPromptTemplate("plot_generation")
                .switchIfEmpty(Mono.defer(() -> {
                    String defaultTemplate = DEFAULT_TEMPLATES.get("plot_generation");
                    return savePromptTemplate("plot_generation", defaultTemplate)
                            .thenReturn(defaultTemplate);
                }));
    }

    @Override
    public Mono<String> getSettingGenerationPrompt() {
        return getPromptTemplate("setting_generation")
                .switchIfEmpty(Mono.defer(() -> {
                    String defaultTemplate = DEFAULT_TEMPLATES.get("setting_generation");
                    return savePromptTemplate("setting_generation", defaultTemplate)
                            .thenReturn(defaultTemplate);
                }));
    }

    @Override
    public Mono<String> getNextOutlinesGenerationPrompt() {
        return getPromptTemplate("next_outlines_generation")
                .switchIfEmpty(Mono.defer(() -> {
                    String defaultTemplate = DEFAULT_TEMPLATES.get("next_outlines_generation");
                    return savePromptTemplate("next_outlines_generation", defaultTemplate)
                            .thenReturn(defaultTemplate);
                }));
    }

    @Override
    public Mono<String> getNextChapterOutlineGenerationPrompt() {
        return getPromptTemplate("next_chapter_outline_generation")
                .switchIfEmpty(Mono.defer(() -> {
                    String defaultTemplate = DEFAULT_TEMPLATES.get("next_chapter_outline_generation");
                    return savePromptTemplate("next_chapter_outline_generation", defaultTemplate)
                            .thenReturn(defaultTemplate);
                }));
    }

    @Override
    public Mono<String> getSingleOutlineGenerationPrompt() {
        String prompt = "基于以下上下文信息，为小说生成一个有趣而合理的后续剧情大纲选项。"
                + "请确保生成的剧情与已有内容保持连贯，符合角色性格，推动情节发展。\n\n"
                + "当前上下文：\n{{context}}\n\n"
                + "{{authorGuidance}}\n\n"
                + "请严格按照以下格式返回你的剧情大纲，先输出标题，再输出内容：\n"
                + "TITLE: [简洁有力的标题，概括这个剧情走向的核心]\n"
                + "CONTENT: [详细描述这个剧情大纲，包括关键人物动向、重要事件、情节转折等]";
        
        return Mono.just(prompt);
    }

    @Override
    public Mono<Void> savePromptTemplate(String promptType, String template) {
        log.info("保存提示词模板，类型: {}", promptType);

        Query query = new Query(Criteria.where("type").is(promptType));
        Update update = new Update()
                .set("template", template)
                .set("updatedAt", java.time.Instant.now());

        return mongoTemplate.upsert(query, update, PromptTemplate.class)
                .then();
    }

    @Override
    public Mono<String> getPromptTemplate(String promptType) {
        log.info("获取提示词模板，类型: {}", promptType);

        // 尝试从数据库获取模板
        Query query = Query.query(Criteria.where("type").is(promptType));
        
        return mongoTemplate.findOne(query, PromptTemplate.class)
                .flatMap(promptTemplate -> Mono.justOrEmpty(promptTemplate.getContent()))
                .switchIfEmpty(Mono.defer(() -> {
                    log.warn("数据库中未找到类型为 '{}' 的提示词模板，将使用默认模板。", promptType);
                    return Mono.justOrEmpty(DEFAULT_TEMPLATES.get(promptType));
                }));
    }

    @Override
    public Mono<List<String>> getAllPromptTypes() {
        log.info("获取所有提示词类型");

        return mongoTemplate.findDistinct(
                new Query(),
                "type",
                PromptTemplate.class,
                String.class
        ).collectList();
    }

    @Override
    public Mono<String> getSystemMessageForFeature(AIFeatureType featureType) {
        String key = featureType.name() + "_SYSTEM";
        log.info("获取特性 {} 的系统提示词，键: {}", featureType, key);
        return getPromptTemplate(key)
                .switchIfEmpty(Mono.defer(() -> {
                    log.warn("特性 {} 没有找到特定的系统提示词 (键: {})，可能需要定义默认模板。", featureType, key);
                    return Mono.empty(); // 或者返回一个非常通用的默认系统提示
                }));
    }
}
