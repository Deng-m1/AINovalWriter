package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.TextIndexed;
import org.springframework.data.mongodb.core.mapping.Document;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "novels")
public class Novel {

    @Id
    private String id;

    @TextIndexed
    private String title;

    @TextIndexed
    private String description;

    private Author author;

    @Builder.Default
    private List<String> genre = new ArrayList<>();

    @Builder.Default
    private List<String> tags = new ArrayList<>();

    private String coverImage;

    private String status;

    @Builder.Default
    private Structure structure = new Structure();

    @Builder.Default
    private Metadata metadata = new Metadata();

    // 记录上次编辑的章节ID
    private String lastEditedChapterId;

    // 是否归档状态
    @Builder.Default
    private Boolean isArchived = false;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    /**
     * 作者信息
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Author {

        private String id;
        private String username;
    }

    /**
     * 小说结构
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Structure {

        @Builder.Default
        private List<Act> acts = new ArrayList<>();
    }

    /**
     * 卷
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Act {

        private String id;
        private String title;
        private String description;
        private int order;
        @Builder.Default
        private List<Chapter> chapters = new ArrayList<>();
    }

    /**
     * 章节
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Chapter {

        private String id;
        private String title;
        private String description;
        private int order;
        // 修改为scenes列表，实现一对多关系
        @Builder.Default
        private List<String> sceneIds = new ArrayList<>();
    }

    /**
     * 元数据
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Metadata {

        private int wordCount;
        private int readTime;
        private LocalDateTime lastEditedAt;
        private int version;
        @Builder.Default
        private List<String> contributors = new ArrayList<>();
    }
}
