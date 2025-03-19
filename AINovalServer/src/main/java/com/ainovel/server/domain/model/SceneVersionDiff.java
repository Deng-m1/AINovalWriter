package com.ainovel.server.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景版本差异
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SceneVersionDiff {
    /**
     * 原始内容
     */
    private String originalContent;
    
    /**
     * 新内容
     */
    private String newContent;
    
    /**
     * 差异内容
     */
    private String diff;
} 