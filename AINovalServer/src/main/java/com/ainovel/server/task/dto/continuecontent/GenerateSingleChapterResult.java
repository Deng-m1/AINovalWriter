package com.ainovel.server.task.dto.continuecontent;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GenerateSingleChapterResult implements Serializable {
    private String generatedChapterId;
    private String generatedInitialSceneId;
    private String generatedSummary;
    private boolean contentGenerated;
    private boolean contentPersisted;
    private int chapterIndex;
    // Optional: Add content snippet if needed, but might be large
} 