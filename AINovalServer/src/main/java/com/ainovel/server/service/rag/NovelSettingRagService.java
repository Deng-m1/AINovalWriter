package com.ainovel.server.service.rag;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.KnowledgeChunk;
import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.domain.model.SettingGroup;
import com.ainovel.server.service.EmbeddingService;
import com.ainovel.server.service.KnowledgeService;
import com.ainovel.server.service.NovelSettingService;
import com.ainovel.server.service.vectorstore.SearchResult;
import com.ainovel.server.service.vectorstore.VectorStore;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说设定RAG服务
 * 负责整合小说设定到RAG系统，提供知识检索和向量化服务
 */
@Slf4j
@Service
public class NovelSettingRagService {

    private final NovelSettingService novelSettingService;
    private final EmbeddingService embeddingService;
    private final VectorStore vectorStore;
    
    // 知识库命名空间前缀
    private static final String NAMESPACE_PREFIX = "novel_setting_";
    
    @Autowired
    public NovelSettingRagService(
            NovelSettingService novelSettingService,
            EmbeddingService embeddingService,
            VectorStore vectorStore) {
        this.novelSettingService = novelSettingService;
        this.embeddingService = embeddingService;
        this.vectorStore = vectorStore;
    }
    
    /**
     * 为小说的所有设定条目创建和更新向量索引
     * 
     * @param novelId 小说ID
     * @return 处理结果
     */
    public Mono<Void> indexAllNovelSettings(String novelId) {
        log.info("开始索引小说 {} 的所有设定条目", novelId);
        
        // 获取小说的所有设定条目
        return novelSettingService.getNovelSettingItems(novelId, null, null, null, null, null, null)
                .flatMap(this::vectorizeAndStoreSettingItem)
                .then()
                .doOnSuccess(v -> log.info("小说 {} 的设定条目索引完成", novelId));
    }
    
    /**
     * 向量化单个设定条目并存储
     * 
     * @param settingItem 设定条目
     * @return 操作结果
     */
    public Mono<String> vectorizeAndStoreSettingItem(NovelSettingItem settingItem) {
        log.debug("向量化设定条目: {}", settingItem.getName());
        
        // 生成设定条目的文本表示
        String settingText = generateSettingText(settingItem);
        
        // 向量化文本
        return embeddingService.generateEmbedding(settingText)
                .flatMap(embedding -> {
                    // 创建元数据
                    Map<String, Object> metadata = Map.of(
                            "id", settingItem.getId(),
                            "novelId", settingItem.getNovelId(),
                            "sourceType", "novel_setting",
                            "sourceId", settingItem.getId(),
                            "type", settingItem.getType(),
                            "priority", settingItem.getPriority() != null ? settingItem.getPriority() : 5,
                            "status", settingItem.getStatus() != null ? settingItem.getStatus() : "active"
                    );
                    
                    // 存储到向量存储
                    return vectorStore.storeVector(settingText, embedding, metadata);
                })
                .doOnError(e -> log.error("向量化设定条目失败: {}", e.getMessage(), e));
    }
    
    /**
     * 检索与查询相关的设定条目
     * 
     * @param novelId 小说ID
     * @param query 查询文本
     * @param types 设定类型列表 (可选)
     * @param activeGroupIds 激活的设定组ID列表 (可选)
     * @param minScore 最小相似度分数 (可选)
     * @param limit 结果数量限制 (可选)
     * @return 相关的设定条目列表
     */
    public Flux<NovelSettingItem> retrieveRelevantSettings(
            String novelId,
            String query,
            List<String> types,
            List<String> activeGroupIds,
            Double minScore,
            Integer limit) {
        
        log.info("检索小说 {} 的相关设定，查询: {}", novelId, query);
        
        // 设置默认值
        double finalMinScore = minScore != null ? minScore : 0.6;
        int finalLimit = limit != null ? limit : 10;
        
        // 如果有激活的设定组，先获取这些组中的设定条目ID
        Mono<List<String>> groupItemIdsMono;
        if (activeGroupIds != null && !activeGroupIds.isEmpty()) {
            groupItemIdsMono = Flux.fromIterable(activeGroupIds)
                    .flatMap(novelSettingService::getSettingGroupById)
                    .flatMapIterable(SettingGroup::getItemIds)
                    .collect(Collectors.toList());
        } else {
            groupItemIdsMono = Mono.just(Collections.emptyList());
        }
        
        // 向量化查询
        return embeddingService.generateEmbedding(query)
                .flatMapMany(queryVector -> {
                    // 使用向量存储搜索相关内容
                    return vectorStore.searchByNovelId(queryVector, novelId, finalLimit * 2)
                            .filter(result -> result.getScore() >= finalMinScore)
                            .flatMap(result -> {
                                // 获取设定条目ID
                                String settingId = (String) result.getMetadata().get("sourceId");
                                if (settingId == null) {
                                    return Mono.empty();
                                }
                                // 加载设定条目
                                return novelSettingService.getSettingItemById(settingId)
                                        .map(item -> {
                                            // 添加相似度分数
                                            if (item.getMetadata() == null) {
                                                item.setMetadata(Map.of("similarityScore", result.getScore()));
                                            } else {
                                                item.getMetadata().put("similarityScore", result.getScore());
                                            }
                                            return item;
                                        });
                            });
                })
                // 应用可选的设定类型过滤
                .filter(item -> types == null || types.isEmpty() || types.contains(item.getType()))
                // 与激活的设定组条目进行交集处理
                .filterWhen(item -> {
                    if (activeGroupIds == null || activeGroupIds.isEmpty()) {
                        return Mono.just(true);
                    }
                    return groupItemIdsMono.map(groupItemIds -> 
                            groupItemIds.isEmpty() || groupItemIds.contains(item.getId()));
                })
                // 按优先级和相似度排序
                .sort((item1, item2) -> {
                    int priority1 = item1.getPriority() != null ? item1.getPriority() : 5;
                    int priority2 = item2.getPriority() != null ? item2.getPriority() : 5;
                    
                    // 先按优先级降序
                    if (priority1 != priority2) {
                        return Integer.compare(priority2, priority1);
                    }
                    
                    // 再按相似度降序
                    Double score1 = (Double) item1.getMetadata().getOrDefault("similarityScore", 0.0);
                    Double score2 = (Double) item2.getMetadata().getOrDefault("similarityScore", 0.0);
                    return Double.compare(score2, score1);
                })
                // 应用限制
                .take(finalLimit)
                .doOnComplete(() -> log.info("小说 {} 的设定检索完成", novelId));
    }
    
