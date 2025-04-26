package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Act;
import com.ainovel.server.domain.model.Novel.Chapter;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.nextsummaries.GenerateSingleSummaryParameters;
import com.ainovel.server.task.dto.nextsummaries.GenerateSingleSummaryResult;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyParameters;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyProgress;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryRequest;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryResponse;
import com.ainovel.server.task.model.BackgroundTask;
import com.ainovel.server.task.service.TaskStateService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.Optional;

/**
 * 生成单个章节摘要的任务执行器
 * 作为子任务，负责处理单个章节摘要的生成
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GenerateSingleSummaryTaskExecutable implements BackgroundTaskExecutable<GenerateSingleSummaryParameters, GenerateSingleSummaryResult> {

    private final NovelService novelService;
    private final NovelAIService novelAIService;
    private final TaskStateService taskStateService;

    @Override
    public String getTaskType() {
        return "GENERATE_SINGLE_SUMMARY";
    }

    @Override
    public Class<GenerateSingleSummaryParameters> getParameterType() {
        return GenerateSingleSummaryParameters.class;
    }

    @Override
    public Class<GenerateSingleSummaryResult> getResultType() {
        return GenerateSingleSummaryResult.class;
    }

    @Override
    public GenerateSingleSummaryResult execute(GenerateSingleSummaryParameters parameters, TaskContext<GenerateSingleSummaryParameters> context) throws Exception {
        String novelId = parameters.getNovelId();
        int chapterIndex = parameters.getChapterIndex();
        int chapterOrder = parameters.getChapterOrder();
        String aiConfigId = parameters.getAiConfigIdSummary();
        String contextContent = parameters.getContext();
        String previousSummary = parameters.getPreviousSummary();

        log.info("开始生成章节摘要，小说ID: {}，章节序号: {}", novelId, chapterOrder);

        // 获取小说信息
        Novel novel = novelService.findNovelById(novelId)
                .blockOptional()
                .orElseThrow(() -> new IllegalArgumentException("找不到小说: " + novelId));

        // 要生成的章节标题
        String chapterTitle = "第" + chapterOrder + "章";

        // 构建生成摘要请求
        GenerateSceneFromSummaryRequest request = GenerateSceneFromSummaryRequest.builder()
                .summary(contextContent) // 将上下文内容作为摘要输入
                .chapterId(null) // 不指定章节ID
                .styleInstructions("生成下一章节的摘要，章节标题：" + chapterTitle) // 添加风格指令
                .build();

        // 调用AI服务生成摘要
        GenerateSceneFromSummaryResponse response = novelAIService.generateSceneFromSummary(
                context.getUserId(), novelId, request)
                .blockOptional()
                .orElseThrow(() -> new RuntimeException("生成章节摘要失败"));

        // GenerateSceneFromSummaryResponse中获取内容，我们将它作为摘要
        String generatedSummary = response.getGeneratedContent();
        log.info("生成章节摘要成功，小说ID: {}，章节序号: {}, 摘要内容前100字: {}", 
                novelId, chapterOrder, generatedSummary.substring(0, Math.min(100, generatedSummary.length())));

        // 创建新章节并添加到小说中
        String newChapterId = addChapterToNovel(novel, chapterOrder, chapterTitle, generatedSummary);

        // 如果还有下一章需要生成，提交下一个子任务
        if (context.getParentTaskId() != null) {
            // 获取父任务参数
            GenerateNextSummariesOnlyParameters parentParams = getParentTaskParameters(context.getParentTaskId());
            
            if (parentParams != null) {
                int nextChapterIndex = chapterIndex + 1;
                if (nextChapterIndex < parentParams.getNumberOfChapters()) {
                    log.info("准备生成下一章摘要，小说ID: {}，下一章序号: {}", novelId, chapterOrder + 1);
                    
                    // 更新父任务进度
                    GenerateNextSummariesOnlyProgress progress = new GenerateNextSummariesOnlyProgress();
                    progress.setTotal(parentParams.getNumberOfChapters());
                    progress.setCompleted(nextChapterIndex);
                    progress.setFailed(0);
                    progress.setCurrentIndex(nextChapterIndex);
                    updateParentProgress(context.getParentTaskId(), progress);
                    
                    // 创建下一章参数
                    GenerateSingleSummaryParameters nextChapterParams = GenerateSingleSummaryParameters.builder()
                            .novelId(novelId)
                            .chapterIndex(nextChapterIndex)
                            .chapterOrder(chapterOrder + 1)
                            .aiConfigIdSummary(parentParams.getAiConfigIdSummary())
                            .context(contextContent + "\n\n" + chapterTitle + ": " + generatedSummary)
                            .previousSummary(generatedSummary)
                            .build();
                    
                    // 提交下一章子任务
                    String taskId = context.submitSubTask("GENERATE_SINGLE_SUMMARY", nextChapterParams);
                    log.info("已提交生成下一章摘要的子任务，父任务ID: {}，子任务ID: {}", context.getParentTaskId(), taskId);
                }
            } else {
                log.warn("无法获取父任务参数，无法继续生成后续章节");
            }
        }

        // 返回当前章节的生成结果
        return GenerateSingleSummaryResult.builder()
                .newChapterId(newChapterId)
                .summary(generatedSummary)
                .chapterIndex(chapterIndex)
                .chapterTitle(chapterTitle)
                .build();
    }

    /**
     * 获取父任务参数
     */
    private GenerateNextSummariesOnlyParameters getParentTaskParameters(String parentTaskId) {
        Optional<BackgroundTask> parentTaskOpt = taskStateService.findById(parentTaskId);
        if (parentTaskOpt.isPresent()) {
            BackgroundTask parentTask = parentTaskOpt.get();
            if (parentTask.getParameters() instanceof GenerateNextSummariesOnlyParameters) {
                return (GenerateNextSummariesOnlyParameters) parentTask.getParameters();
            }
        }
        return null;
    }

    /**
     * 更新父任务进度
     */
    private void updateParentProgress(String parentTaskId, GenerateNextSummariesOnlyProgress progress) {
        taskStateService.recordProgress(parentTaskId, progress);
    }

    /**
     * 将新章节添加到小说中
     */
    private String addChapterToNovel(Novel novel, int chapterOrder, String chapterTitle, String summary) {
        String chapterId = UUID.randomUUID().toString();
        
        // 创建新章节
        Chapter newChapter = new Chapter();
        newChapter.setId(chapterId);
        newChapter.setTitle(chapterTitle);
        newChapter.setDescription(summary);
        newChapter.setOrder(chapterOrder);
        newChapter.setSceneIds(new ArrayList<>());
        
        // 找到最后一个Act，将新章节添加到其中
        // 如果没有Act，则创建一个新的
        if (novel.getStructure() == null) {
            novel.setStructure(new Novel.Structure());
        }
        
        List<Act> acts = novel.getStructure().getActs();
        if (acts == null || acts.isEmpty()) {
            Act act = new Act();
            act.setId(UUID.randomUUID().toString());
            act.setTitle("第一卷");
            act.setOrder(1);
            act.setChapters(new ArrayList<>());
            acts = new ArrayList<>();
            acts.add(act);
            novel.getStructure().setActs(acts);
        }
        
        // 获取最后一个Act
        Act lastAct = acts.get(acts.size() - 1);
        if (lastAct.getChapters() == null) {
            lastAct.setChapters(new ArrayList<>());
        }
        
        // 添加新章节到最后一个Act
        lastAct.getChapters().add(newChapter);
        
        // 更新小说
        novelService.updateNovel(novel.getId(), novel).block();
        
        return chapterId;
    }
} 