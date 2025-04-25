package com.ainovel.server.task.dto.summarygeneration;

/**
 * 摘要生成任务进度
 */
public class GenerateSummaryProgress {
    private String sceneId;
    private Integer percentComplete;
    private String partialSummary;
    
    // 默认构造函数，用于反序列化
    public GenerateSummaryProgress() {
    }
    
    public GenerateSummaryProgress(String sceneId, Integer percentComplete, String partialSummary) {
        this.sceneId = sceneId;
        this.percentComplete = percentComplete;
        this.partialSummary = partialSummary;
    }
    
    // Getters and Setters
    public String getSceneId() {
        return sceneId;
    }
    
    public void setSceneId(String sceneId) {
        this.sceneId = sceneId;
    }
    
    public Integer getPercentComplete() {
        return percentComplete;
    }
    
    public void setPercentComplete(Integer percentComplete) {
        this.percentComplete = percentComplete;
    }
    
    public String getPartialSummary() {
        return partialSummary;
    }
    
    public void setPartialSummary(String partialSummary) {
        this.partialSummary = partialSummary;
    }
} 