package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.KnowledgeChunk;
import com.ainovel.server.domain.model.NovelSettingItem;
import com.ainovel.server.domain.model.NovelSettingItem.SettingRelationship;
import com.ainovel.server.domain.model.SettingGroup;
import com.ainovel.server.repository.NovelSettingItemRepository;
import com.ainovel.server.repository.SettingGroupRepository;
import com.ainovel.server.service.EmbeddingService;
import com.ainovel.server.service.KeywordExtractionService;
import com.ainovel.server.service.NovelSettingService;
import com.ainovel.server.service.vectorstore.SearchResult;
import com.ainovel.server.service.vectorstore.VectorStore;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说设定服务实现类
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NovelSettingServiceImpl implements NovelSettingService {

    private final NovelSettingItemRepository settingItemRepository;
    private final SettingGroupRepository settingGroupRepository;
    private final ReactiveMongoTemplate mongoTemplate;
    private final EmbeddingService embeddingService;
    private final VectorStore vectorStore;
    
    // TODO: 需要创建这个服务来提取关键词
    // 暂时设为null以便编译通过，实际上会通过依赖注入注入
    private final KeywordExtractionService keywordExtractionService;
    
    // 默认优先级
    private static final int DEFAULT_PRIORITY = 3;
    
    // ==================== 设定条目管理 ====================
    
    @Override
    public Mono<NovelSettingItem> createSettingItem(NovelSettingItem settingItem) {
        // 设置ID、时间戳等信息
        settingItem.setId(UUID.randomUUID().toString());
        
        LocalDateTime now = LocalDateTime.now();
        settingItem.setCreatedAt(now);
        settingItem.setUpdatedAt(now);
        
        // 设置默认优先级
        if (settingItem.getPriority() == null) {
            settingItem.setPriority(DEFAULT_PRIORITY);
        }
        
        // 设置默认生成来源
        if (settingItem.getGeneratedBy() == null) {
            settingItem.setGeneratedBy("USER");
        }
        
        // 设置关系列表（如果为空）
        if (settingItem.getRelationships() == null) {
            settingItem.setRelationships(new ArrayList<>());
        }
        
        log.info("创建小说设定条目: novelId={}, type={}, name={}", 
                settingItem.getNovelId(), settingItem.getType(), settingItem.getName());
        
        return settingItemRepository.save(settingItem)
                .doOnSuccess(saved -> indexSettingItem(saved).subscribe());
    }
    
    @Override
    public Flux<NovelSettingItem> getNovelSettingItems(String novelId, String type, 
            String name, Integer priority, String generatedBy, String status, Pageable pageable) {
        log.info("查询小说设定条目: novelId={}, type={}, name={}, priority={}, generatedBy={}, status={}", 
                novelId, type, name, priority, generatedBy, status);
        
        // 构建查询条件
        Criteria criteria = Criteria.where("novelId").is(novelId);
        
        if (type != null && !type.isEmpty()) {
            criteria.and("type").is(type);
        }
        
        if (name != null && !name.isEmpty()) {
            criteria.and("name").regex(name, "i"); // 不区分大小写的模糊匹配
        }
        
        if (priority != null) {
            criteria.and("priority").is(priority);
        }
        
        if (generatedBy != null && !generatedBy.isEmpty()) {
            criteria.and("generatedBy").is(generatedBy);
        }
        
        if (status != null && !status.isEmpty()) {
            criteria.and("status").is(status);
        }
        
        Query query = Query.query(criteria);
        
        // 应用分页
        if (pageable != null) {
            query.with(pageable);
        }
        
        return mongoTemplate.find(query, NovelSettingItem.class);
    }
    
    @Override
    public Mono<NovelSettingItem> getSettingItemById(String settingItemId) {
        return settingItemRepository.findById(settingItemId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("设定条目", settingItemId)));
    }
    
    @Override
    public Mono<NovelSettingItem> updateSettingItem(String settingItemId, NovelSettingItem settingItem) {
        return getSettingItemById(settingItemId)
                .flatMap(existing -> {
                    // 保留不可修改的字段
                    settingItem.setId(existing.getId());
                    settingItem.setNovelId(existing.getNovelId());
                    settingItem.setUserId(existing.getUserId());
                    settingItem.setCreatedAt(existing.getCreatedAt());
                    settingItem.setUpdatedAt(LocalDateTime.now());
                    
                    log.info("更新小说设定条目: id={}, novelId={}, type={}, name={}", 
                            settingItemId, settingItem.getNovelId(), settingItem.getType(), settingItem.getName());
                    
                    return settingItemRepository.save(settingItem)
                            .doOnSuccess(saved -> indexSettingItem(saved).subscribe());
                });
    }
    
    @Override
    public Mono<Void> deleteSettingItem(String settingItemId) {
        log.info("删除小说设定条目: id={}", settingItemId);
        
        return getSettingItemById(settingItemId)
                .flatMap(settingItem -> {
                    // 从所有设定组中移除该设定条目
                    return settingGroupRepository.findByNovelId(settingItem.getNovelId())
                            .filter(group -> group.getItemIds() != null && 
                                    group.getItemIds().contains(settingItemId))
                            .flatMap(group -> {
                                group.getItemIds().remove(settingItemId);
                                return settingGroupRepository.save(group);
                            })
                            .then(settingItemRepository.delete(settingItem))
                            .then(deleteSettingItemIndex(settingItem.getNovelId(), settingItemId));
                });
    }
    
    @Override
    public Flux<NovelSettingItem> getSceneSettingItems(String novelId, String sceneId) {
        log.info("获取场景相关设定条目: novelId={}, sceneId={}", novelId, sceneId);
        return settingItemRepository.findByNovelIdAndSceneIdIn(novelId, sceneId);
    }
    
    @Override
    public Mono<NovelSettingItem> acceptSuggestedSettingItem(String settingItemId) {
        return getSettingItemById(settingItemId)
                .flatMap(settingItem -> {
                    if (!"AI_SCENE_SUGGESTION".equals(settingItem.getGeneratedBy()) && 
                            !"AI_GENERAL_SUGGESTION".equals(settingItem.getGeneratedBy())) {
                        return Mono.error(new IllegalArgumentException("只能接受AI生成的设定条目"));
                    }
                    
                    settingItem.setStatus("ACCEPTED");
                    settingItem.setUpdatedAt(LocalDateTime.now());
                    
                    log.info("接受AI建议的设定条目: id={}, novelId={}, type={}, name={}", 
                            settingItemId, settingItem.getNovelId(), settingItem.getType(), settingItem.getName());
                    
                    return settingItemRepository.save(settingItem)
                            .doOnSuccess(saved -> indexSettingItem(saved).subscribe());
                });
    }
    
    @Override
    public Mono<NovelSettingItem> rejectSuggestedSettingItem(String settingItemId) {
        return getSettingItemById(settingItemId)
                .flatMap(settingItem -> {
                    if (!"AI_SCENE_SUGGESTION".equals(settingItem.getGeneratedBy()) && 
                            !"AI_GENERAL_SUGGESTION".equals(settingItem.getGeneratedBy())) {
                        return Mono.error(new IllegalArgumentException("只能拒绝AI生成的设定条目"));
                    }
                    
                    settingItem.setStatus("REJECTED");
                    settingItem.setUpdatedAt(LocalDateTime.now());
                    
                    log.info("拒绝AI建议的设定条目: id={}, novelId={}, type={}, name={}", 
                            settingItemId, settingItem.getNovelId(), settingItem.getType(), settingItem.getName());
                    
                    return settingItemRepository.save(settingItem);
                });
    }
    
    // ==================== 设定关系管理 ====================
    
    @Override
    public Mono<NovelSettingItem> addSettingRelationship(String settingItemId, SettingRelationship relationship) {
        return getSettingItemById(settingItemId)
                .flatMap(settingItem -> {
                    // 验证关联的设定条目是否存在
                    return settingItemRepository.findById(relationship.getTargetItemId())
                            .switchIfEmpty(Mono.error(new ResourceNotFoundException("关联的设定条目", relationship.getTargetItemId())))
                            .flatMap(relatedItem -> {
                                // 确保设定条目属于同一个小说
                                if (!relatedItem.getNovelId().equals(settingItem.getNovelId())) {
                                    return Mono.error(new IllegalArgumentException("只能与同一小说的设定条目建立关系"));
                                }
                                
                                // 确保关系列表已初始化
                                if (settingItem.getRelationships() == null) {
                                    settingItem.setRelationships(new ArrayList<>());
                                }
                                
                                // 检查是否已存在相同的关系
                                boolean relationshipExists = settingItem.getRelationships().stream()
                                        .anyMatch(r -> r.getTargetItemId().equals(relationship.getTargetItemId()));
                                
                                if (relationshipExists) {
                                    return Mono.error(new IllegalArgumentException("已存在与该设定条目的关系"));
                                }
                                
                                // 添加关系
                                settingItem.getRelationships().add(relationship);
                                settingItem.setUpdatedAt(LocalDateTime.now());
                                
                                log.info("添加设定条目关系: fromId={}, toId={}, type={}", 
                                        settingItemId, relationship.getTargetItemId(), relationship.getType());
                                
                                return settingItemRepository.save(settingItem)
                                        .doOnSuccess(saved -> indexSettingItem(saved).subscribe());
                            });
                });
    }
    
    @Override
    public Mono<Void> removeSettingRelationship(String settingItemId, String targetItemId, String relationshipType) {
        return getSettingItemById(settingItemId)
                .flatMap(settingItem -> {
                    if (settingItem.getRelationships() == null || settingItem.getRelationships().isEmpty()) {
                        return Mono.error(new ResourceNotFoundException("设定条目关系", targetItemId));
                    }
                    
                    // 查找并移除关系
                    int initialSize = settingItem.getRelationships().size();
                    List<SettingRelationship> filteredRelationships;
                    
                    if (relationshipType != null && !relationshipType.isEmpty()) {
                        filteredRelationships = settingItem.getRelationships().stream()
                                .filter(r -> !(r.getTargetItemId().equals(targetItemId) && 
                                        r.getType().equals(relationshipType)))
                                .collect(Collectors.toList());
                    } else {
                        filteredRelationships = settingItem.getRelationships().stream()
                                .filter(r -> !r.getTargetItemId().equals(targetItemId))
                                .collect(Collectors.toList());
                    }
                    
                    settingItem.setRelationships(filteredRelationships);
                    
                    if (settingItem.getRelationships().size() == initialSize) {
                        return Mono.error(new ResourceNotFoundException("设定条目关系", targetItemId));
                    }
                    
                    settingItem.setUpdatedAt(LocalDateTime.now());
                    
                    log.info("删除设定条目关系: fromId={}, toId={}", settingItemId, targetItemId);
                    
                    return settingItemRepository.save(settingItem)
                            .doOnSuccess(saved -> indexSettingItem(saved).subscribe())
                            .then();
                });
    }
    

    public Flux<NovelSettingItem> getRelatedSettingItems(String settingItemId) {
        return getSettingItemById(settingItemId)
                .flatMapMany(settingItem -> {
                    if (settingItem.getRelationships() == null || settingItem.getRelationships().isEmpty()) {
                        return Flux.empty();
                    }
                    
                    List<String> relatedItemIds = settingItem.getRelationships().stream()
                            .map(SettingRelationship::getTargetItemId)
                            .collect(Collectors.toList());
                    
                    return settingItemRepository.findAllById(relatedItemIds);
                });
    }
    
    // ==================== 设定组管理 ====================
    
    @Override
    public Mono<SettingGroup> createSettingGroup(SettingGroup settingGroup) {
        // 设置ID、时间戳等信息
        settingGroup.setId(UUID.randomUUID().toString());
        
        LocalDateTime now = LocalDateTime.now();
        settingGroup.setCreatedAt(now);
        settingGroup.setUpdatedAt(now);
        
        // 初始化设定条目ID列表
        if (settingGroup.getItemIds() == null) {
            settingGroup.setItemIds(new ArrayList<>());
        }
        
        // 设置默认激活状态

            settingGroup.setActiveContext(false);

        
        log.info("创建设定组: novelId={}, name={}, isActive={}", 
                settingGroup.getNovelId(), settingGroup.getName(), settingGroup.isActiveContext());
        
        return settingGroupRepository.save(settingGroup);
    }
    
    @Override
    public Flux<SettingGroup> getNovelSettingGroups(String novelId, String name, Boolean isActiveContext) {
        log.info("查询小说设定组: novelId={}, name={}, isActive={}", novelId, name, isActiveContext);
        
        Criteria criteria = Criteria.where("novelId").is(novelId);
        
        if (name != null && !name.isEmpty()) {
            criteria.and("name").regex(name, "i");
        }
        
        if (isActiveContext != null) {
            criteria.and("active").is(isActiveContext);
        }
        
        Query query = Query.query(criteria);
        return mongoTemplate.find(query, SettingGroup.class);
    }
    
    
    @Override
    public Mono<SettingGroup> getSettingGroupById(String groupId) {
        return settingGroupRepository.findById(groupId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("设定组", groupId)));
    }
    
    @Override
    public Mono<SettingGroup> updateSettingGroup(String groupId, SettingGroup settingGroup) {
        return getSettingGroupById(groupId)
                .flatMap(existing -> {
                    // 保留不可修改的字段
                    settingGroup.setId(existing.getId());
                    settingGroup.setNovelId(existing.getNovelId());
                    settingGroup.setUserId(existing.getUserId());
                    settingGroup.setCreatedAt(existing.getCreatedAt());
                    settingGroup.setUpdatedAt(LocalDateTime.now());
                    
                    log.info("更新设定组: id={}, novelId={}, name={}, isActive={}", 
                            groupId, settingGroup.getNovelId(), settingGroup.getName(), settingGroup.isActiveContext());
                    
                    return settingGroupRepository.save(settingGroup);
                });
    }
    
    @Override
    public Mono<Void> deleteSettingGroup(String groupId) {
        log.info("删除设定组: id={}", groupId);
        return settingGroupRepository.deleteById(groupId);
    }
    
    @Override
    public Mono<SettingGroup> addItemToGroup(String groupId, String itemId) {
        log.info("开始处理添加条目到设定组: groupId={}, itemId={}", groupId, itemId);
        
        if (groupId == null || groupId.trim().isEmpty()) {
            log.error("设定组ID为空");
            return Mono.error(new IllegalArgumentException("设定组ID不能为空"));
        }
        
        if (itemId == null || itemId.trim().isEmpty()) {
            log.error("设定条目ID为空");
            return Mono.error(new IllegalArgumentException("设定条目ID不能为空"));
        }
        
        return Mono.zip(
                getSettingGroupById(groupId),
                getSettingItemById(itemId)
            )
            .doOnSuccess(tuple -> {
                SettingGroup group = tuple.getT1();
                NovelSettingItem item = tuple.getT2();
                log.info("找到设定组和设定条目: groupId={}, groupName={}, itemId={}, itemName={}", 
                        group.getId(), group.getName(), item.getId(), item.getName());
            })
            .doOnError(e -> log.error("获取设定组或条目失败: {}", e.getMessage()))
            .flatMap(tuple -> {
                SettingGroup group = tuple.getT1();
                NovelSettingItem item = tuple.getT2();
                
                // 确保设定条目属于同一个小说
                if (!item.getNovelId().equals(group.getNovelId())) {
                    log.error("设定条目和设定组不属于同一小说: itemNovelId={}, groupNovelId={}", 
                            item.getNovelId(), group.getNovelId());
                    return Mono.error(new IllegalArgumentException("只能添加同一小说的设定条目到设定组"));
                }
                
                // 确保设定条目ID列表已初始化
                if (group.getItemIds() == null) {
                    group.setItemIds(new ArrayList<>());
                    log.info("初始化设定组的条目ID列表: groupId={}", groupId);
                }
                
                // 检查是否已存在于组中
                if (group.getItemIds().contains(itemId)) {
                    log.info("设定条目已存在于设定组中: groupId={}, itemId={}", groupId, itemId);
                    return Mono.just(group); // 已存在，无需再添加
                }
                
                // 添加设定条目ID到组
                group.getItemIds().add(itemId);
                group.setUpdatedAt(LocalDateTime.now());
                
                log.info("向设定组添加设定条目: groupId={}, groupName={}, settingItemId={}, itemName={}, 当前组内条目数量: {}", 
                        groupId, group.getName(), itemId, item.getName(), group.getItemIds().size());
                
                return settingGroupRepository.save(group)
                        .doOnSuccess(saved -> {
                            log.info("保存设定组成功，组内条目数量: {}, 条目列表: {}", 
                                    saved.getItemIds().size(), saved.getItemIds());
                            // 更新设定条目的索引以包含组ID信息
                            indexSettingItem(item).subscribe();
                        })
                        .doOnError(e -> log.error("保存设定组失败: {}", e.getMessage()));
            });
    }
    
    
    @Override
    public Mono<Void> removeItemFromGroup(String groupId, String itemId) {
        return getSettingGroupById(groupId)
                .flatMap(group -> {
                    if (group.getItemIds() == null || !group.getItemIds().contains(itemId)) {
                        return Mono.error(new ResourceNotFoundException("设定组中的设定条目", itemId));
                    }
                    
                    // 移除设定条目ID
                    group.getItemIds().remove(itemId);
                    group.setUpdatedAt(LocalDateTime.now());
                    
                    log.info("从设定组移除设定条目: groupId={}, settingItemId={}", groupId, itemId);
                    
                    return settingGroupRepository.save(group)
                            .doOnSuccess(saved -> {
                                // 更新设定条目的索引以移除组ID信息
                                getSettingItemById(itemId)
                                        .flatMap(this::indexSettingItem)
                                        .subscribe();
                            })
                            .then();
                });
    }
    
    
    @Override
    public Mono<SettingGroup> setGroupActiveContext(String groupId, boolean isActive) {
        return getSettingGroupById(groupId)
                .flatMap(group -> {
                    group.setActiveContext(isActive);
                    group.setUpdatedAt(LocalDateTime.now());
                    
                    log.info("切换设定组激活状态: groupId={}, isActive={}", groupId, isActive);
                    
                    return settingGroupRepository.save(group);
                });
    }
    

    
    // ==================== 设定检索 ====================
    

    public Flux<NovelSettingItem> findRelevantSettings(String novelId, String contextText, String currentSceneId, 
            List<String> activeGroupIds, int topK) {
        log.info("检索相关设定: novelId={}, contextLength={}, sceneId={}, activeGroups={}, topK={}", 
                novelId, (contextText != null ? contextText.length() : 0), currentSceneId, activeGroupIds, topK);
        
        // 1. 使用LLM从上下文中提取关键词
        Mono<List<String>> keywordsMono = keywordExtractionService != null ? 
                keywordExtractionService.extractKeywords(contextText) : 
                Mono.just(Collections.emptyList());
        
        // 2. 生成查询向量
        Mono<float[]> queryVectorMono = contextText != null && !contextText.isEmpty() ? 
                embeddingService.generateEmbedding(contextText) : 
                Mono.just(new float[0]);
        
        return Mono.zip(keywordsMono, queryVectorMono)
                .flatMapMany(tuple -> {
                    List<String> keywords = tuple.getT1();
                    float[] queryVector = tuple.getT2();
                    
                    if (queryVector.length == 0) {
                        log.warn("无法生成查询向量，返回空结果");
                        return Flux.empty();
                    }
                    
                    // 构建元数据过滤条件
                    Map<String, Object> filterMetadata = new HashMap<>();
                    filterMetadata.put("novelId", novelId);
                    
                    // 增加关键词过滤（如果有）
                    if (!keywords.isEmpty()) {
                        log.info("使用关键词进行过滤: {}", keywords);
                        filterMetadata.put("keywords", keywords);
                    }
                    
                    // 初步检索，获取比最终所需多一些的结果以便后处理
                    int initialTopK = topK * 2;
                    
                    return vectorStore.search(queryVector, filterMetadata, initialTopK)
                            .flatMap(result -> {
                                String settingItemId = (String) result.getMetadata().get("novelSettingItemId");
                                if (settingItemId == null) {
                                    log.warn("检索结果缺少设定条目ID: {}", result.getMetadata());
                                    return Mono.empty();
                                }
                                return getSettingItemById(settingItemId)
                                       .map(item -> {
                                           // 保存原始相似度分数，用于后续重排序
                                           if (item.getMetadata() == null) {
                                               item.setMetadata(new HashMap<>());
                                           }
                                           item.getMetadata().put("_score", result.getScore());
                                           return item;
                                       });
                            })
                            .collectList()
                            .flatMapMany(initialResults -> {
                                if (initialResults.isEmpty()) {
                                    log.warn("未找到相关设定条目");
                                    return Flux.empty();
                                }
                                
                                log.info("初步检索到 {} 个设定条目", initialResults.size());
                                
                                // 如果有关键词，进行关键词匹配过滤
                                List<NovelSettingItem> filteredResults = initialResults;
                                if (!keywords.isEmpty()) {
                                    filteredResults = initialResults.stream()
                                        .filter(item -> {
                                            // 构建完整文本用于匹配
                                            String fullText = item.getName() + " " + 
                                                             item.getType() + " " + 
                                                             (item.getDescription() != null ? item.getDescription() : "");
                                            
                                            // 检查是否至少匹配一个关键词
                                            return keywords.stream()
                                                    .anyMatch(keyword -> 
                                                        fullText.toLowerCase().contains(keyword.toLowerCase()));
                                        })
                                        .collect(Collectors.toList());
                                    
                                    log.info("关键词过滤后剩余 {} 个设定条目", filteredResults.size());
                                    
                                    // 如果过滤后结果太少，回退到原始结果
                                    if (filteredResults.size() < Math.max(3, topK / 2)) {
                                        log.info("过滤后结果太少，回退到原始结果");
                                        filteredResults = initialResults;
                                    }
                                }
                                
                                // 进行结果优化和重排序
                                List<NovelSettingItem> rerankedResults = reorderResults(
                                        filteredResults, currentSceneId, activeGroupIds);
                                
                                // 选择前topK个结果
                                int resultCount = Math.min(topK, rerankedResults.size());
                                
                                log.info("重排序后返回 {} 个设定条目", resultCount);
                                
                                return Flux.fromIterable(rerankedResults.subList(0, resultCount));
                            });
                });
    }
    
    @Override
    public Flux<NovelSettingItem> extractSettingsFromText(String novelId, String text, String type, String userId) {
        log.info("从文本中提取设定: novelId={}, textLength={}, type={}", novelId, text.length(), type);
        // 实现待完成 - 这可能需要调用LLM来执行实体提取和结构化
        return Flux.empty();
    }
    
    @Override
    public Flux<NovelSettingItem> searchSettingItems(String novelId, String query, List<String> types, 
            List<String> groupIds, Double minScore, Integer maxResults) {
        log.info("搜索设定条目: novelId={}, query={}, types={}, groupIds={}", novelId, query, types, groupIds);
        // 实现待完成 - 这需要使用向量检索和过滤
        return Flux.empty();
    }
    
    @Override
    public Mono<Void> vectorizeAndIndexSettingItem(String itemId) {
        log.info("向量化并索引设定条目: itemId={}", itemId);
        return getSettingItemById(itemId)
                .flatMap(this::indexSettingItem)
                .then();
    }
    
    // ==================== 辅助方法 ====================
    
    /**
     * 索引设定条目
     */
    private Mono<Void> indexSettingItem(NovelSettingItem settingItem) {
        log.info("为设定条目创建索引: id={}, novelId={}, type={}, name={}", 
                settingItem.getId(), settingItem.getNovelId(), settingItem.getType(), settingItem.getName());
        
        return Mono.fromCallable(() -> {
            // 准备索引内容
            StringBuilder contentBuilder = new StringBuilder();
            contentBuilder.append("名称: ").append(settingItem.getName()).append("\n");
            contentBuilder.append("类型: ").append(settingItem.getType()).append("\n");
            contentBuilder.append("内容: ").append(settingItem.getDescription()).append("\n");
            
            // 添加属性信息
            if (settingItem.getAttributes() != null && !settingItem.getAttributes().isEmpty()) {
                contentBuilder.append("属性:\n");
                settingItem.getAttributes().forEach((key, value) -> {
                    contentBuilder.append(key).append(": ").append(value).append("\n");
                });
            }
            
            String indexContent = contentBuilder.toString();
            
            // 提取关键词
            return keywordExtractionService != null ? 
                keywordExtractionService.extractKeywords(indexContent, 30) : 
                Mono.just(Collections.emptyList())
                .flatMap(keywords -> {
                    // 准备元数据
                    Map<String, Object> metadata = new HashMap<>();
                    metadata.put("novelId", settingItem.getNovelId());
                    metadata.put("novelSettingItemId", settingItem.getId());
                    
                    if (settingItem.getSceneIds() != null && !settingItem.getSceneIds().isEmpty()) {
                        metadata.put("sceneId", settingItem.getSceneIds().get(0)); // 使用第一个场景ID
                    }
                    
                    metadata.put("settingType", settingItem.getType());
                    metadata.put("settingName", settingItem.getName());
                    metadata.put("priority", settingItem.getPriority());
                    metadata.put("generatedBy", settingItem.getGeneratedBy());
                    
                    // 添加关键词到元数据
                    if (!keywords.isEmpty()) {
                        metadata.put("keywords", keywords);
                        log.info("为设定条目提取到的关键词: id={}, keywords={}", settingItem.getId(), keywords);
                    }
                    
                    if (settingItem.getStatus() != null) {
                        metadata.put("status", settingItem.getStatus());
                    }
                    
                    // 添加关联的设定条目ID信息
                    if (settingItem.getRelationships() != null && !settingItem.getRelationships().isEmpty()) {
                        List<String> relatedIds = settingItem.getRelationships().stream()
                                .map(SettingRelationship::getTargetItemId)
                                .collect(Collectors.toList());
                        metadata.put("relatedNovelSettingItemIds", relatedIds);
                    }
                    
                    // 找出该设定条目所属的所有设定组
                    return settingGroupRepository.findByNovelId(settingItem.getNovelId())
                            .filter(group -> group.getItemIds() != null && 
                                    group.getItemIds().contains(settingItem.getId()))
                            .map(SettingGroup::getId)
                            .collectList()
                            .flatMap(groupIds -> {
                                if (!groupIds.isEmpty()) {
                                    metadata.put("groupIds", groupIds);
                                }
                                
                                // 生成向量嵌入
                                return embeddingService.generateEmbedding(indexContent)
                                        .flatMap(vector -> {
                                            // 创建并保存知识块
                                            KnowledgeChunk chunk = new KnowledgeChunk();
                                            chunk.setId(UUID.randomUUID().toString());
                                            chunk.setNovelId(settingItem.getNovelId());
                                            chunk.setSourceType("setting");
                                            chunk.setSourceId(settingItem.getId());
                                            chunk.setContent(indexContent);
                                            chunk.setMetadata(metadata);
                                            
                                            KnowledgeChunk.VectorEmbedding embedding = new KnowledgeChunk.VectorEmbedding();
                                            embedding.setVector(vector);
                                            embedding.setDimension(vector.length);
                                            embedding.setModel("text-embedding-3-small"); // 默认模型名称
                                            chunk.setVectorEmbedding(embedding);
                                            
                                            return vectorStore.storeKnowledgeChunk(chunk);
                                        });
                            });
                });
        })
        .flatMap(mono -> mono)
        .onErrorResume(e -> {
            log.error("索引设定条目时出错: id={}, error={}", settingItem.getId(), e.getMessage(), e);
            return Mono.empty();
        })
        .subscribeOn(reactor.core.scheduler.Schedulers.boundedElastic())
        .then();
    }
    
    /**
     * 删除设定条目的索引
     */
    private Mono<Void> deleteSettingItemIndex(String novelId, String settingItemId) {
        log.info("删除设定条目索引: novelId={}, settingItemId={}", novelId, settingItemId);
        
        return vectorStore.deleteBySourceId(novelId, "setting", settingItemId)
                .onErrorResume(e -> {
                    log.error("删除设定条目索引时出错: settingItemId={}, error={}", settingItemId, e.getMessage(), e);
                    return Mono.empty();
                });
    }
    
    /**
     * 重新排序检索结果
     */
    private List<NovelSettingItem> reorderResults(List<NovelSettingItem> items, 
            String currentSceneId, List<String> activeGroupIds) {
        // 使用得分系统对结果进行重排序
        return items.stream()
                .map(item -> {
                    double score = calculateItemScore(item, currentSceneId, activeGroupIds);
                    return Map.entry(item, score);
                })
                .sorted((e1, e2) -> Double.compare(e2.getValue(), e1.getValue())) // 降序排序
                .map(Map.Entry::getKey)
                .collect(Collectors.toList());
    }
    
    /**
     * 计算设定条目的得分
     * 综合考虑优先级、当前场景相关性、设定组激活状态等因素
     */
    private double calculateItemScore(NovelSettingItem item, String currentSceneId, List<String> activeGroupIds) {
        double score = 0.0;
        
        // 如果有向量搜索得分，添加到总分中 (0.0-1.0范围)
        if (item.getMetadata() != null && item.getMetadata().containsKey("_score")) {
            try {
                double vectorScore = ((Number) item.getMetadata().get("_score")).doubleValue();
                // 向量搜索得分通常是0-1范围内的值，可能需要根据实际情况调整权重
                score += vectorScore * 0.5; // 赋予50%的权重
                log.debug("添加向量相似度得分: itemId={}, vectorScore={}", item.getId(), vectorScore);
            } catch (Exception e) {
                log.warn("无法解析向量相似度得分: {}", e.getMessage());
            }
        }
        
        // 基于优先级的得分（优先级越高，得分越高）
        // 优先级从1到5，1为最高
        if (item.getPriority() != null) {
            // 转换为0-1范围的得分，优先级1得1分，优先级5得0.2分
            double priorityScore = (6 - item.getPriority()) / 5.0;
            score += priorityScore * 0.3; // 赋予30%的权重
        }
        
        // 当前场景相关性得分
        if (currentSceneId != null && item.getSceneIds() != null && item.getSceneIds().contains(currentSceneId)) {
            score += 0.5; // 与当前场景直接相关的设定条目额外加分
        }
        
        // 设定组激活状态得分
        if (activeGroupIds != null && !activeGroupIds.isEmpty()) {
            // 获取该设定条目所属的所有设定组
            // 这里假设我们已经在元数据中查询到了组ID，如果实际使用需要改为数据库查询
            // 这里是简化实现
            settingGroupRepository.findByNovelId(item.getNovelId())
                    .filter(group -> group.getItemIds() != null && 
                            group.getItemIds().contains(item.getId()))
                    .map(SettingGroup::getId)
                    .filter(activeGroupIds::contains)
                    .count()
                    .subscribe(count -> {
                        // 如果设定条目属于激活的设定组，给予额外得分
                        if (count > 0) {
                            // 这里无法直接修改外部的score变量，实际实现需要调整
                        }
                    });
        }
        
        // 生成源和状态得分
        if ("USER".equals(item.getGeneratedBy())) {
            score += 0.2; // 用户创建的设定条目更可信
        } else if ("AI_SCENE_SUGGESTION".equals(item.getGeneratedBy()) || 
                "AI_GENERAL_SUGGESTION".equals(item.getGeneratedBy())) {
            if ("ACCEPTED".equals(item.getStatus())) {
                score += 0.15; // 已接受的AI建议
            } else if ("SUGGESTED".equals(item.getStatus())) {
                score += 0.05; // 未审核的AI建议
            }
            // REJECTED的不加分
        }
        
        return score;
    }
} 