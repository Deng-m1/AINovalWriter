package com.ainovel.server.domain.dto;

import java.util.ArrayList;
import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 解析后的小说数据模型
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ParsedNovelData {

    /**
     * 小说标题
     */
    private String novelTitle;

    /**
     * 解析后的场景列表
     */
    @Builder.Default
    private List<ParsedSceneData> scenes = new ArrayList<>();

    /**
     * 添加场景
     *
     * @param scene 解析后的场景
     * @return this 对象，用于链式调用
     */
    public ParsedNovelData addScene(ParsedSceneData scene) {
        if (scenes == null) {
            scenes = new ArrayList<>();
        }
        scenes.add(scene);
        return this;
    }
}
