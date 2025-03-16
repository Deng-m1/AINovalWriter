package com.ainovel.server.web.dto;

import com.ainovel.server.domain.model.Scene;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 场景更新数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SceneUpdateDto {
    private String id;
    private Scene scene;
}