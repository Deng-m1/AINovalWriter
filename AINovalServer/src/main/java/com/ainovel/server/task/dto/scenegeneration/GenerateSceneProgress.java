package com.ainovel.server.task.dto.scenegeneration;

/**
 * 场景生成任务进度
 */
public class GenerateSceneProgress {
    private String sceneId;
    private Integer percentComplete;
    private String partialContent;
    
    // 默认构造函数，用于反序列化
    public GenerateSceneProgress() {
    }
    
    public GenerateSceneProgress(String sceneId, Integer percentComplete, String partialContent) {
        this.sceneId = sceneId;
        this.percentComplete = percentComplete;
        this.partialContent = partialContent;
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
    
    public String getPartialContent() {
        return partialContent;
    }
    
    public void setPartialContent(String partialContent) {
        this.partialContent = partialContent;
    }
} 