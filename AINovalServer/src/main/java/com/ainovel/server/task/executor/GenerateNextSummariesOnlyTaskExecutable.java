package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Act;
import com.ainovel.server.domain.model.Novel.Chapter;
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
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/**
 * 自动续写小说章节摘要的任务执行器
 * 作为父任务，负责协调多个子任务的生成流程
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
        // 从context获取参数
        GenerateNextSummariesOnlyParameters parameters = context.getParameters();
        String novelId = parameters.getNovelId();
        int numberOfChapters = parameters.getNumberOfChapters();
        String aiConfigIdSummary = parameters.getAiConfigIdSummary();
        String startContextMode = parameters.getStartContextMode();

        log.info("开始执行自动续写小说章节摘要任务，小说ID: {}，章节数: {}", novelId, numberOfChapters);
        
        // 初始化进度信息
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
                return getContextContent(novel, startContextMode)
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
                                .build();

                        // 提交第一个子任务
                        return context.submitSubTask("GENERATE_SINGLE_SUMMARY", firstChapterParams)
                            .doOnNext(taskId -> 
                                log.info("已提交生成第一个章节摘要的子任务，父任务ID: {}，子任务ID: {}", context.getTaskId(), taskId))
                            .map(taskId -> {
                                // 父任务直接返回初始结果，后续由子任务完成并触发状态聚合
                                return GenerateNextSummariesOnlyResult.builder()
                                        .newChapterIds(new ArrayList<>())
                                        .summariesGeneratedCount(0)
                                        .status("RUNNING")
                                        .failedSteps(new ArrayList<>())
                                        .build();
                            });
                    });
            });
    }

    /**
     * 获取小说最后一章的序号
     */
    private int getLastChapterOrder(Novel novel) {
        return novel.getStructure().getActs().stream()
                .flatMap(act -> act.getChapters().stream())
                .max(Comparator.comparingInt(Chapter::getOrder))
                .map(Chapter::getOrder)
                .orElse(0);
    }

    /**
     * 获取上下文内容，根据不同的上下文模式
     */
    private Mono<String> getContextContent(Novel novel, String startContextMode) {
        switch (startContextMode) {
            case "LAST_CHAPTER":
                return getLastChapterContext(novel);
            case "LAST_THREE_CHAPTERS":
                return getLastThreeChaptersContext(novel);
            case "ALL_CHAPTERS":
                return getAllChaptersContext(novel);
            default:
                return getLastChapterContext(novel);
        }
    }

    /**
     * 获取最后一章的上下文
     */
    private Mono<String> getLastChapterContext(Novel novel) {
        Optional<Chapter> lastChapter = novel.getStructure().getActs().stream()
                .flatMap(act -> act.getChapters().stream())
                .max(Comparator.comparingInt(Chapter::getOrder));

        if (lastChapter.isPresent()) {
            Chapter chapter = lastChapter.get();
            return Mono.just(String.format("第%d章 %s: %s", 
                    chapter.getOrder(), 
                    chapter.getTitle(), 
                    chapter.getDescription()));
        } else {
            return Mono.just("这是小说的第一章。");
        }
    }

    /**
     * 获取最后三章的上下文
     */
    private Mono<String> getLastThreeChaptersContext(Novel novel) {
        List<Chapter> allChapters = novel.getStructure().getActs().stream()
                .flatMap(act -> act.getChapters().stream())
                .sorted(Comparator.comparingInt(Chapter::getOrder))
                .toList();

        StringBuilder context = new StringBuilder();
        int size = allChapters.size();
        int startIndex = Math.max(0, size - 3);

        for (int i = startIndex; i < size; i++) {
            Chapter chapter = allChapters.get(i);
            context.append(String.format("第%d章 %s: %s\n\n", 
                    chapter.getOrder(), 
                    chapter.getTitle(), 
                    chapter.getDescription()));
        }

        return Mono.just(context.toString().trim());
    }

    /**
     * 获取所有章节的上下文
     */
    private Mono<String> getAllChaptersContext(Novel novel) {
        List<Chapter> allChapters = novel.getStructure().getActs().stream()
                .flatMap(act -> act.getChapters().stream())
                .sorted(Comparator.comparingInt(Chapter::getOrder))
                .toList();

        StringBuilder context = new StringBuilder();
        for (Chapter chapter : allChapters) {
            context.append(String.format("第%d章 %s: %s\n\n", 
                    chapter.getOrder(), 
                    chapter.getTitle(), 
                    chapter.getDescription()));
        }

        return Mono.just(context.toString().trim());
    }

    /**
     * 获取最后一章的摘要
     */
    private String getLastChapterSummary(Novel novel) {
        return novel.getStructure().getActs().stream()
                .flatMap(act -> act.getChapters().stream())
                .max(Comparator.comparingInt(Chapter::getOrder))
                .map(Chapter::getDescription)
                .orElse("");
    }
} 