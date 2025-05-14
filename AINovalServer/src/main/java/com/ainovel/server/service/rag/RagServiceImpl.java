package com.ainovel.server.service.rag;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.AIFeatureType;
import com.ainovel.server.domain.model.KnowledgeChunk;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.service.KnowledgeService;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;

import dev.langchain4j.rag.content.Content;
import dev.langchain4j.rag.content.retriever.ContentRetriever;
import dev.langchain4j.rag.query.Query;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import com.ainovel.server.common.util.PromptUtil;

/**
 * RAG服务实现类 提供基于检索增强生成的上下文获取服务
 */
@Slf4j
@Service
public class RagServiceImpl implements RagService {

    private final NovelService novelService;
    private final SceneService sceneService;
    private final KnowledgeService knowledgeService;
    private final ContentRetriever contentRetriever;

    @Value("${ainovel.ai.rag.retrieval-k:5}")
    private int retrievalK;

    @Autowired
    public RagServiceImpl(
            NovelService novelService,
            SceneService sceneService,
            KnowledgeService knowledgeService,
            ContentRetriever contentRetriever) {
        this.novelService = novelService;
        this.sceneService = sceneService;
        this.knowledgeService = knowledgeService;
        this.contentRetriever = contentRetriever;
    }

    @Override
    public Mono<String> retrieveRelevantContext(String novelId, String contextId, AIFeatureType featureType) {
        return retrieveRelevantContext(novelId, contextId, null, featureType);
    }

    @Override
    public Mono<String> retrieveRelevantContext(String novelId, String contextId, Object positionHint, AIFeatureType featureType) {
        log.info("开始检索相关上下文, novelId: {}, contextId: {}, featureType: {}", novelId, contextId, featureType);

        // 构建查询文本
        return buildQueryText(novelId, contextId, positionHint, featureType)
                .flatMap(queryText -> {
                    log.debug("构建的查询文本: {}", queryText);

                    // 使用两种检索方法并行执行
                    Mono<String> vectorSearchMono = performVectorSearch(queryText, novelId);
                    Mono<String> metadataSearchMono = retrieveMetadata(novelId, contextId, featureType);

                    // 合并两种检索结果
                    return Mono.zip(vectorSearchMono, metadataSearchMono)
                            .map(tuple -> {
                                String vectorSearchResult = tuple.getT1();
                                String metadataResult = tuple.getT2();

                                StringBuilder contextBuilder = new StringBuilder();
                                if (!metadataResult.isEmpty()) {
                                    contextBuilder.append("## 小说信息\n").append(metadataResult).append("\n\n");
                                }
                                if (!vectorSearchResult.isEmpty()) {
                                    contextBuilder.append("## 相关内容\n").append(vectorSearchResult);
                                }

                                return contextBuilder.toString().trim();
                            });
                })
                .onErrorResume(e -> {
                    log.error("检索上下文时出错", e);
                    return Mono.just("无法获取相关上下文信息。");
                });
    }

    /**
     * 根据功能类型和上下文构建查询文本
     */
    private Mono<String> buildQueryText(String novelId, String contextId, Object positionHint, AIFeatureType featureType) {
        if (featureType == AIFeatureType.SCENE_TO_SUMMARY && contextId != null) {
            // 为场景生成摘要构建查询文本
            return sceneService.findSceneById(contextId)
                    .map(scene -> {
                        // 使用场景内容前100个字符作为查询
                        String content = scene.getContent();
                        String queryPrefix = content.length() > 100
                                ? content.substring(0, 100)
                                : content;
                        return "小说场景: " + queryPrefix + "...";
                    })
                    .defaultIfEmpty("小说场景内容");
        } else if (featureType == AIFeatureType.SUMMARY_TO_SCENE) {
            // 为摘要生成场景构建查询文本
            if (positionHint instanceof String && !((String) positionHint).isEmpty()) {
                return Mono.just("小说摘要: " + positionHint);
            } else {
                return novelService.findNovelById(novelId)
                        .map(novel -> "小说: " + novel.getTitle() + " 类型: " + novel.getGenre());
            }
        } else {
            // 默认查询文本
            return Mono.just("小说ID: " + novelId);
        }
    }

