package com.ainovel.server.domain.model;

import java.time.Instant;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.Data;

/**
 * 设定模型
 * 表示小说中的一个世界设定
 */
@Data
@Document(collection = "setting")
public class Setting {
    
    @Id
    private String id;
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 设定名称
     */
    private String name;
    
    /**
     * 设定类型（世界观、规则、地理等）
     */
    private String type;
    
    /**
     * 设定内容
     */
    private String content;
    
    /**
     * 创建时间
     */
    private Instant createdAt = Instant.now();
    
    /**
     * 更新时间
     */
    private Instant updatedAt = Instant.now();
} 