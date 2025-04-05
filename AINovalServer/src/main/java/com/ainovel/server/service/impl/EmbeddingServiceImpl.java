package com.ainovel.server.service.impl;

import java.util.HashMap;
import java.util.Map;

import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModel;
import dev.langchain4j.model.embedding.onnx.allminilml6v2.AllMiniLmL6V2EmbeddingModelFactory;
import dev.langchain4j.model.embedding.onnx.allminilml6v2q.AllMiniLmL6V2QuantizedEmbeddingModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ainovel.server.service.EmbeddingService;

import dev.langchain4j.data.embedding.Embedding;
import dev.langchain4j.model.embedding.EmbeddingModel;

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
    
    // 是否使用量化模型（量化模型速度更快但精度略低）
    private final boolean useQuantizedModel;
    
    public EmbeddingServiceImpl(
            @Value("${ai.embedding.default-model:all-minilm-l6-v2}") String defaultEmbeddingModel,
            @Value("${ai.embedding.use-quantized:true}") boolean useQuantizedModel) {
        this.defaultEmbeddingModel = defaultEmbeddingModel;
        this.useQuantizedModel = useQuantizedModel;
        log.info("初始化嵌入服务，默认模型: {}, 使用量化模型: {}", defaultEmbeddingModel, useQuantizedModel);
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
            log.info("生成向量模型成功");
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
        
        // 创建新模型
        if ("all-minilm-l6-v2".equals(modelName)) {
            // 使用本地的 AllMiniLmL6V2 模型
            if (useQuantizedModel) {
                // 使用量化版本（更小更快，但精度略低）
                // 通过反射创建量化版本的模型
                try {
                    model = new AllMiniLmL6V2QuantizedEmbeddingModel();

                    log.info("创建量化版 AllMiniLmL6V2 嵌入模型");
                } catch (Exception e) {
                    log.error("创建量化版 AllMiniLmL6V2 嵌入模型失败", e);
                    throw new RuntimeException("创建量化版 AllMiniLmL6V2 嵌入模型失败: " + e.getMessage());
                }
            } else {
                // 使用完整版本
                try {
                    model=new AllMiniLmL6V2EmbeddingModel();
                    log.info("创建完整版 AllMiniLmL6V2 嵌入模型");
                } catch (Exception e) {
                    log.error("创建完整版 AllMiniLmL6V2 嵌入模型失败", e);
                    throw new RuntimeException("创建完整版 AllMiniLmL6V2 嵌入模型失败: " + e.getMessage());
                }
            }
        } else {
            // 默认使用量化版本的 AllMiniLmL6V2 模型
            try {
                model=new AllMiniLmL6V2EmbeddingModel();
                log.info("创建默认量化版 AllMiniLmL6V2 嵌入模型");
            } catch (Exception e) {
                log.error("创建默认量化版 AllMiniLmL6V2 嵌入模型失败", e);
                throw new RuntimeException("创建默认量化版 AllMiniLmL6V2 嵌入模型失败: " + e.getMessage());
            }
        }
        
        // 缓存模型
        embeddingModels.put(modelName, model);
        return model;
    }
} 