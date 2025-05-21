package com.ainovel.server.service.impl;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ainovel.server.common.util.RichTextUtil;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.IndexingService;
import com.ainovel.server.service.KnowledgeService;
import com.ainovel.server.service.NovelService;

import dev.langchain4j.data.document.Document;
import dev.langchain4j.data.document.DocumentSplitter;
import dev.langchain4j.data.document.Metadata;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.embedding.EmbeddingModel;
import dev.langchain4j.store.embedding.EmbeddingStore;
import dev.langchain4j.store.embedding.EmbeddingStoreIngestor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

/**
 * 索引服务实现类 负责处理文档的加载、分割、嵌入和存储
 */
@Slf4j
@Service
public class IndexingServiceImpl implements IndexingService {

    private final NovelService novelService;
    private final SceneRepository sceneRepository;
    private final KnowledgeService knowledgeService;
    private final DocumentSplitter documentSplitter;
    private final EmbeddingModel embeddingModel;
    private final EmbeddingStore<TextSegment> embeddingStore;
    private final EmbeddingStoreIngestor embeddingStoreIngestor;

    // 存储正在进行的索引任务Map
    private final Map<String, Boolean> cancelledIndexingTasks = new ConcurrentHashMap<>();

    // 存储活跃的索引任务线程
    private final Map<String, Thread> indexingThreads = new ConcurrentHashMap<>();

    // 存储活跃的任务取消标记
    private final Map<String, AtomicBoolean> taskCancellations = new ConcurrentHashMap<>();

    @Autowired
    public IndexingServiceImpl(
            NovelService novelService,
            SceneRepository sceneRepository,
            KnowledgeService knowledgeService,
            DocumentSplitter documentSplitter,
            EmbeddingModel embeddingModel,
            EmbeddingStore<TextSegment> embeddingStore,
            EmbeddingStoreIngestor embeddingStoreIngestor) {
        this.novelService = novelService;
        this.sceneRepository = sceneRepository;
        this.knowledgeService = knowledgeService;
        this.documentSplitter = documentSplitter;
        this.embeddingModel = embeddingModel;
        this.embeddingStore = embeddingStore;
        this.embeddingStoreIngestor = embeddingStoreIngestor;
    }

