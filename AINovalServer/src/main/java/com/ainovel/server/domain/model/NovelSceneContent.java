package com.ainovel.server.domain.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说场景内容实体
 * 存储小说场景的内容数据
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "scene_contents")
public class NovelSceneContent {
    
    @Id
    private String id;
    
    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 章节ID
     */
    private String chapterId;
    
    /**
     * 场景标题
     */
    private String title;
    
    /**
     * 场景内容
     */
    private String content;
    
    /**
     * 字数统计
     */
    private int wordCount;
    
    /**
     * 摘要ID
     */
    private String summaryId;
    
    /**
     * 摘要内容
     */
    private String summaryContent;
    
    /**
     * 创建时间
     */
    private LocalDateTime createdAt;
    
    /**
     * 最后更新时间
     */
    private LocalDateTime updatedAt;
    
    /**
     * 版本号
     */
    private int version;
} 