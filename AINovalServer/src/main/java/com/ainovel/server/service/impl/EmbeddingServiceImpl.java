package com.ainovel.server.service.impl;

import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ainovel.server.service.EmbeddingService;

import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.model.openai.OpenAiEmbeddingModel;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * 嵌入服务实现类
 * 负责文本向量化功能
 */
@Slf4j
@Service
public class EmbeddingServiceImpl implements EmbeddingService {
    
    // 嵌入模型缓存
    private final Map<String, EmbeddingModel> embeddingModels = new HashMap<>();
    
    // 默认嵌入模型名称
    private final String defaultEmbeddingModel;
    
    // OpenAI API密钥
    private final String openaiApiKey;
    
    public EmbeddingServiceImpl(
            @Value("${ai.embedding.default-model:text-embedding-3-small}") String defaultEmbeddingModel,
            @Value("${ai.openai.api-key:#{environment.OPENAI_API_KEY}}") String openaiApiKey) {
        this.defaultEmbeddingModel = defaultEmbeddingModel;
        this.openaiApiKey = openaiApiKey;
        log.info("初始化嵌入服务，默认模型: {}", defaultEmbeddingModel);
    }
    
    /**
     * 生成文本的向量嵌入
     * 使用默认的嵌入模型
     * @param text 文本内容
     * @return 向量嵌入
     */
    @Override
    public Mono<float[]> generateEmbedding(String text) {
        return generateEmbedding(text, defaultEmbeddingModel);
    }
    
    /**
     * 生成文本的向量嵌入
     * @param text 文本内容
     * @param modelName 模型名称
     * @return 向量嵌入
     */
    @Override
    public Mono<float[]> generateEmbedding(String text, String modelName) {
        log.info("生成文本向量嵌入，模型: {}", modelName);
        
        if (text == null || text.isEmpty()) {
            return Mono.error(new IllegalArgumentException("文本内容不能为空"));
        }
        
        return Mono.fromCallable(() -> {
            EmbeddingModel embeddingModel = getOrCreateEmbeddingModel(modelName);
            Embedding embedding = embeddingModel.embed(text).content();
            return embedding.vector();
        }).onErrorResume(e -> {
            log.error("生成向量嵌入失败", e);
            return Mono.error(new RuntimeException("生成向量嵌入失败: " + e.getMessage()));
        });
    }
    
    /**
     * 获取或创建嵌入模型
     * @param modelName 模型名称
     * @return 嵌入模型
     */
    private EmbeddingModel getOrCreateEmbeddingModel(String modelName) {
        // 从缓存中获取模型
        EmbeddingModel model = embeddingModels.get(modelName);
        if (model != null) {
            return model;
        }
        
        // 验证API密钥
        if (openaiApiKey == null || openaiApiKey.isEmpty()) {
            throw new IllegalStateException("未设置OpenAI API密钥");
        }
        
        // 创建新模型
        if (modelName.startsWith("text-embedding")) {
            // OpenAI嵌入模型
            model = OpenAiEmbeddingModel.builder()
                    .apiKey(openaiApiKey)
                    .modelName(modelName)
                    .build();
        } else {
            // 默认使用OpenAI嵌入模型
            model = OpenAiEmbeddingModel.builder()
                    .apiKey(openaiApiKey)
                    .modelName(defaultEmbeddingModel)
                    .build();
        }
        
        // 缓存模型
        embeddingModels.put(modelName, model);
        return model;
    }
} 