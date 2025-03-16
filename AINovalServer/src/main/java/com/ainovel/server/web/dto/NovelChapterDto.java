package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说章节数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class NovelChapterDto {
    private String novelId;
    private String chapterId;
}