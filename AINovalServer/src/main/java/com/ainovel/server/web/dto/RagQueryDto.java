package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * RAG查询数据传输对象
 * 用于接收前端发送的RAG查询请求
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RagQueryDto {

    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 查询文本
     */
    private String query;
} 