package com.ainovel.server.domain.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 解析后的场景数据模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ParsedSceneData {
    
    /**
     * 场景标题（即章节标题）
     */
    private String sceneTitle;
    
    /**
     * 场景内容
     */
    private String sceneContent;
    
    /**
     * 场景顺序
     */
    private int order;
} 