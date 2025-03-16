package com.ainovel.server.web.dto;

import com.ainovel.server.domain.model.Scene;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 章节场景数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChapterSceneDto {
    private String novelId;
    private String chapterId;
    private Scene scene;
}