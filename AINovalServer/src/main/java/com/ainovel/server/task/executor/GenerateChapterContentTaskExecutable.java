package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Novel.Act;
import com.ainovel.server.domain.model.Novel.Chapter;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.continuecontent.GenerateChapterContentParameters;
import com.ainovel.server.task.dto.continuecontent.GenerateChapterContentResult;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryRequest;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * 生成单个章节内容的任务执行器
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GenerateChapterContentTaskExecutable implements BackgroundTaskExecutable<GenerateChapterContentParameters, GenerateChapterContentResult> {

    private final NovelService novelService;
    private final NovelAIService novelAIService;
    private final SceneService sceneService;

    @Override
    public String getTaskType() {
        return "GENERATE_CHAPTER_CONTENT";
    }

    @Override
    public Class<GenerateChapterContentParameters> getParameterType() {
        return GenerateChapterContentParameters.class;
    }

    @Override
    public Class<GenerateChapterContentResult> getResultType() {
        return GenerateChapterContentResult.class;
    }

    @Override
    public GenerateChapterContentResult execute(GenerateChapterContentParameters parameters, TaskContext<GenerateChapterContentParameters> context) throws Exception {
        String novelId = parameters.getNovelId();
        String chapterId = parameters.getChapterId();
        int chapterIndex = parameters.getChapterIndex();
        String chapterTitle = parameters.getChapterTitle();
        String chapterSummary = parameters.getChapterSummary();
        String aiConfigId = parameters.getAiConfigId();
        String contextContent = parameters.getContext();
        String writingStyle = parameters.getWritingStyle();

        log.info("开始生成章节内容，小说ID: {}，章节ID: {}，章节标题: {}", novelId, chapterId, chapterTitle);

        try {
            // 获取小说信息
            Novel novel = novelService.findNovelById(novelId)
                    .blockOptional()
                    .orElseThrow(() -> new IllegalArgumentException("找不到小说: " + novelId));

            // 构建生成场景内容的请求
            GenerateSceneFromSummaryRequest sceneRequest = GenerateSceneFromSummaryRequest.builder()
                    .summary(chapterSummary)
                    .styleInstructions(writingStyle)
                    .chapterId(chapterId)
                    .build();

            // 调用AI服务生成内容
            String generatedContent = novelAIService.generateSceneFromSummary(
                    context.getUserId(), novelId, sceneRequest)
                    .map(response -> response.getGeneratedContent())
                    .block();

            if (generatedContent == null || generatedContent.isEmpty()) {
                throw new RuntimeException("生成章节内容失败：AI返回空内容");
            }

            log.info("生成章节内容成功，小说ID: {}，章节ID: {}，内容长度: {}", 
                    novelId, chapterId, generatedContent.length());

            // 创建场景
            Scene scene = Scene.builder()
                    .novelId(novelId)
                    .chapterId(chapterId)
                    .title(chapterTitle)
                    .content(generatedContent)
                    .summary(chapterSummary)
                    .sequence(0) // 第一个场景
                    .build();

            Scene savedScene = sceneService.createScene(scene).block();
            if (savedScene == null) {
                throw new RuntimeException("保存场景失败");
            }

            // 将场景ID添加到章节中
            Chapter updatedChapter = updateChapterWithScene(novel, chapterId, savedScene.getId());
            
            // 构建结果
            List<String> sceneIds = new ArrayList<>();
            sceneIds.add(savedScene.getId());
            
            return GenerateChapterContentResult.builder()
                    .novelId(novelId)
                    .chapterId(chapterId)
                    .chapterIndex(chapterIndex)
                    .chapter(updatedChapter)
                    .sceneIds(sceneIds)
                    .success(true)
                    .build();
            
        } catch (Exception e) {
            log.error("生成章节内容失败，小说ID: {}，章节ID: {}，错误: {}", novelId, chapterId, e.getMessage(), e);
            return GenerateChapterContentResult.builder()
                    .novelId(novelId)
                    .chapterId(chapterId)
                    .chapterIndex(chapterIndex)
                    .success(false)
                    .errorMessage("生成章节内容失败: " + e.getMessage())
                    .build();
        }
    }

    /**
     * 更新章节，添加场景ID
     */
    private Chapter updateChapterWithScene(Novel novel, String chapterId, String sceneId) {
        // 查找章节
        for (Act act : novel.getStructure().getActs()) {
            for (Chapter chapter : act.getChapters()) {
                if (chapter.getId().equals(chapterId)) {
                    // 添加场景ID
                    if (chapter.getSceneIds() == null) {
                        chapter.setSceneIds(new ArrayList<>());
                    }
                    chapter.getSceneIds().add(sceneId);
                    
                    // 更新小说
                    novelService.updateNovel(novel.getId(), novel).block();
                    
                    return chapter;
                }
            }
        }
        
        throw new IllegalStateException("找不到章节: " + chapterId);
    }
} 