package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说ID数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class NovelIdDto {

    /**
     * 小说ID
     */
    private String novelId;
}
