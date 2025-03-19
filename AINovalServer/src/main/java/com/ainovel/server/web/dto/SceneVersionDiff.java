package com.ainovel.server.web.dto;

import lombok.Data;

/**
 * 场景版本差异DTO
 */
@Data
public class SceneVersionDiff {
    private String originalContent;
    private String newContent;
    private String diff;
} 