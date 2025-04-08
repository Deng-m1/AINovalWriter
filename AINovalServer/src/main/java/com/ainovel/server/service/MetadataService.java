package com.ainovel.server.service;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;

import reactor.core.publisher.Mono;

/**
 * 元数据服务接口 负责处理与元数据相关的操作，如字数统计、阅读时间计算等
 */
public interface MetadataService {

    /**
     * 计算文本内容的字数
     *
     * @param content 文本内容
     * @return 字数统计
     */
    int calculateWordCount(String content);

    /**
     * 计算并更新场景的元数据（包括字数统计）
     *
     * @param scene 场景对象
     * @return 更新后的场景
     */
    Scene updateSceneMetadata(Scene scene);

    /**
     * 计算并更新小说的元数据（如总字数、阅读时间等）
     *
     * @param novelId 小说ID
     * @return 更新后的小说
     */
    Mono<Novel> updateNovelMetadata(String novelId);

    /**
     * 根据场景内容变更触发小说元数据更新
     *
     * @param scene 已更新的场景
     * @return 操作完成指示
     */
    Mono<Void> triggerNovelMetadataUpdate(Scene scene);
}
