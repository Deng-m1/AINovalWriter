package com.ainovel.server.task.dto.scenegeneration;

/**
 * 场景生成任务结果
 */
public class GenerateSceneResult {
    private String sceneId;
    private String content;
    private Integer tokenCount;
    private String modelId;
    
    // 默认构造函数，用于反序列化
    public GenerateSceneResult() {
    }
    
    public GenerateSceneResult(String sceneId, String content, Integer tokenCount, String modelId) {
        this.sceneId = sceneId;
        this.content = content;
        this.tokenCount = tokenCount;
        this.modelId = modelId;
    }
    
    // Getters and Setters
    public String getSceneId() {
        return sceneId;
    }
    
    public void setSceneId(String sceneId) {
        this.sceneId = sceneId;
    }
    
    public String getContent() {
        return content;
    }
    
    public void setContent(String content) {
        this.content = content;
    }
    
    public Integer getTokenCount() {
        return tokenCount;
    }
    
    public void setTokenCount(Integer tokenCount) {
        this.tokenCount = tokenCount;
    }
    
    public String getModelId() {
        return modelId;
    }
    
    public void setModelId(String modelId) {
        this.modelId = modelId;
    }
} 