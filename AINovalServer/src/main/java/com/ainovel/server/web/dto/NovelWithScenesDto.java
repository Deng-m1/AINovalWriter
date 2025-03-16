package com.ainovel.server.web.dto;

import java.util.List;
import java.util.Map;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说及其场景DTO
 * 用于返回小说信息及其所有场景内容
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NovelWithScenesDto {
    
    /**
     * 小说基本信息
     */
    private Novel novel;
    
    /**
     * 所有场景，按章节ID分组
     * Map的键为章节ID，值为该章节下的所有场景列表
     */
    private Map<String, List<Scene>> scenesByChapter;
} 