package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyParameters;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyProgress;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyResult;
import com.ainovel.server.task.dto.nextsummaries.GenerateSingleSummaryParameters;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.List;

/**
 * 生成多个章节摘要的父任务执行器
 * 利用GenerateSingleSummaryTaskExecutable作为子任务，逐章生成摘要
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GenerateNextSummariesOnlyTaskExecutable implements BackgroundTaskExecutable<GenerateNextSummariesOnlyParameters, GenerateNextSummariesOnlyResult> {

    private final NovelService novelService;

    @Override
    public String getTaskType() {
        return "GENERATE_NEXT_SUMMARIES_ONLY";
    }

    @Override
    public Mono<GenerateNextSummariesOnlyResult> execute(TaskContext<GenerateNextSummariesOnlyParameters> context) {
        GenerateNextSummariesOnlyParameters parameters = context.getParameters();
        String novelId = parameters.getNovelId();
        int numberOfChapters = parameters.getNumberOfChapters();
        String aiConfigIdSummary = parameters.getAiConfigIdSummary();
        String startContextMode = parameters.getStartContextMode();
        
        log.info("开始生成后续章节摘要，小说ID: {}，章节数量: {}, 使用AI配置: {}", 
                novelId, numberOfChapters, aiConfigIdSummary);
        
        // 初始化进度
        GenerateNextSummariesOnlyProgress progress = new GenerateNextSummariesOnlyProgress();
        progress.setTotal(numberOfChapters);
        progress.setCompleted(0);
        progress.setFailed(0);
        progress.setCurrentIndex(0);
        
        return context.updateProgress(progress)
            .then(novelService.findNovelById(novelId))
            .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到小说: " + novelId)))
            .flatMap(novel -> {
                // 获取最新章节序号
                int lastChapterOrder = getLastChapterOrder(novel);

                // 获取上下文内容
                return getContextContent(novel, startContextMode, parameters.getContextChapterCount(), 
                                        parameters.getCustomContext())
                    .flatMap(contextContent -> {
                        // 开始生成第一个章节摘要
                        log.info("开始生成第一个章节摘要，小说ID: {}，当前章节序号: {}", novelId, lastChapterOrder + 1);
                        GenerateSingleSummaryParameters firstChapterParams = GenerateSingleSummaryParameters.builder()
                                .novelId(novelId)
                                .chapterIndex(0)
                                .chapterOrder(lastChapterOrder + 1)
                                .aiConfigIdSummary(aiConfigIdSummary)
                                .context(contextContent)
                                .previousSummary(getLastChapterSummary(novel))
                                .totalChapters(numberOfChapters)
                                .parentTaskId(context.getTaskId())
                                .build();

                        // 提交第一个子任务
                        return context.submitSubTask("GENERATE_SINGLE_SUMMARY", firstChapterParams)
                                .doOnNext(subTaskId -> 
                                    log.info("已提交第一个章节摘要生成子任务: {}", subTaskId))
                                .thenReturn(buildInitialResult(numberOfChapters));
                    });
            });
    }

    /**
     * 获取最后一章的序号
     */
    private int getLastChapterOrder(Novel novel) {
        if (novel.getStructure() == null || novel.getStructure().getActs() == null) {
            return 0;
        }
        
        return novel.getStructure().getActs().stream()
            .flatMap(act -> act.getChapters().stream())
            .map(chapter -> {
                try {
                    String title = chapter.getTitle();
                    if (title.startsWith("第") && title.endsWith("章")) {
                        String numPart = title.substring(1, title.length() - 1);
                        return Integer.parseInt(numPart);
                    }
                } catch (Exception ignored) {
                    // 忽略无法解析的标题
                }
                return 0;
            })
            .max(Integer::compareTo)
            .orElse(0);
    }

    /**
     * 获取上下文内容
     */
    private Mono<String> getContextContent(Novel novel, String startContextMode, 
                                           Integer contextChapterCount, String customContext) {
        // 如果是自定义上下文，直接返回
        if ("CUSTOM".equals(startContextMode) && customContext != null && !customContext.isEmpty()) {
            log.info("使用自定义上下文，长度: {}", customContext.length());
            return Mono.just(customContext);
        }
        
        // 构建小说的基本信息作为上下文
        StringBuilder contextBuilder = new StringBuilder();
        if (novel.getTitle() != null) {
            contextBuilder.append("小说标题: ").append(novel.getTitle()).append("\n\n");
        }
        if (novel.getDescription() != null) {
            contextBuilder.append("小说描述: ").append(novel.getDescription()).append("\n\n");
        }
        
        // 如果是自动模式或指定章节数，获取最近的章节内容
        if ("AUTO".equals(startContextMode) || "LAST_N_CHAPTERS".equals(startContextMode)) {
            int chaptersToInclude = (contextChapterCount != null && contextChapterCount > 0) 
                                   ? contextChapterCount : 3; // 默认取最近3章
            
            // 这里应该调用NovelService的方法获取最近N章的摘要
            // 由于示例代码中没有此方法，暂时只返回基本信息
            log.info("获取最近 {} 章作为上下文（简化实现）", chaptersToInclude);
            contextBuilder.append("包含最近 ").append(chaptersToInclude).append(" 章的内容摘要...");
        }
        
        return Mono.just(contextBuilder.toString());
    }

    /**
     * 获取最后一章的摘要
     */
    private String getLastChapterSummary(Novel novel) {
        // 这里应该获取最后一章的摘要，简化实现
        return "";
    }

    /**
     * 构建初始结果对象
     */
    private GenerateNextSummariesOnlyResult buildInitialResult(int totalChapters) {
        return GenerateNextSummariesOnlyResult.builder()
                .newChapterIds(new ArrayList<>())
                .summaries(new ArrayList<>())
                .summariesGeneratedCount(0)
                .totalChapters(totalChapters)
                .build();
    }
} 