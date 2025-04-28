package com.ainovel.server.task.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景摘要生成任务参数
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSummaryParameters {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 小说ID (可选)
     */
    private String novelId;
    
    /**
     * 生成语调
     */
    private String tone;
    
    /**
     * 摘要最大长度
     */
    private Integer maxLength;
    
    /**
     * 摘要关注点
     */
    private String focusOn;
} 