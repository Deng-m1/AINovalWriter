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
        
        return Mono.just(context.getUserId())
            .flatMap(userId -> {
                // 调用NovelAIService生成摘要
                return novelAIService.generateNextSingleSummary(
                    userId,
                    novelId,
                    contextContent,
                    aiConfigId,
                    null // 暂不提供写作风格
                )
                .flatMap(generatedSummary -> {
                    log.info("章节摘要生成成功，小说ID: {}，章节序号: {}，摘要长度: {}", 
                        novelId, chapterOrder, generatedSummary.length());
                    
                    // 创建新章节
                    return createNewChapter(novelId, chapterTitle, generatedSummary, chapterOrder)
                        .flatMap(newChapterId -> {
                            // 构建结果
                            GenerateSingleSummaryResult result = GenerateSingleSummaryResult.builder()
                                .novelId(novelId)
                                .chapterId(newChapterId)
                                .summary(generatedSummary)
                                .chapterIndex(chapterIndex)
                                .chapterOrder(chapterOrder)
                                .chapterTitle(chapterTitle)
                                .build();
                            
                            // 如果是批量任务的一部分，检查是否需要提交下一个任务
                            if (parameters.getTotalChapters() != null && 
                                chapterIndex < parameters.getTotalChapters() - 1) {
                                
                                // 构建下一个章节的上下文（当前上下文+新生成的摘要）
                                String nextContext = contextContent;
                                if (nextContext != null && !nextContext.isEmpty()) {
                                    nextContext += "\n\n";
                                }
                                nextContext += "第" + chapterOrder + "章: " + generatedSummary;
                                
                                // 创建下一个章节的参数
                                GenerateSingleSummaryParameters nextParams = GenerateSingleSummaryParameters.builder()
                                    .novelId(novelId)
                                    .chapterIndex(chapterIndex + 1)
                                    .chapterOrder(chapterOrder + 1)
                                    .aiConfigIdSummary(aiConfigId)
                                    .context(nextContext)
                                    .previousSummary(generatedSummary)
                                    .totalChapters(parameters.getTotalChapters())
                                    .parentTaskId(parameters.getParentTaskId())
                                    .build();
                                
                                // 提交下一个子任务
                                log.info("提交下一个摘要生成子任务，小说ID: {}，章节序号: {}", 
                                    novelId, chapterOrder + 1);
                                    
                                return context.submitSubTask("GENERATE_SINGLE_SUMMARY", nextParams)
                                    .thenReturn(result);
                            }
                            
                            return Mono.just(result);
                        });
                })
                .onErrorResume(e -> {
                    log.error("生成章节摘要失败，小说ID: {}，章节序号: {}, 错误: {}", 
                        novelId, chapterOrder, e.getMessage(), e);
                    return Mono.error(
                        new RuntimeException("生成章节摘要失败: " + e.getMessage(), e)
                    );
                });
            });
    }
    
    /**
     * 创建新章节并添加到小说结构中
     */
    private Mono<String> createNewChapter(String novelId, String title, String summary, int order) {
        return novelService.findNovelById(novelId)
            .flatMap(novel -> {
                // 如果没有卷，先创建一个默认卷
                if (novel.getStructure() == null || 
                    novel.getStructure().getActs() == null || 
                    novel.getStructure().getActs().isEmpty()) {
                    
                    return novelService.addAct(novelId, "第一卷", null)
                        .flatMap(updatedNovel -> {
                            String actId = updatedNovel.getStructure().getActs().get(0).getId();
                            // 创建章节，使用摘要作为章节描述
                            return novelService.addChapter(novelId, actId, title, null);
                        });
                } else {
                    // 使用第一个卷添加章节
                    String actId = novel.getStructure().getActs().get(0).getId();
                    return novelService.addChapter(novelId, actId, title, null);
                }
            })
            .map(updatedNovel -> {
                // 找到新添加的章节
                for (Act act : updatedNovel.getStructure().getActs()) {
                    List<Chapter> chapters = act.getChapters();
                    if (chapters != null && !chapters.isEmpty()) {
                        // 查找最后一个章节或匹配章节名的章节
                        for (Chapter chapter : chapters) {
                            if (chapter.getTitle().equals(title)) {
                                return chapter.getId();
                            }
                        }
                        // 如果没找到匹配的，则返回最后一个
                        return chapters.get(chapters.size() - 1).getId();
                    }
                }
                // 如果未找到章节，抛出异常
                throw new RuntimeException("无法找到新创建的章节");
            });
    }
} 