package com.ainovel.server.service.impl;

import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

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

        return loadNovelDocuments(novelId)
                .flatMap(documents -> {
                    log.info("为小说 {} 加载了 {} 个文档", novelId, documents.size());

                    // 使用EmbeddingStoreIngestor进行文档处理和存储
                    for (Document document : documents) {
                        embeddingStoreIngestor.ingest(document);
                    }

                    return Mono.empty();
                });
    }

    @Override
    public Mono<Void> indexScene(Scene scene) {
        log.info("开始索引场景：{}", scene.getId());

        return loadSceneDocument(scene)
                .flatMap(document -> {
                    log.info("为场景 {} 加载了文档", scene.getId());

                    // 使用EmbeddingStoreIngestor进行文档处理和存储
                    embeddingStoreIngestor.ingest(document);

                    return Mono.empty();
                });
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
        content.append(scene.getContent());

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
