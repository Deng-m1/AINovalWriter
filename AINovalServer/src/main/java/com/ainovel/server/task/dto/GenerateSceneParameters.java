package com.ainovel.server.task.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景生成任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSceneParameters {
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 场景摘要
     */
    private String summary;
    
    /**
     * 生成风格
     */
    private String style;
    
    /**
     * 生成长度
     */
    private String length;
    
    /**
     * 生成语调
     */
    private String tone;
    
    /**
     * 额外指令
     */
    private String additionalInstructions;
} 