package com.ainovel.server.task.dto.scenegeneration;

/**
 * 场景生成任务参数
 */
public class GenerateSceneParameters {
    private String sceneId;
    private String summary;
    private String modelId;
    private Integer maxTokens;
    private Double temperature;
    private String previousSceneContent;
    private String promptTemplateId;
    
    // 默认构造函数，用于反序列化
    public GenerateSceneParameters() {
    }
    
    public GenerateSceneParameters(String sceneId, String summary, String modelId, 
                                   Integer maxTokens, Double temperature,
                                   String previousSceneContent, String promptTemplateId) {
        this.sceneId = sceneId;
        this.summary = summary;
        this.modelId = modelId;
        this.maxTokens = maxTokens;
        this.temperature = temperature;
        this.previousSceneContent = previousSceneContent;
        this.promptTemplateId = promptTemplateId;
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
    
    public String getPreviousSceneContent() {
        return previousSceneContent;
    }
    
    public void setPreviousSceneContent(String previousSceneContent) {
        this.previousSceneContent = previousSceneContent;
    }
    
    public String getPromptTemplateId() {
        return promptTemplateId;
    }
    
    public void setPromptTemplateId(String promptTemplateId) {
        this.promptTemplateId = promptTemplateId;
    }
} 