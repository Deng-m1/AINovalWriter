package com.ainovel.server.task.dto.summarygeneration;

/**
 * 摘要生成任务参数
 */
public class GenerateSummaryParameters {
    private String sceneId;
    private String sceneContent;
    private String modelId;
    private Integer maxTokens;
    private Double temperature;
    
    // 默认构造函数，用于反序列化
    public GenerateSummaryParameters() {
    }
    
    public GenerateSummaryParameters(String sceneId, String sceneContent, String modelId, Integer maxTokens, Double temperature) {
        this.sceneId = sceneId;
        this.sceneContent = sceneContent;
        this.modelId = modelId;
        this.maxTokens = maxTokens;
        this.temperature = temperature;
    }
    
    // Getters and Setters
    public String getSceneId() {
        return sceneId;
    }
    
    public void setSceneId(String sceneId) {
        this.sceneId = sceneId;
    }
    
    public String getSceneContent() {
        return sceneContent;
    }
    
    public void setSceneContent(String sceneContent) {
        this.sceneContent = sceneContent;
    }
    
    public String getModelId() {
        return modelId;
    }
    
    public void setModelId(String modelId) {
        this.modelId = modelId;
    }
    
    public Integer getMaxTokens() {
        return maxTokens;
    }
    
    public void setMaxTokens(Integer maxTokens) {
        this.maxTokens = maxTokens;
    }
    
    public Double getTemperature() {
        return temperature;
    }
    
    public void setTemperature(Double temperature) {
        this.temperature = temperature;
    }
} 