package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 摘要生成请求DTO
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SummarizeSceneRequest {
    /**
     * 场景内容
     */
    private String content;
    
    /**
     * 摘要最大长度（字符数）
     */
    private Integer maxLength;
    
    /**
     * 摘要语调
     */
    private String tone;
    
    /**
     * 摘要应专注于内容的哪些方面
     */
    private String focusOn;
} 