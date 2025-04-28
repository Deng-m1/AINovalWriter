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
import reactor.core.publisher.Mono;

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
    public Mono<GenerateSingleSummaryResult> execute(TaskContext<GenerateSingleSummaryParameters> context) {
        GenerateSingleSummaryParameters parameters = context.getParameters();
        String novelId = parameters.getNovelId();
        int chapterIndex = parameters.getChapterIndex();
        int chapterOrder = parameters.getChapterOrder();
        String aiConfigId = parameters.getAiConfigIdSummary();
        String contextContent = parameters.getContext();
        String previousSummary = parameters.getPreviousSummary();

        log.info("开始生成章节摘要，小说ID: {}，章节序号: {}", novelId, chapterOrder);

        // 要生成的章节标题
        String chapterTitle = "第" + chapterOrder + "章";

        return novelService.findNovelById(novelId)
            .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到小说: " + novelId)))
            .flatMap(novel -> {
                // 构建生成摘要请求
                GenerateSceneFromSummaryRequest.GenerateSceneFromSummaryRequestBuilder requestBuilder = GenerateSceneFromSummaryRequest.builder()
                        .summary(contextContent) // 将上下文内容作为摘要输入
                        .chapterId(null); // 不指定章节ID
                
                // 在构建器上添加style指令
                String styleInstruction = "生成下一章节的摘要，章节标题：" + chapterTitle;
                // 假设GenerateSceneFromSummaryRequest有一个style方法
                try {
                    // 尝试使用反射查找style方法
                    java.lang.reflect.Method styleMethod = requestBuilder.getClass().getMethod("style", String.class);
                    styleMethod.invoke(requestBuilder, styleInstruction);
                } catch (Exception e) {
                    log.warn("无法设置style指令，将使用默认方式: {}", e.getMessage());
                }
                
                GenerateSceneFromSummaryRequest request = requestBuilder.build();

                // 调用AI服务生成摘要
                return novelAIService.generateSceneFromSummary(context.getUserId(), novelId, request)
                    .switchIfEmpty(Mono.error(new RuntimeException("生成章节摘要失败")))
                    .flatMap(response -> {
                        // 从响应中获取内容，作为摘要 
                        return getSummaryFromResponse(response)
                            .flatMap(generatedSummary -> {
                                log.info("生成章节摘要成功，小说ID: {}，章节序号: {}, 摘要内容前100字: {}", 
                                        novelId, chapterOrder, generatedSummary.substring(0, Math.min(100, generatedSummary.length())));

                                // 创建新章节并添加到小说中
                                return addChapterToNovel(novel, chapterOrder, chapterTitle, generatedSummary)
                                    .flatMap(newChapterId -> {
                                        // 如果还有下一章需要生成，提交下一个子任务
                                        if (context.getParentTaskId() != null) {
                                            return getParentTaskParameters(context.getParentTaskId())
                                                .flatMap(parentParams -> {
                                                    int nextChapterIndex = chapterIndex + 1;
                                                    if (nextChapterIndex < parentParams.getNumberOfChapters()) {
                                                        log.info("准备生成下一章摘要，小说ID: {}，下一章序号: {}", novelId, chapterOrder + 1);
                                                        
                                                        // 更新父任务进度
                                                        GenerateNextSummariesOnlyProgress progress = new GenerateNextSummariesOnlyProgress();
                                                        progress.setTotal(parentParams.getNumberOfChapters());
                                                        progress.setCompleted(nextChapterIndex);
                                                        progress.setFailed(0);
                                                        progress.setCurrentIndex(nextChapterIndex);
                                                        
                                                        return updateParentProgress(context.getParentTaskId(), progress)
                                                            .then(Mono.defer(() -> {
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
                                                                return context.submitSubTask("GENERATE_SINGLE_SUMMARY", nextChapterParams)
                                                                    .doOnNext(taskId -> 
                                                                        log.info("已提交生成下一章摘要的子任务，父任务ID: {}，子任务ID: {}", 
                                                                                context.getParentTaskId(), taskId))
                                                                    .then();
                                                            }));
                                                    }
                                                    return Mono.empty();
                                                })
                                                .then(Mono.just(newChapterId));
                                        }
                                        return Mono.just(newChapterId);
                                    })
                                    .map(newChapterId -> {
                                        // 返回当前章节的生成结果
                                        return GenerateSingleSummaryResult.builder()
                                                .newChapterId(newChapterId)
                                                .summary(generatedSummary)
                                                .chapterIndex(chapterIndex)
                                                .chapterTitle(chapterTitle)
                                                .build();
                                    });
                            });
                    });
            });
    }

    /**
     * 从响应中提取摘要内容
     */
    private Mono<String> getSummaryFromResponse(GenerateSceneFromSummaryResponse response) {
        try {
            // 尝试使用getContent方法
            String summary = response.getContent();
            if (summary != null && !summary.isEmpty()) {
                return Mono.just(summary);
            }
        } catch (Exception ignored) {
            // 忽略异常，尝试下一种方法
        }
        
        try {
            // 尝试使用getGeneratedContent方法
            java.lang.reflect.Method getContentMethod = response.getClass().getMethod("getGeneratedContent");
            String summary = (String) getContentMethod.invoke(response);
            if (summary != null && !summary.isEmpty()) {
                return Mono.just(summary);
            }
            log.error("无法获取生成的内容: 内容为空");
            return Mono.error(new RuntimeException("无法获取生成的内容"));
        } catch (Exception ex) {
            log.error("无法获取生成的内容: {}", ex.getMessage());
            return Mono.error(new RuntimeException("无法获取生成的内容"));
        }
    }

    /**
     * 获取父任务参数
     */
    private Mono<GenerateNextSummariesOnlyParameters> getParentTaskParameters(String parentTaskId) {
        return taskStateService.getTask(parentTaskId)
            .filter(task -> task.getParameters() instanceof GenerateNextSummariesOnlyParameters)
            .map(task -> (GenerateNextSummariesOnlyParameters) task.getParameters());
    }

    /**
     * 更新父任务进度
     */
    private Mono<Void> updateParentProgress(String parentTaskId, GenerateNextSummariesOnlyProgress progress) {
        return taskStateService.recordProgress(parentTaskId, progress);
    }

    /**
     * 将新章节添加到小说中
     */
    private Mono<String> addChapterToNovel(Novel novel, int chapterOrder, String chapterTitle, String summary) {
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
        return novelService.updateNovel(novel.getId(), novel)
            .thenReturn(chapterId);
    }
} 