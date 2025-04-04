package com.ainovel.server.service.vectorstore;

import java.util.List;
import java.util.Map;

import com.ainovel.server.domain.model.KnowledgeChunk;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 向量存储接口 提供向量存储和检索功能
 */
public interface VectorStore {



    /**
     * 存储向量
     *
     * @param content 内容文本
     * @param vector 向量数据
     * @param metadata 元数据
     * @return 存储ID
     */
    Mono<String> storeVector(String content, float[] vector, Map<String, Object> metadata);

    /**
     * 批量存储向量
     *
     * @param vectorDataList 向量数据列表
     * @return 存储ID列表
     */
    Mono<List<String>> storeVectorsBatch(List<VectorData> vectorDataList);

    /**
     * 存储知识块
     *
     * @param chunk 知识块
     * @return 存储ID
     */
    Mono<String> storeKnowledgeChunk(KnowledgeChunk chunk);

    /**
     * 搜索向量
     *
     * @param queryVector 查询向量
     * @param limit 限制数量
     * @return 搜索结果
     */
    Flux<SearchResult> search(float[] queryVector, int limit);

    /**
     * 搜索向量（带过滤条件）
     *
     * @param queryVector 查询向量
     * @param filter 过滤条件
     * @param limit 限制数量
     * @return 搜索结果
     */
    Flux<SearchResult> search(float[] queryVector, Map<String, Object> filter, int limit);

    /**
     * 按小说ID搜索向量
     *
     * @param queryVector 查询向量
     * @param novelId 小说ID
     * @param limit 限制数量
     * @return 搜索结果
     */
    Flux<SearchResult> searchByNovelId(float[] queryVector, String novelId, int limit);

    /**
     * 删除小说的所有向量
     *
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteByNovelId(String novelId);

    /**
     * 删除源的所有向量
     *
     * @param novelId 小说ID
     * @param sourceType 源类型
     * @param sourceId 源ID
     * @return 操作结果
     */
    Mono<Void> deleteBySourceId(String novelId, String sourceType, String sourceId);

    /**
     * 向量数据类
     */
    class VectorData {

        private final String content;
        private final float[] vector;
        private final Map<String, Object> metadata;

        public VectorData(String content, float[] vector, Map<String, Object> metadata) {
            this.content = content;
            this.vector = vector;
            this.metadata = metadata;
        }

        public String getContent() {
            return content;
        }

        public float[] getVector() {
            return vector;
        }

        public Map<String, Object> getMetadata() {
            return metadata;
        }
    }
}
