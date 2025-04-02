package com.ainovel.server.web.controller;

import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.service.IndexingService;
import com.ainovel.server.service.NovelRagAssistant;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.NovelIdDto;
import com.ainovel.server.web.dto.RagQueryDto;
import com.ainovel.server.web.dto.RagQueryResultDto;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * RAG功能控制器 提供基于检索增强生成(RAG)的知识库查询和管理功能
 */
@Slf4j
@RestController
@RequestMapping("/api/rag")
@CrossOrigin(origins = "*", maxAge = 3600)
@RequiredArgsConstructor
public class RagController extends ReactiveBaseController {

    private final IndexingService indexingService;
    private final NovelRagAssistant novelRagAssistant;

    /**
     * 处理RAG知识库查询
     *
     * @param queryDto 查询DTO
     * @return 查询结果
     */
    @PostMapping("/query")
    public Mono<RagQueryResultDto> queryKnowledgeBase(@RequestBody RagQueryDto queryDto) {
        log.info("收到RAG查询请求: {}", queryDto);
        return novelRagAssistant.queryWithRagContext(queryDto.getNovelId(), queryDto.getQuery())
                .map(result -> new RagQueryResultDto(result, queryDto.getQuery()))
                .doOnSuccess(response -> log.info("RAG查询完成: {}", queryDto.getQuery()));
    }

    /**
     * 重新索引小说知识库
     *
     * @param novelIdDto 小说ID DTO
     * @return 操作结果
     */
    @PostMapping("/reindex")
    public Mono<String> reindexNovel(@RequestBody NovelIdDto novelIdDto) {
        log.info("收到重新索引请求: {}", novelIdDto.getNovelId());
        return indexingService.indexNovel(novelIdDto.getNovelId())
                .thenReturn("小说重新索引成功: " + novelIdDto.getNovelId())
                .doOnSuccess(result -> log.info("小说重新索引完成: {}", novelIdDto.getNovelId()));
    }

    /**
     * 删除小说知识库索引
     *
     * @param novelIdDto 小说ID DTO
     * @return 操作结果
     */
    @PostMapping("/delete-indices")
    public Mono<String> deleteNovelIndices(@RequestBody NovelIdDto novelIdDto) {
        log.info("收到删除索引请求: {}", novelIdDto.getNovelId());
        return indexingService.deleteNovelIndices(novelIdDto.getNovelId())
                .thenReturn("小说索引删除成功: " + novelIdDto.getNovelId())
                .doOnSuccess(result -> log.info("小说索引删除完成: {}", novelIdDto.getNovelId()));
    }
}
