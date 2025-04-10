package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 根据摘要生成场景响应DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSceneFromSummaryResponse {
    
    /**
     * 生成的场景内容
     */
    private String generatedContent;
} 