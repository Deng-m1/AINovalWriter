package com.ainovel.server.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 优化区块
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OptimizationSection {
    /**
     * 区块标题
     */
    private String title;
    
    /**
     * 区块内容
     */
    private String content;
    
    /**
     * 原始内容
     */
    private String original;
    
    /**
     * 区块类型 (modified/unchanged)
     */
    private String type;
} 