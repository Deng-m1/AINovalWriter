package com.ainovel.server.task.dto.summarygeneration;

/**
 * 摘要生成任务结果
 */
public class GenerateSummaryResult {
    private String sceneId;
    private String summary;
    private Integer tokenCount;
    private String modelId;
    
    // 默认构造函数，用于反序列化
    public GenerateSummaryResult() {
    }
    
    public GenerateSummaryResult(String sceneId, String summary, Integer tokenCount, String modelId) {
        this.sceneId = sceneId;
        this.summary = summary;
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
    
    public String getSummary() {
        return summary;
    }
    
    public void setSummary(String summary) {
        this.summary = summary;
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