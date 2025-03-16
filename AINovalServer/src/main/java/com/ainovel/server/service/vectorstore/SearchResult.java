package com.ainovel.server.service.vectorstore;

import java.util.Map;

import lombok.Data;

/**
 * 向量搜索结果
 */
@Data
public class SearchResult {

    /**
     * 结果ID
     */
    private String id;

    /**
     * 内容文本
     */
    private String content;

    /**
     * 相似度得分
     */
    private double score;

    /**
     * 元数据
     */
    private Map<String, Object> metadata;
}
