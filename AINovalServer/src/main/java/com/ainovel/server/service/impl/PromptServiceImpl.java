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
        DEFAULT_TEMPLATES.put("next_outlines_generation", "你是一位经验丰富的网络小说作家助手。请根据以下提供的小说背景信息和当前剧情进展：\n\n{{context}}\n\n{{authorGuidance}}\n\n请为这部小说构思接下来可能发生的 {{numberOfOptions}} 个不同的剧情大纲选项。每个大纲应包含：\n1. 主要事件或转折点。\n2. 涉及的关键角色及其行动。\n3. 可能产生的悬念或冲突。\n请确保每个选项都逻辑连贯，符合现有设定，并且彼此之间具有明显的区别。请以清晰的列表格式输出每个大纲选项。");
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
                .map(PromptTemplate::getTemplate);
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
