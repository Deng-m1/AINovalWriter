package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.service.ai.AIModelProvider;
import com.ainovel.server.service.UserAIModelConfigService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryParameters;
import com.ainovel.server.task.dto.summarygeneration.GenerateSummaryResult;
import com.ainovel.server.web.dto.SummarizeSceneRequest;
import com.ainovel.server.web.dto.SummarizeSceneResponse;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Component;

import reactor.core.publisher.Mono;

/**
 * 生成场景摘要任务执行器
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GenerateSummaryTaskExecutable implements BackgroundTaskExecutable<GenerateSummaryParameters, GenerateSummaryResult> {

    private final SceneService sceneService;
    private final NovelAIService novelAIService;
    private final UserAIModelConfigService userAIModelConfigService;
    private final MongoTemplate mongoTemplate;

    @Override
    public GenerateSummaryResult execute(GenerateSummaryParameters parameters, TaskContext<GenerateSummaryParameters> context) throws Exception {
        String sceneId = parameters.getSceneId();
        String aiConfigId = parameters.getAiConfigId();
        int expectedVersion = parameters.getExpectedVersion();
        String userId = context.getUserId();

        context.logInfo("开始为场景 {} 生成摘要，期望版本: {}，用户ID: {}, AI配置ID: {}", 
                sceneId, expectedVersion, userId, aiConfigId);

        // 1. 获取场景内容和当前版本
        Scene scene = sceneService.findSceneById(sceneId)
                .switchIfEmpty(Mono.error(new Exception("场景不存在: " + sceneId)))
                .block();

        int actualVersion = scene.getVersion();
        String content = scene.getContent();
        String novelId = scene.getNovelId();

        if (content == null || content.trim().isEmpty()) {
            context.logError("场景 {} 内容为空，无法生成摘要", sceneId);
            throw new IllegalArgumentException("场景内容为空，无法生成摘要");
        }

        // 2. 版本检查
        boolean conflict = false;
        if (actualVersion != expectedVersion) {
            conflict = true;
            context.logInfo("场景 {} 版本不匹配，期望版本: {}，实际版本: {}，将使用最新内容生成摘要", 
                    sceneId, expectedVersion, actualVersion);
        }

        // 3. 调用AI服务生成摘要
        SummarizeSceneRequest summarizeRequest = new SummarizeSceneRequest();
        // 可以添加style instructions等额外参数

        SummarizeSceneResponse response = novelAIService.summarizeScene(userId, sceneId, summarizeRequest)
                .block();

        if (response == null || response.getSummary() == null) {
            context.logError("生成场景 {} 摘要失败: AI服务未返回有效摘要", sceneId);
            throw new RuntimeException("AI服务未返回有效摘要");
        }

        String generatedSummary = response.getSummary();
        context.logInfo("场景 {} 摘要生成成功，长度: {}", sceneId, generatedSummary.length());

        // 4. 原子更新场景摘要
        boolean updateSuccess = updateSceneSummaryAtomic(sceneId, conflict ? actualVersion : expectedVersion, generatedSummary);
        
        if (!updateSuccess) {
            if (!conflict) {
                // 如果之前没有检测到冲突，但更新时失败，说明在生成过程中发生了并发修改
                conflict = true;
                context.logInfo("场景 {} 在生成摘要过程中被修改，将尝试基于最新版本更新", sceneId);
                
                // 重新获取场景最新版本
                scene = sceneService.findSceneById(sceneId)
                        .switchIfEmpty(Mono.error(new Exception("场景不存在: " + sceneId)))
                        .block();
                
                actualVersion = scene.getVersion();
                
                // 再次尝试更新
                updateSuccess = updateSceneSummaryAtomic(sceneId, actualVersion, generatedSummary);
                
                if (!updateSuccess) {
                    context.logError("场景 {} 摘要更新失败: 多次尝试后仍然版本冲突", sceneId);
                }
            } else {
                context.logError("场景 {} 摘要更新失败: 版本冲突", sceneId);
            }
        }

        // 5. 返回结果
        return GenerateSummaryResult.builder()
                .sceneId(sceneId)
                .summary(generatedSummary)
                .conflict(conflict)
                .version(actualVersion + (updateSuccess ? 1 : 0))
                .build();
    }

    /**
     * 原子更新场景摘要
     * 
     * @param sceneId 场景ID
     * @param expectedVersion 期望版本号
     * @param summary 生成的摘要
     * @return 更新是否成功
     */
    private boolean updateSceneSummaryAtomic(String sceneId, int expectedVersion, String summary) {
        try {
            Query query = Query.query(Criteria.where("_id").is(sceneId)
                    .and("version").is(expectedVersion));
            
            Update update = new Update()
                    .set("summary", summary)
                    .inc("version", 1);
            
            return mongoTemplate.updateFirst(query, update, Scene.class).getModifiedCount() > 0;
        } catch (Exception e) {
            log.error("原子更新场景摘要失败", e);
            return false;
        }
    }
    
    @Override
    public String getTaskType() {
        return "GENERATE_SUMMARY";
    }

    @Override
    public Class<GenerateSummaryParameters> getParameterType() {
        return GenerateSummaryParameters.class;
    }

    @Override
    public Class<GenerateSummaryResult> getResultType() {
        return GenerateSummaryResult.class;
    }
    
    @Override
    public boolean isRetryable(Throwable throwable) {
        // 可重试的异常：网络超时、限流等
        return !(throwable instanceof IllegalArgumentException);
    }
} 