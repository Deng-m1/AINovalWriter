package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreatedChapterInfo {
    private String chapterId;
    private String sceneId; // 新增的初始场景ID
    private String generatedSummary;
}