    @Override
    public Mono<Void> indexNovel(String novelId) {
        log.info("开始索引小说：{}", novelId);

        // 确保任务开始时标记为未取消
        cancelledIndexingTasks.put(novelId, false);

        // 创建取消标记
        AtomicBoolean cancelled = new AtomicBoolean(false);
        taskCancellations.put(novelId, cancelled);

        // 创建一个Mono，其中包含一个阻塞操作，将在单独的线程中执行
        return loadNovelDocuments(novelId)
                .flatMap(documents -> {
                    // 检查任务是否被取消
                    if (isCancelled(novelId)) {
                        log.info("小说索引任务已被取消: {}", novelId);
                        return Mono.empty().then();
                    }

                    log.info("为小说 {} 加载了 {} 个文档", novelId, documents.size());

                    // 使用subscribeOn确保在单独的线程上执行，并记录该线程
                    return Mono.<Void>fromRunnable(() -> {
                        // 保存当前线程以便可以中断
                        Thread currentThread = Thread.currentThread();
                        indexingThreads.put(novelId, currentThread);

                        log.info("开始对小说 {} 进行索引处理，线程ID: {}", novelId, currentThread.getId());
                        try {
                            // 循环处理每个文档
                            for (int i = 0; i < documents.size(); i++) {
                                // 定期检查线程中断状态和取消标记
                                if (Thread.currentThread().isInterrupted()) {
                                    log.warn("小说索引任务 {} 线程被中断，停止处理", novelId);
                                    break;
                                }

                                if (isCancelled(novelId)) {
                                    log.warn("小说索引任务 {} 被标记为取消，停止处理", novelId);
                                    break;
                                }

                                if (cancelled.get()) {
                                    log.warn("小说索引任务 {} 收到取消标记，停止处理", novelId);
                                    break;
                                }

                                // 每处理5个文档，检查一次任务是否被取消
                                if (i % 5 == 0) {
                                    if (Thread.currentThread().isInterrupted()) {
                                        log.warn("小说索引任务 {} 线程在处理过程中被中断，停止处理", novelId);
                                        break;
                                    }

                                    if (isCancelled(novelId)) {
                                        log.warn("小说索引任务 {} 在处理过程中被标记为取消，停止处理", novelId);
                                        break;
                                    }

                                    if (cancelled.get()) {
                                        log.warn("小说索引任务 {} 在处理过程中收到取消标记，停止处理", novelId);
                                        break;
                                    }
                                }

                                try {
                                    Document document = documents.get(i);
                                    embeddingStoreIngestor.ingest(document);

                                    // 每处理完一个文档打印进度
                                    if (i % 10 == 0 || i == documents.size() - 1) {
                                        log.info("小说 {} 索引进度: {}/{}", novelId, i + 1, documents.size());
                                    }
                                } catch (Exception e) {
                                    log.error("处理文档时发生错误: {}", e.getMessage(), e);
                                    // 继续处理下一个文档
                                }
                            }
                            log.info("小说 {} 索引处理完成或被中断", novelId);
                        } catch (Exception e) {
                            log.error("索引处理过程中发生错误: {}", e.getMessage(), e);
                        } finally {
                            // 移除线程引用和任务状态
                            cleanupTask(novelId);
                        }
                    })
                            .subscribeOn(Schedulers.boundedElastic())
                            .doOnSubscribe(subscription -> {
                                // 记录订阅已经开始
                                log.info("小说 {} 索引任务已开始订阅", novelId);
                            })
                            .doFinally(signalType -> {
                                // 确保清理资源
                                log.info("小说 {} 索引任务结束，信号类型: {}", novelId, signalType);
                                cleanupTask(novelId);
                            });
                })
                .onErrorResume(e -> {
                    log.error("索引任务发生错误: {}", e.getMessage(), e);
                    // 清理任务状态
                    cleanupTask(novelId);
                    return Mono.empty().then();
                });
    }

    @Override
    public Mono<Void> indexScene(Scene scene) {
        String sceneId = scene.getId();
        String novelId = scene.getNovelId();
        String taskId = novelId + ":" + sceneId;
        log.info("开始索引场景：{}", sceneId);

        // 确保任务开始时标记为未取消
        cancelledIndexingTasks.put(taskId, false);

        // 创建取消标记
        AtomicBoolean cancelled = new AtomicBoolean(false);
        taskCancellations.put(taskId, cancelled);

        return loadSceneDocument(scene)
                .flatMap(document -> {
                    // 检查任务是否被取消
                    if (isCancelled(taskId) || isCancelled(novelId)) {
                        log.info("场景索引任务已被取消: {}", sceneId);
                        return Mono.empty().then();
                    }

                    log.info("为场景 {} 加载了文档", sceneId);

                    // 在单独的线程上执行索引
                    return Mono.<Void>fromRunnable(() -> {
                        // 保存当前线程以便可以中断
                        Thread currentThread = Thread.currentThread();
                        indexingThreads.put(taskId, currentThread);

                        log.info("开始对场景 {} 进行索引处理，线程ID: {}", sceneId, currentThread.getId());
                        try {
                            // 分别检查不同类型的取消信号
                            boolean threadInterrupted = Thread.currentThread().isInterrupted();
                            boolean taskCancelled = isCancelled(taskId);
                            boolean novelCancelled = isCancelled(novelId);
                            boolean flagCancelled = cancelled.get();

                            if (threadInterrupted || taskCancelled || novelCancelled || flagCancelled) {
                                if (threadInterrupted) {
                                    log.warn("场景 {} 索引任务线程被中断", sceneId);
                                }
                                if (taskCancelled) {
                                    log.warn("场景 {} 索引任务被标记为取消", sceneId);
                                }
                                if (novelCancelled) {
                                    log.warn("场景 {} 所属小说的索引任务被标记为取消", sceneId);
                                }
                                if (flagCancelled) {
                                    log.warn("场景 {} 索引任务收到取消标记", sceneId);
                                }
                                log.info("场景 {} 索引任务被取消", sceneId);
                            } else {
                                embeddingStoreIngestor.ingest(document);
                                log.info("场景 {} 索引处理完成", sceneId);
                            }
                        } catch (Exception e) {
                            log.error("场景索引处理过程中发生错误: {}", e.getMessage(), e);
                        } finally {
                            // 移除线程引用和任务状态
                            cleanupTask(taskId);
                        }
                    })
                            .subscribeOn(Schedulers.boundedElastic())
                            .doOnSubscribe(subscription -> {
                                // 记录订阅已经开始
                                log.info("场景 {} 索引任务已开始订阅", sceneId);
                            })
                            .doFinally(signalType -> {
                                // 确保清理资源
                                log.info("场景 {} 索引任务结束，信号类型: {}", sceneId, signalType);
                                cleanupTask(taskId);
                            });
                })
                .onErrorResume(e -> {
                    log.error("场景索引任务发生错误: {}", e.getMessage(), e);
                    // 清理任务状态
                    cleanupTask(taskId);
                    return Mono.empty().then();
                });
    }

