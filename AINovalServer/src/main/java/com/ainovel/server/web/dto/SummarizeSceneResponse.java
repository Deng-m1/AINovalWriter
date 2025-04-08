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
} 