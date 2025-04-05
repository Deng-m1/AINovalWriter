package com.ainovel.server.web.dto;

import java.time.LocalDateTime;

import com.fasterxml.jackson.annotation.JsonFormat;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景摘要DTO
 * 包含场景的基本信息及摘要，不包含完整内容，适用于大纲视图
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SceneSummaryDto {
    
    private String id;
    
    private String novelId;
    
    private String chapterId;
    
    private String title;
    
    private String summary;
    
    private Integer sequence;
    
    private Integer wordCount;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime updatedAt;
} 