    /**
     * 检查指定ID的索引任务是否已被取消
     *
     * @param taskId 任务ID (小说ID或场景专用ID)
     * @return 任务是否已被取消
     */
    public boolean isCancelled(String taskId) {
        return cancelledIndexingTasks.getOrDefault(taskId, false);
    }

    /**
     * 清理任务相关的资源
     */
    private void cleanupTask(String taskId) {
        // 设置取消标记
        AtomicBoolean cancelled = taskCancellations.remove(taskId);
        if (cancelled != null) {
            cancelled.set(true);
            log.info("已设置并移除任务 {} 的取消标记", taskId);
        }

        // 中断线程
        try {
            Thread thread = indexingThreads.remove(taskId);
            if (thread != null && thread.isAlive() && !thread.isInterrupted()) {
                thread.interrupt();
                log.info("任务 {} 的线程已被中断", taskId);
            }
        } catch (Exception e) {
            log.error("中断线程时发生错误: {}", e.getMessage());
        }

        // 移除标记
        cancelledIndexingTasks.remove(taskId);
    }

    /**
     * 取消正在进行的索引任务
     *
     * @param taskId 任务ID (小说ID或场景专用ID)
     * @return 是否成功标记取消
     */
    public boolean cancelIndexingTask(String taskId) {
        log.info("请求取消索引任务: {}", taskId);
        boolean taskExists = false;

        // 尝试取消所有相关联的任务，包括 taskId 和以 taskId: 开头的子任务
        Set<String> tasksToCancel = new HashSet<>();
        tasksToCancel.add(taskId);

        // 查找所有相关任务
        for (String key : new HashSet<>(indexingThreads.keySet())) {
            if (key.startsWith(taskId + ":")) {
                tasksToCancel.add(key);
            }
        }

        // 标记取消并中断所有相关任务
        for (String id : tasksToCancel) {
            // 标记任务为已取消
            if (cancelledIndexingTasks.containsKey(id)) {
                cancelledIndexingTasks.put(id, true);
                taskExists = true;
                log.info("已标记索引任务为取消状态: {}", id);
            }

            // 设置取消标记
            AtomicBoolean cancelled = taskCancellations.get(id);
            if (cancelled != null) {
                cancelled.set(true);
                taskExists = true;
                log.info("已设置任务 {} 的取消标记", id);
            }

            // 尝试中断线程
            Thread thread = indexingThreads.get(id);
            if (thread != null && thread.isAlive() && !thread.isInterrupted()) {
                thread.interrupt();
                log.info("任务 {} 的线程已被中断", id);
                taskExists = true;
            }
        }

        if (!taskExists) {
            log.warn("未找到要取消的索引任务: {}", taskId);
        }

        return taskExists;
    }

