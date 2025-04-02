package com.ainovel.server.web.dto;

import com.ainovel.server.domain.model.Novel;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 小说更新数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class NovelUpdateDto {
    private String id;
    private Novel novel;
}