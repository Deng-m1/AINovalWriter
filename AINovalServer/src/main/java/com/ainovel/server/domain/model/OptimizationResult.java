package com.ainovel.server.domain.model;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 优化结果
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OptimizationResult {
    /**
     * 优化后的内容
     */
    private String optimizedContent;
    
    /**
     * 区块列表
     */
    private List<OptimizationSection> sections;
    
    /**
     * 统计数据
     */
    private OptimizationStatistics statistics;
} 