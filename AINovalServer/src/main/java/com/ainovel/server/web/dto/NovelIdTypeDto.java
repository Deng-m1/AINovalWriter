package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 包含小说ID和类型的数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class NovelIdTypeDto {
    private String novelId;
    private String type;
}