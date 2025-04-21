package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 剧情大纲生成的数据块
 * 用于流式传输生成的剧情大纲选项
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class OutlineGenerationChunk {
    /**
     * 选项ID，用于唯一标识一个剧情选项
     */
    private String optionId;
    
    /**
     * 选项标题，AI生成的剧情选项的短标题
     */
    private String optionTitle;
    
    /**
     * 文本块内容，大纲内容的文本片段
     */
    private String textChunk;
    
    /**
     * 是否为该选项的最后一个块
     */
    private boolean isFinalChunk;
    
    /**
     * 错误信息，如果生成过程中出错则包含错误信息
     */
    private String error;
} 