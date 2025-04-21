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

        return mongoTemplate.findOne(
                Query.query(Criteria.where("type").is(promptType)),
                PromptTemplate.class
        )
                .map(template -> template.getContent());
    }

    @Override
    public Mono<List<String>> getAllPromptTypes() {
        log.info("获取所有提示词类型");

        return mongoTemplate.findDistinct(
                new Query(),
                "type",
                PromptTemplate.class,
                String.class
        )
                .collectList();
    }
}
