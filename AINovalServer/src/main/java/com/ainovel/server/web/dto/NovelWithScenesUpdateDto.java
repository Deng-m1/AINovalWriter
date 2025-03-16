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
 * 小说更新数据传输对象，包含场景内容
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NovelWithScenesUpdateDto {
    
    /**
     * 小说基本信息
     */
    private Novel novel;
    
    /**
     * 需要更新的场景列表，按章节ID分组
     * Map的键为章节ID，值为该章节下需要更新的场景列表
     */
    private Map<String, List<Scene>> scenesByChapter;
} 