    /**
     * 检索与上下文相关的设定条目，用于AI生成
     * 
     * @param novelId 小说ID
     * @param contextText 上下文文本
     * @param limit 结果数量限制
     * @return 相关的设定条目
     */
    public Flux<NovelSettingItem> retrieveContextualSettings(
            String novelId, String contextText, int limit) {
        
        // 获取该小说的激活设定组
        return novelSettingService.getNovelSettingGroups(novelId, null, true)
                .map(SettingGroup::getId)
                .collect(Collectors.toList())
                .flatMapMany(activeGroupIds -> 
                    retrieveRelevantSettings(novelId, contextText, null, activeGroupIds, 0.5, limit)
                );
    }
    
    /**
     * 为AI生成格式化设定条目列表文本
     * 
     * @param items 设定条目列表
     * @return 格式化的设定文本
     */
    public String formatSettingsForAI(List<NovelSettingItem> items) {
        if (items == null || items.isEmpty()) {
            return "";
        }
        
        StringBuilder sb = new StringBuilder();
        sb.append("## 相关设定\n\n");
        
        // 按类型分组
        Map<String, List<NovelSettingItem>> itemsByType = items.stream()
                .collect(Collectors.groupingBy(NovelSettingItem::getType));
        
        // 遍历每个类型
        for (Map.Entry<String, List<NovelSettingItem>> entry : itemsByType.entrySet()) {
            String type = entry.getKey();
            List<NovelSettingItem> typeItems = entry.getValue();
            
            sb.append("### ").append(type).append("\n\n");
            
            // 遍历该类型的所有条目
            for (NovelSettingItem item : typeItems) {
                sb.append("- **").append(item.getName()).append("**: ");
                sb.append(item.getDescription()).append("\n");
                
                // 添加重要属性
                if (item.getAttributes() != null && !item.getAttributes().isEmpty()) {
                    sb.append("  - 属性: ");
                    List<String> attrStrings = new ArrayList<>();
                    for (Map.Entry<String, String> attr : item.getAttributes().entrySet()) {
                        attrStrings.add(attr.getKey() + ": " + attr.getValue());
                    }
                    sb.append(String.join(", ", attrStrings)).append("\n");
                }
            }
            sb.append("\n");
        }
        
        return sb.toString();
    }
    
    /**
     * 生成设定条目的文本表示
     * 
     * @param item 设定条目
     * @return 文本表示
     */
    private String generateSettingText(NovelSettingItem item) {
        StringBuilder sb = new StringBuilder();
        
        // 添加名称和类型
        sb.append("名称: ").append(item.getName()).append("\n");
        sb.append("类型: ").append(item.getType()).append("\n");
        
        // 添加描述
        if (item.getDescription() != null && !item.getDescription().isEmpty()) {
            sb.append("描述: ").append(item.getDescription()).append("\n");
        }
        
        // 添加属性
        if (item.getAttributes() != null && !item.getAttributes().isEmpty()) {
            sb.append("属性:\n");
            for (Map.Entry<String, String> attr : item.getAttributes().entrySet()) {
                sb.append("  - ").append(attr.getKey()).append(": ")
                  .append(attr.getValue()).append("\n");
            }
        }
        
        // 添加标签
        if (item.getTags() != null && !item.getTags().isEmpty()) {
            sb.append("标签: ").append(String.join(", ", item.getTags())).append("\n");
        }
        
        // 添加关系
        if (item.getRelationships() != null && !item.getRelationships().isEmpty()) {
            sb.append("关系:\n");
            for (NovelSettingItem.SettingRelationship rel : item.getRelationships()) {
                sb.append("  - ").append(rel.getType()).append(": ")
                  .append("[ID: ").append(rel.getTargetItemId()).append("]");
                
                if (rel.getDescription() != null && !rel.getDescription().isEmpty()) {
                    sb.append(" - ").append(rel.getDescription());
                }
                sb.append("\n");
            }
        }
        
        return sb.toString();
    }
    
    /**
     * 获取小说设定的命名空间
     * 
     * @param novelId 小说ID
     * @return 命名空间
     */
    private String getNamespace(String novelId) {
        return NAMESPACE_PREFIX + novelId;
    }
} 