package com.ainovel.server.task.dto.batchsummary;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.HashMap;
import java.util.Map;

/**
 * 批量生成场景摘要任务结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatchGenerateSummaryResult {
    
    /**
     * 本次任务处理的总场景数
     */
    private int totalScenes;
    
    /**
     * 成功生成并更新摘要的场景数量
     */
    private int successCount;
    
    /**
     * 因错误（场景删除、AI失败等）而失败的场景数量
     */
    private int failedCount;
    
    /**
     * 检测到版本冲突并基于最新内容尝试生成的场景数量
     */
    private int conflictCount;
    
    /**
     * 因overwriteExisting=false且摘要已存在而跳过的场景数量
     */
    private int skippedCount;
    
    /**
     * 存储失败场景ID及其失败原因
     */
    @Builder.Default
    private Map<String, String> failedSceneDetails = new HashMap<>();
} 