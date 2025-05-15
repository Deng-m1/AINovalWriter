package com.ainovel.server.domain.model;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景领域模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "scenes")
@CompoundIndexes({
    @CompoundIndex(name = "novel_chapter_idx", def = "{'novelId': 1, 'chapterId': 1}")
})
public class Scene {

    @Id
    private String id;

    @Indexed
    private String novelId;

    @Indexed
    private String chapterId;

    private String title;

    private String content;

    private String summary;

    /**
     * 场景字数
     */
    private Integer wordCount;

    /**
     * 场景序号，用于排序
     */
    private Integer sequence;

    /**
     * 场景类型
     */
    private String sceneType;

    private VectorEmbedding vectorEmbedding;

    @Builder.Default
    private List<String> characterIds = new ArrayList<>();

    @Builder.Default
    private List<String> locations = new ArrayList<>();

    private String timeframe;

    private int version;

    @Builder.Default
    private List<HistoryEntry> history = new ArrayList<>();

    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS")
    private LocalDateTime createdAt;

    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS")
    private LocalDateTime updatedAt;

    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSS")
    private LocalDateTime lastEdited;

    /**
     * 向量嵌入
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class VectorEmbedding {

        private float[] vector;
        private String model;
    }

    /**
     * 历史记录条目
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class HistoryEntry {

        private String content;
        // HistoryEntry 中的 updatedAt 是 LocalDateTime，这个没问题
        private LocalDateTime updatedAt;
        private String updatedBy;
        private String reason;
    }
}
