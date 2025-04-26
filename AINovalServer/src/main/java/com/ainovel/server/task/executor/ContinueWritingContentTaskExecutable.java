package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Act;
import com.ainovel.server.domain.model.Novel.Chapter;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentParameters;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentProgress;
import com.ainovel.server.task.dto.continuecontent.ContinueWritingContentResult;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyParameters;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/**
 * 自动续写小说章节内容的任务执行器
 * 作为父任务，负责协调摘要生成和内容生成流程
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ContinueWritingContentTaskExecutable implements BackgroundTaskExecutable<ContinueWritingContentParameters, ContinueWritingContentResult> {

    private final NovelService novelService;

    @Override
    public String getTaskType() {
        return "CONTINUE_WRITING_CONTENT";
    }

    @Override
    public Class<ContinueWritingContentParameters> getParameterType() {
        return ContinueWritingContentParameters.class;
    }
    
    @Override
    public Class<ContinueWritingContentResult> getResultType() {
        return ContinueWritingContentResult.class;
    }

    @Override
    public ContinueWritingContentResult execute(ContinueWritingContentParameters parameters, TaskContext<ContinueWritingContentParameters> context) throws Exception {
        String novelId = parameters.getNovelId();
        int numberOfChapters = parameters.getNumberOfChapters();
        String aiConfigIdSummary = parameters.getAiConfigIdSummary();
        String aiConfigIdContent = parameters.getAiConfigIdContent();
        String startContextMode = parameters.getStartContextMode();
        boolean requiresReview = parameters.isRequiresReview();

        log.info("开始执行自动续写小说章节内容任务，小说ID: {}，章节数: {}", novelId, numberOfChapters);
        
        // 初始化进度信息
        ContinueWritingContentProgress progress = new ContinueWritingContentProgress();
        progress.setStage("GENERATING_SUMMARIES");
        progress.setTotalChapters(numberOfChapters);
        progress.setSummariesCompleted(0);
        progress.setContentsCompleted(0);
        progress.setFailed(0);
        progress.setCurrentIndex(0);
        progress.setPercentComplete(0);
        context.updateProgress(progress);

        // 获取小说信息
        Novel novel = novelService.findNovelById(novelId)
                .blockOptional()
                .orElseThrow(() -> new IllegalArgumentException("找不到小说: " + novelId));

        // 首先提交生成摘要的子任务
        // 直接复用已有的摘要生成任务
        GenerateNextSummariesOnlyParameters summaryParams = GenerateNextSummariesOnlyParameters.builder()
                .novelId(novelId)
                .numberOfChapters(numberOfChapters)
                .aiConfigIdSummary(aiConfigIdSummary)
                .startContextMode(startContextMode)
                .build();

        // 提交摘要生成任务
        String summaryTaskId = context.submitSubTask("GENERATE_NEXT_SUMMARIES_ONLY", summaryParams);
        log.info("已提交生成章节摘要的子任务，父任务ID: {}，子任务ID: {}", context.getTaskId(), summaryTaskId);

        // 返回初始结果，后续由状态聚合器根据子任务完成情况更新
        return ContinueWritingContentResult.builder()
                .generatedChapters(new ArrayList<>())
                .success(false)
                .status("RUNNING")
                .completedChapters(0)
                .totalChapters(numberOfChapters)
                .build();
    }
} 