    /**
     * 执行向量搜索
     */
    private Mono<String> performVectorSearch(String queryText, String novelId) {
        return Mono.fromCallable(() -> {
            try {
                // 使用LangChain4j的ContentRetriever进行向量搜索
                List<Content> relevantContents = contentRetriever.retrieve(Query.from(queryText));

                if (relevantContents.isEmpty()) {
                    log.info("向量搜索未找到相关内容");
                    return "";
                }

                log.info("向量搜索找到 {} 个相关内容", relevantContents.size());

                // 格式化检索到的内容 - 在这里转换为纯文本
                return relevantContents.stream()
                        .map(content -> PromptUtil.extractPlainTextFromRichText(content.textSegment().text())) // 转换为纯文本
                        .filter(plainText -> plainText != null && !plainText.isBlank()) // 过滤空结果
                        .collect(Collectors.joining("\n\n"));
            } catch (Exception e) {
                log.error("执行向量搜索时出错", e);
                return "";
            }
        })
        .subscribeOn(Schedulers.boundedElastic())
        .switchIfEmpty(Mono.defer(() -> 
            // 如果向量搜索失败，回退到传统检索
            knowledgeService.semanticSearch(queryText, novelId, retrievalK)
            .map(chunk -> PromptUtil.extractPlainTextFromRichText(chunk.getContent())) // 转换为纯文本
            .filter(plainText -> plainText != null && !plainText.isBlank()) // 过滤空结果
            .collectList()
            .map(contents -> {
                if (contents.isEmpty()) {
                    return "";
                }
                return String.join("\n\n", contents);
            })
            .defaultIfEmpty("")
        ));
    }

    /**
     * 检索元数据
     */
    private Mono<String> retrieveMetadata(String novelId, String contextId, AIFeatureType featureType) {
        if (featureType == AIFeatureType.SCENE_TO_SUMMARY) {
            // 为场景生成摘要检索元数据
            return novelService.findNovelById(novelId)
                    .map(novel -> {
                        StringBuilder metadata = new StringBuilder();
                        metadata.append("标题: ").append(novel.getTitle()).append("\n");
                        metadata.append("类型: ").append(novel.getGenre()).append("\n");
                        if (novel.getDescription() != null && !novel.getDescription().isEmpty()) {
                            metadata.append("简介: ").append(novel.getDescription()).append("\n");
                        }
                        return metadata.toString();
                    })
                    .defaultIfEmpty("");
        } else if (featureType == AIFeatureType.SUMMARY_TO_SCENE) {
            // 为摘要生成场景检索元数据
            Mono<String> novelInfoMono = novelService.findNovelById(novelId)
                    .map(novel -> {
                        StringBuilder metadata = new StringBuilder();
                        metadata.append("标题: ").append(novel.getTitle()).append("\n");
                        metadata.append("类型: ").append(novel.getGenre()).append("\n");
                        if (novel.getDescription() != null && !novel.getDescription().isEmpty()) {
                            metadata.append("简介: ").append(novel.getDescription()).append("\n");
                        }
                        return metadata.toString();
                    })
                    .defaultIfEmpty("");

            // 如果有章节ID，则获取章节信息
            if (contextId != null && !contextId.isEmpty()) {
                // 这里需要通过小说结构查找章节信息，而不是通过场景
                return novelService.findNovelById(novelId)
                        .flatMap(novel -> {
                            // 在小说结构中查找章节
                            for (Novel.Act act : novel.getStructure().getActs()) {
                                for (Novel.Chapter chapter : act.getChapters()) {
                                    if (chapter.getId().equals(contextId)) {
                                        StringBuilder metadata = new StringBuilder();
                                        metadata.append("章节: ").append(chapter.getTitle()).append("\n");
                                        if (chapter.getDescription() != null && !chapter.getDescription().isEmpty()) {
                                            metadata.append("章节描述: ").append(chapter.getDescription()).append("\n");
                                        }
                                        return Mono.just(metadata.toString());
                                    }
                                }
                            }
                            return Mono.just(""); // 未找到章节
                        })
                        .defaultIfEmpty("")
                        .flatMap(chapterInfo -> 
                            novelInfoMono.map(novelInfo -> novelInfo + chapterInfo)
                        );
            }

            return novelInfoMono;
        } else {
            return Mono.just("");
        }
    }
}
