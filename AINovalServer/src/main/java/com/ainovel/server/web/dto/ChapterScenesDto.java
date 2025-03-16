package com.ainovel.server.web.dto;

import java.util.List;

import com.ainovel.server.domain.model.Scene;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 章节场景列表数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChapterScenesDto {
    private String novelId;
    private String chapterId;
    private List<Scene> scenes;
}