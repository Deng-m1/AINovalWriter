package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * RAG查询结果数据传输对象
 * 用于返回RAG查询的结果
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RagQueryResultDto {

    /**
     * 查询结果文本
     */
    private String result;
    
    /**
     * 原始查询文本
     */
    private String query;
} 