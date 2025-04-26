package com.ainovel.server.task.dto.summarygeneration;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 生成场景摘要任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSummaryResult {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 生成的摘要内容
     */
    private String summary;
    
    /**
     * 是否遇到了版本冲突
     */
    private boolean conflict;
    
    /**
     * 最终更新使用的版本号
     */
    private int version;
} 