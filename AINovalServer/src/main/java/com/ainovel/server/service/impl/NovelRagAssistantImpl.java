package com.ainovel.server.service.impl;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.service.KnowledgeService;
import com.ainovel.server.service.NovelRagAssistant;
import com.ainovel.server.service.NovelService;

import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.input.Prompt;
import dev.langchain4j.model.input.PromptTemplate;
import dev.langchain4j.rag.content.Content;
import dev.langchain4j.rag.content.retriever.ContentRetriever;
import dev.langchain4j.rag.query.Query;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;

/**
 * 小说RAG助手实现类 提供基于检索增强生成的小说辅助功能
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NovelRagAssistantImpl implements NovelRagAssistant {

    private final NovelService novelService;
    private final KnowledgeService knowledgeService;
    private final ContentRetriever contentRetriever;
    private final ChatLanguageModel chatLanguageModel;

    // RAG查询提示模板
    private static final String RAG_PROMPT_TEMPLATE = """
            你是一个专业的小说顾问，基于以下相关背景信息，回答问题:
            
            背景信息:
            {{context}}
            
            问题: {{query}}
            
            请提供专业、准确的回答，仅使用背景信息中的内容。如果背景信息中没有相关内容，请直接回答'我没有足够的信息来回答这个问题'。
            """;

    @Override
    public Mono<String> queryWithRagContext(String novelId, String query) {
        log.info("RAG小说查询: novelId={}, query={}", novelId, query);

        return novelService.findNovelById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    log.info("基于小说 '{}' 进行RAG查询", novel.getTitle());

                    // 从内容检索器获取相关内容
                    List<Content> relevantContents = contentRetriever.retrieve(Query.from(query));

                    if (relevantContents.isEmpty()) {
                        log.warn("没有找到与查询相关的内容: {}", query);
                        return Mono.just("没有找到与查询相关的小说内容。");
                    }

                    // 将相关内容合并为上下文
                    String context = relevantContents.stream()
                            .map(content -> content.textSegment().text())
                            .collect(Collectors.joining("\n\n"));

                    log.debug("找到相关上下文: {}", context);

                    // 创建提示
                    PromptTemplate promptTemplate = PromptTemplate.from(RAG_PROMPT_TEMPLATE);
                    Prompt prompt = promptTemplate.apply(Map.of(
                            "context", context,
                            "query", query
                    ));

                    // 使用语言模型生成回答
                    String responseText = chatLanguageModel.chat(prompt.text());

                    log.info("RAG查询完成: novelId={}, query={}", novelId, query);
                    return Mono.just(responseText);
                });
    }
}
