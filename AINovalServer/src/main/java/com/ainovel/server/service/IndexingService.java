package com.ainovel.server.service;

import java.util.List;

import com.ainovel.server.domain.model.Scene;

import dev.langchain4j.data.document.Document;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 索引服务接口 负责处理文档的加载、分割、嵌入和存储
 */
public interface IndexingService {

    /**
     * 为小说索引所有内容 包括场景、角色、设定等
     *
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> indexNovel(String novelId);

    /**
     * 索引单个场景
     *
     * @param scene 场景对象
     * @return 操作结果
     */
    Mono<Void> indexScene(Scene scene);

    /**
     * 删除小说的所有索引
     *
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteNovelIndices(String novelId);

    /**
     * 删除场景的索引
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @return 操作结果
     */
    Mono<Void> deleteSceneIndex(String novelId, String sceneId);

    /**
     * 加载小说文档
     *
     * @param novelId 小说ID
     * @return 文档列表
     */
    Mono<List<Document>> loadNovelDocuments(String novelId);

    /**
     * 加载场景文档
     *
     * @param scene 场景对象
     * @return 文档对象
     */
    Mono<Document> loadSceneDocument(Scene scene);

    /**
     * 加载小说的所有场景文档
     *
     * @param novelId 小说ID
     * @return 场景文档流
     */
    Flux<Document> loadNovelSceneDocuments(String novelId);

    /**
     * 取消正在进行的索引任务
     *
     * @param taskId 任务ID (通常是小说ID或者小说ID:场景ID的格式)
     * @return 是否成功标记为取消
     */
    boolean cancelIndexingTask(String taskId);
}
