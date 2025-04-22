package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 摘要生成响应DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SummarizeSceneResponse {
    
    /**
     * 生成的摘要
     */
    private String summary;
    
    /**
     * 任务ID（用于异步任务跟踪）
     */
    private String taskId;
    
    /**
     * 任务状态
     * - processing: 处理中
     * - completed: 已完成
     * - error: 错误
     * - not_found: 未找到任务
     */
    private String status;

    /**
     * 只设置摘要的构造函数
     * @param summary 摘要内容
     */
    public SummarizeSceneResponse(String summary) {
        this.summary = summary;
        this.status = "completed";
    }
} 