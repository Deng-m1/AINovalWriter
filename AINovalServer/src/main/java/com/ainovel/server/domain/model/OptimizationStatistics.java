package com.ainovel.server.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 优化统计数据
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OptimizationStatistics {
    /**
     * 原始token数
     */
    private int originalTokens;
    
    /**
     * 优化后token数
     */
    private int optimizedTokens;
    
    /**
     * 原始长度
     */
    private int originalLength;
    
    /**
     * 优化后长度
     */
    private int optimizedLength;
    
    /**
     * 效率提升
     */
    private double efficiency;
} 