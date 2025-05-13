package com.ainovel.server.web.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 设定搜索请求DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SettingSearchRequest {

    /**
     * 搜索查询关键词
     */
    private String query;
    
    /**
     * 筛选的设定类型列表
     */
    private List<String> types;
    
    /**
     * 筛选的设定组ID列表
     */
    private List<String> groupIds;
    
    /**
     * 最小相似度分数 (0.0-1.0)
     */
    @Builder.Default
    private Double minScore = 0.6;
    
    /**
     * 最大返回结果数
     */
    @Builder.Default
    private Integer maxResults = 10;
} 