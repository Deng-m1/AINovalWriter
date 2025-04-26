package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryParameters;
import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryProgress;
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
 * 批量生成场景摘要任务执行器
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BatchGenerateSummaryTaskExecutable implements BackgroundTaskExecutable<BatchGenerateSummaryParameters, BatchGenerateSummaryResult> {

    private final NovelService novelService;
    private final SceneService sceneService;

    @Override
    public BatchGenerateSummaryResult execute(BatchGenerateSummaryParameters parameters, TaskContext<BatchGenerateSummaryParameters> context) throws Exception {
        String novelId = parameters.getNovelId();
        String startChapterId = parameters.getStartChapterId();
        String endChapterId = parameters.getEndChapterId();
        String aiConfigId = parameters.getAiConfigId();
        boolean overwriteExisting = parameters.isOverwriteExisting();
        String userId = context.getUserId();

        context.logInfo("开始批量生成场景摘要，小说ID: {}, 起始章节: {}, 结束章节: {}, 用户ID: {}, AI配置ID: {}, 覆盖已有摘要: {}", 
                novelId, startChapterId, endChapterId, userId, aiConfigId, overwriteExisting);

        // 1. 参数验证
        Novel novel = novelService.findNovelById(novelId)
                .switchIfEmpty(Mono.error(new IllegalArgumentException("小说不存在: " + novelId)))
                .block();

        if (!novel.getAuthor().getId().equals(userId)) {
            context.logError("用户 {} 无权访问小说 {}", userId, novelId);
            throw new IllegalArgumentException("无权访问该小说");
        }

        // 获取章节顺序，以便确定范围查询时的前后关系
        Map<String, Integer> chapterOrderMap = getChapterOrderMap(novel);
        
        if (!chapterOrderMap.containsKey(startChapterId) || !chapterOrderMap.containsKey(endChapterId)) {
            context.logError("章节ID不存在: startChapterId={}, endChapterId={}", startChapterId, endChapterId);
            throw new IllegalArgumentException("章节ID不存在");
        }
        
        int startOrder = chapterOrderMap.get(startChapterId);
        int endOrder = chapterOrderMap.get(endChapterId);
        
        if (startOrder > endOrder) {
            context.logError("起始章节顺序({})大于结束章节顺序({})", startOrder, endOrder);
            throw new IllegalArgumentException("起始章节必须在结束章节之前或相同");
        }

        // 2. 查询指定章节范围内的所有场景
        List<String> chapterIds = getChapterIdsInRange(novel, startOrder, endOrder);
        
        List<Scene> scenes = sceneService.findScenesByChapterIds(chapterIds)
                .collectList()
                .block();

        if (scenes == null || scenes.isEmpty()) {
            context.logInfo("指定章节范围内没有找到场景，任务完成");
            return BatchGenerateSummaryResult.builder()
                    .totalScenes(0)
                    .successCount(0)
                    .failedCount(0)
                    .conflictCount(0)
                    .skippedCount(0)
                    .build();
        }

        // 3. 初始化进度
        int totalScenes = scenes.size();
        BatchGenerateSummaryProgress initialProgress = BatchGenerateSummaryProgress.builder()
                .totalScenes(totalScenes)
                .processedCount(0)
                .successCount(0)
                .failedCount(0)
                .conflictCount(0)
                .skippedCount(0)
                .build();
        
        context.updateProgress(initialProgress);
        context.logInfo("指定章节范围内找到 {} 个场景", totalScenes);

        // 4. 循环提交子任务
        int skippedCount = 0;
        Map<String, String> failedSceneDetails = new HashMap<>();
        
        for (Scene scene : scenes) {
            String sceneId = scene.getId();
            int version = scene.getVersion();
            
            // 如果设置了不覆盖已有摘要且当前场景已有摘要，则跳过
            if (!overwriteExisting && scene.getSummary() != null && !scene.getSummary().trim().isEmpty()) {
                skippedCount++;
                context.logInfo("场景 {} 已有摘要且设置了不覆盖，跳过生成", sceneId);
                continue;
            }
            
            try {
                // 创建子任务参数
                GenerateSummaryParameters subTaskParams = GenerateSummaryParameters.builder()
                        .sceneId(sceneId)
                        .aiConfigId(aiConfigId)
                        .expectedVersion(version)
                        .build();
                
                // 提交子任务
                String subTaskId = context.submitSubTask("GENERATE_SUMMARY", subTaskParams);
                context.logInfo("为场景 {} 提交子任务 {}", sceneId, subTaskId);
                
            } catch (Exception e) {
                // 子任务提交失败
                context.logError("为场景 {} 提交子任务失败: {}", sceneId, e.getMessage());
                failedSceneDetails.put(sceneId, "子任务提交失败: " + e.getMessage());
            }
        }
        
        // 5. 更新进度以反映跳过的场景
        if (skippedCount > 0) {
            BatchGenerateSummaryProgress updatedProgress = BatchGenerateSummaryProgress.builder()
                    .totalScenes(totalScenes)
                    .processedCount(skippedCount)
                    .successCount(0)
                    .failedCount(0)
                    .conflictCount(0)
                    .skippedCount(skippedCount)
                    .build();
            
            context.updateProgress(updatedProgress);
        }
        
        // 6. 返回初始结果（最终结果由状态聚合器根据子任务完成情况更新）
        int failedCountInitial = failedSceneDetails.size();
        
        return BatchGenerateSummaryResult.builder()
                .totalScenes(totalScenes)
                .successCount(0)  // 初始为0，后续由StateAggregatorService更新
                .failedCount(failedCountInitial)
                .conflictCount(0)  // 初始为0，后续由StateAggregatorService更新
                .skippedCount(skippedCount)
                .failedSceneDetails(failedSceneDetails)
                .build();
    }
    
    /**
     * 获取小说内所有章节的顺序映射
     */
    private Map<String, Integer> getChapterOrderMap(Novel novel) {
        Map<String, Integer> orderMap = new HashMap<>();
        int globalOrder = 0;
        
        for (Novel.Act act : novel.getStructure().getActs()) {
            for (Novel.Chapter chapter : act.getChapters()) {
                orderMap.put(chapter.getId(), globalOrder++);
            }
        }
        
        return orderMap;
    }
    
    /**
     * 获取指定顺序范围内的章节ID列表
     */
    private List<String> getChapterIdsInRange(Novel novel, int startOrder, int endOrder) {
        List<String> chapterIds = new ArrayList<>();
        int currentOrder = 0;
        
        for (Novel.Act act : novel.getStructure().getActs()) {
            for (Novel.Chapter chapter : act.getChapters()) {
                if (currentOrder >= startOrder && currentOrder <= endOrder) {
                    chapterIds.add(chapter.getId());
                }
                currentOrder++;
            }
        }
        
        return chapterIds;
    }
    
    @Override
    public String getTaskType() {
        return "BATCH_GENERATE_SUMMARY";
    }

    @Override
    public Class<BatchGenerateSummaryParameters> getParameterType() {
        return BatchGenerateSummaryParameters.class;
    }

    @Override
    public Class<BatchGenerateSummaryResult> getResultType() {
        return BatchGenerateSummaryResult.class;
    }
} 