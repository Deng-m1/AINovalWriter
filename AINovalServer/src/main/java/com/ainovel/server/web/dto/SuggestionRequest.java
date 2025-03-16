package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 创作建议请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SuggestionRequest {
    
    /**
     * 场景ID
     */
    private String sceneId;
    
    /**
     * 建议类型（情节、角色、对话等）
     */
    private String suggestionType;
} 