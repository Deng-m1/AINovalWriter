package com.ainovel.server.service.impl;

import java.util.List;
import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.service.KnowledgeService;
import com.ainovel.server.service.NovelRagAssistant;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.service.rag.NovelSettingRagService;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * 小说RAG助手实现
 * 提供基于检索增强的小说内容检索功能
 */
@Slf4j
@Service
public class NovelRagAssistantImpl implements NovelRagAssistant {

    private final NovelService novelService;
    private final SceneService sceneService;
    private final KnowledgeService knowledgeService;
    private final NovelSettingRagService settingRagService;
    
    @Value("${ainovel.rag.max-context-items:5}")
    private int maxContextItems;

    @Autowired
    public NovelRagAssistantImpl(
            NovelService novelService,
            KnowledgeService knowledgeService,
            NovelSettingRagService settingRagService,
            SceneService sceneService) {
        this.novelService = novelService;
        this.knowledgeService = knowledgeService;
        this.settingRagService = settingRagService;
        this.sceneService = sceneService;
    }

    /**
     * 使用RAG上下文进行查询，只负责上下文检索，不负责生成
     *
     * @param novelId 小说ID
     * @param query 查询文本
     * @return 查询结果
     */
    @Override
    public Mono<String> queryWithRagContext(String novelId, String query) {
        log.info("检索小说相关信息，小说ID: {}, 查询: {}", novelId, query);
        
        // 获取与查询相关的上下文
        return retrieveRelevantContext(novelId, query)
            .flatMap(context -> {
                // 获取相关的设定信息
                return retrieveRelevantSettings(novelId, query)
                    .map(settingsContext -> {
                        // 格式化并返回上下文
                        return formatRetrievedContext(query, context, settingsContext);
                    });
            });
    }
    
    /**
     * 检索与查询相关的上下文
     *
     * @param novelId 小说ID
     * @param query 查询文本
     * @return 上下文文本
     */
    public Mono<String> retrieveRelevantContext(String novelId, String query) {
        return knowledgeService.retrieveRelevantContext(query, novelId, maxContextItems);
    }
    
    /**
     * 检索与查询相关的设定信息
     *
     * @param novelId 小说ID
     * @param query 查询文本
     * @return 设定上下文文本
     */
    public Mono<String> retrieveRelevantSettings(String novelId, String query) {
        return settingRagService.retrieveContextualSettings(novelId, query, maxContextItems)
                .collectList()
                .map(items -> {
                    if (items.isEmpty()) {
                        return "";
                    }
                    return settingRagService.formatSettingsForAI(items);
                });
    }
    
    /**
     * 格式化检索到的上下文和设定信息
     *
     * @param query 查询文本
     * @param context 检索到的上下文
     * @param settingsContext 设定上下文
     * @return 格式化后的上下文
     */
    private String formatRetrievedContext(String query, String context, String settingsContext) {
        StringBuilder sb = new StringBuilder();
        
        sb.append("## 相关背景信息\n\n");
        
        // 添加检索到的上下文
        if (StringUtils.isNotBlank(context)) {
            sb.append("### 小说内容\n\n");
            sb.append(context);
            sb.append("\n\n");
        }
        
        // 添加设定上下文
        if (StringUtils.isNotBlank(settingsContext)) {
            sb.append(settingsContext);
            sb.append("\n\n");
        }
        
        return sb.toString();
    }
    
    /**
     * 提取文本的最后几个段落
     *
     * @param text 文本
     * @param paragraphCount 段落数
     * @return 最后的段落
     */
    public String extractLastParagraphs(String text, int paragraphCount) {
        if (StringUtils.isBlank(text)) {
            return "";
        }
        
        String[] paragraphs = text.split("\n\n");
        if (paragraphs.length <= paragraphCount) {
            return text;
        }
        
        StringBuilder sb = new StringBuilder();
        for (int i = paragraphs.length - paragraphCount; i < paragraphs.length; i++) {
            sb.append(paragraphs[i]);
            if (i < paragraphs.length - 1) {
                sb.append("\n\n");
            }
        }
        
        return sb.toString();
    }
}
