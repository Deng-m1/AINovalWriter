package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 包含章节ID的数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChapterIdDto {
    private String chapterId;
}