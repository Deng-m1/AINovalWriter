package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Chapter;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryParameters;
import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryResult;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryParameters;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 批量生成场景摘要的任务执行器
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BatchGenerateSummaryTaskExecutable implements BackgroundTaskExecutable<BatchGenerateSummaryParameters, BatchGenerateSummaryResult> {

    private final NovelService novelService;
    private final SceneService sceneService;

    @Override
    public Mono<BatchGenerateSummaryResult> execute(TaskContext<BatchGenerateSummaryParameters> context) {
        BatchGenerateSummaryParameters parameters = context.getParameters();
        String novelId = parameters.getNovelId();
        String startChapterId = parameters.getStartChapterId();
        String endChapterId = parameters.getEndChapterId();
        String aiConfigId = parameters.getAiConfigId();
        boolean overwriteExisting = parameters.isOverwriteExisting();
        String userId = context.getUserId();

        log.info("开始批量生成场景摘要，小说ID: {}, 起始章节: {}, 结束章节: {}, 用户ID: {}, AI配置ID: {}, 覆盖已有摘要: {}", 
            novelId, startChapterId, endChapterId, userId, aiConfigId, overwriteExisting);
        
        // 1. 参数验证
        return novelService.findNovelById(novelId)
            .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到小说: " + novelId)))
            .flatMap(novel -> {
                if (!novel.getAuthor().getId().equals(userId)) {
                    log.error("用户 {} 无权访问小说 {}", userId, novelId);
                    return Mono.error(new IllegalArgumentException("无权访问该小说"));
                }
                
                // 2. 查找章节顺序
                Map<String, Integer> chapterOrderMap = getChapterOrderMap(novel);
                
                if (!chapterOrderMap.containsKey(startChapterId) || !chapterOrderMap.containsKey(endChapterId)) {
                    log.error("章节ID不存在: startChapterId={}, endChapterId={}", startChapterId, endChapterId);
                    return Mono.error(new IllegalArgumentException("章节ID不存在"));
                }
                
                int startOrder = chapterOrderMap.get(startChapterId);
                int endOrder = chapterOrderMap.get(endChapterId);
                
                if (startOrder > endOrder) {
                    log.error("起始章节顺序({})大于结束章节顺序({})", startOrder, endOrder);
                    return Mono.error(new IllegalArgumentException("起始章节必须在结束章节之前或相同"));
                }
                
                // 3. 获取该范围内所有章节ID
                List<String> chapterIds = getChapterIdsInRange(novel, startOrder, endOrder);
                
                // 查询这些章节下的所有场景
                return sceneService.findScenesByChapterIds(chapterIds)
                    .collectList()
                    .flatMap(scenes -> {
                        int totalScenes = scenes.size();
                        double progressStep = totalScenes > 0 ? 100.0 / totalScenes : 0;
                        double initialProgress = 0;
                        
                        Map<String, String> failedSceneDetails = new HashMap<>();
                        List<String> processedSceneIds = new ArrayList<>();
                        
                        return context.updateProgress(initialProgress)
                            .then(Mono.fromRunnable(() -> log.info("指定章节范围内找到 {} 个场景", totalScenes)))
                            .thenMany(Flux.fromIterable(scenes))
                            .flatMap(scene -> {
                                String sceneId = scene.getId();
                                int version = scene.getVersion();
                                
                                if (!overwriteExisting && scene.getSummary() != null && !scene.getSummary().trim().isEmpty()) {
                                    log.info("场景 {} 已有摘要且设置了不覆盖，跳过生成", sceneId);
                                    return Mono.just("SKIPPED");
                                }
                                
                                // 创建子任务参数
                                GenerateSummaryParameters subTaskParams = GenerateSummaryParameters.builder()
                                    .sceneId(sceneId)
                                    .novelId(novelId)
                                    .useAIEnhancement(true)
                                    .build();
                                
                                // 提交子任务
                                return context.submitSubTask("GENERATE_SUMMARY", subTaskParams)
                                    .doOnNext(subTaskId -> log.info("为场景 {} 提交子任务 {}", sceneId, subTaskId))
                                    .map(subTaskId -> "SUBMITTED");
                            })
                            .onErrorResume(e -> {
                                String sceneId = "unknown";
                                log.error("为场景 {} 提交子任务失败: {}", sceneId, e.getMessage());
                                return Mono.just("FAILED:" + sceneId);
                            })
                            .collectList()
                            .map(results -> {
                                long skippedCount = results.stream().filter(r -> r.equals("SKIPPED")).count();
                                long failedCount = results.stream().filter(r -> r.startsWith("FAILED")).count();
                                
                                // 构建结果
                                return BatchGenerateSummaryResult.builder()
                                    .totalScenes(totalScenes)
                                    .successCount(0) // 初始为0，后续由状态聚合器更新
                                    .failedCount((int)failedCount)
                                    .conflictCount(0) // 初始为0，后续由状态聚合器更新
                                    .skippedCount((int)skippedCount)
                                    .failedSceneDetails(failedSceneDetails)
                                    .build();
                            });
                    });
            });
    }

    private Map<String, Integer> getChapterOrderMap(Novel novel) {
        Map<String, Integer> chapterOrderMap = new HashMap<>();
        
        for (Novel.Act act : novel.getStructure().getActs()) {
            for (Novel.Chapter chapter : act.getChapters()) {
                chapterOrderMap.put(chapter.getId(), chapter.getOrder());
            }
        }
        
        return chapterOrderMap;
    }
    
    private List<String> getChapterIdsInRange(Novel novel, int startOrder, int endOrder) {
        List<String> chapterIds = new ArrayList<>();
        
        for (Novel.Act act : novel.getStructure().getActs()) {
            for (Novel.Chapter chapter : act.getChapters()) {
                int order = chapter.getOrder();
                if (order >= startOrder && order <= endOrder) {
                    chapterIds.add(chapter.getId());
                }
            }
        }
        
        return chapterIds;
    }

    @Override
    public String getTaskType() {
        return "BATCH_GENERATE_SUMMARY";
    }
} 