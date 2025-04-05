package com.ainovel.server.web.dto;

import java.util.List;
import java.util.Map;

import com.ainovel.server.domain.model.Novel;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 包含场景摘要的小说DTO
 * 适用于大纲视图，只包含小说基本信息和场景摘要，不包含场景完整内容
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NovelWithSummariesDto {
    
    /**
     * 小说基本信息
     */
    private Novel novel;
    
    /**
     * 按章节分组的场景摘要列表
     * key: 章节ID
     * value: 该章节下的场景摘要列表
     */
    private Map<String, List<SceneSummaryDto>> sceneSummariesByChapter;
} 