    @Override
    public Mono<Void> deleteNovelIndices(String novelId) {
        log.info("删除小说索引：{}", novelId);

        // 这里我们借用已有的KnowledgeService删除功能
        return knowledgeService.deleteKnowledgeChunks(novelId, null, null);
    }

    @Override
    public Mono<Void> deleteSceneIndex(String novelId, String sceneId) {
        log.info("删除场景索引：{}", sceneId);

        // 这里我们借用已有的KnowledgeService删除功能
        return knowledgeService.deleteKnowledgeChunks(novelId, "scene", sceneId);
    }

    @Override
    public Mono<List<Document>> loadNovelDocuments(String novelId) {
        log.info("加载小说文档：{}", novelId);

        return novelService.findNovelById(novelId)
                .flatMap(novel -> {
                    // 加载小说元数据文档
                    Document novelMetadataDoc = createNovelMetadataDocument(novel);

                    // 加载所有场景文档
                    return loadNovelSceneDocuments(novelId)
                            .collectList()
                            .map(sceneDocuments -> {
                                List<Document> allDocuments = new ArrayList<>();
                                allDocuments.add(novelMetadataDoc);
                                allDocuments.addAll(sceneDocuments);
                                return allDocuments;
                            });
                });
    }

    @Override
    public Mono<Document> loadSceneDocument(Scene scene) {
        log.info("加载场景文档：{}", scene.getId());

        // 创建元数据
        Metadata metadata = new Metadata();
        metadata.put("novelId", scene.getNovelId());
        metadata.put("sourceType", "scene");
        metadata.put("sourceId", scene.getId());
        metadata.put("chapterId", scene.getChapterId());
        metadata.put("title", scene.getTitle());
        if (scene.getSceneType() != null) {
            metadata.put("sceneType", scene.getSceneType());
        }

        // 构建文档内容
        StringBuilder content = new StringBuilder();
        content.append("标题: ").append(scene.getTitle()).append("\n\n");
        content.append(RichTextUtil.deltaJsonToPlainText(scene.getContent()));

        // 创建文档
        return Mono.just(Document.from(content.toString(), metadata));
    }

    @Override
    public Flux<Document> loadNovelSceneDocuments(String novelId) {
        log.info("加载小说场景文档：{}", novelId);

        return sceneRepository.findByNovelId(novelId)
                .flatMap(this::loadSceneDocument);
    }

    /**
     * 创建小说元数据文档
     *
     * @param novel 小说对象
     * @return 文档对象
     */
    private Document createNovelMetadataDocument(Novel novel) {
        // 创建元数据
        Metadata metadata = new Metadata();
        metadata.put("novelId", novel.getId());
        metadata.put("sourceType", "novel_metadata");
        metadata.put("sourceId", novel.getId());
        metadata.put("title", novel.getTitle());

        // 构建文档内容
        StringBuilder content = new StringBuilder();
        content.append("标题: ").append(novel.getTitle()).append("\n\n");

        if (novel.getDescription() != null && !novel.getDescription().isEmpty()) {
            content.append("描述: ").append(novel.getDescription()).append("\n\n");
        }

        if (novel.getGenre() != null && !novel.getGenre().isEmpty()) {
            content.append("类型: ").append(String.join(", ", novel.getGenre())).append("\n\n");
        }

        if (novel.getTags() != null && !novel.getTags().isEmpty()) {
            content.append("标签: ").append(String.join(", ", novel.getTags())).append("\n\n");
        }

        // 创建文档
        return Document.from(content.toString(), metadata);
    }
}
