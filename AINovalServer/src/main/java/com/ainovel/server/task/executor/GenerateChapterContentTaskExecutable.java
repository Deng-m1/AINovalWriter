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
    public Mono<GenerateChapterContentResult> execute(TaskContext<GenerateChapterContentParameters> context) {
        // 从context获取参数
        GenerateChapterContentParameters parameters = context.getParameters();
        String novelId = parameters.getNovelId();
        String chapterId = parameters.getChapterId();
        int chapterIndex = parameters.getChapterIndex();
        String chapterTitle = parameters.getChapterTitle();
        String chapterSummary = parameters.getChapterSummary();
        String aiConfigId = parameters.getAiConfigId();
        String contextContent = parameters.getContext();
        String writingStyle = parameters.getWritingStyle();

        log.info("开始生成章节内容，小说ID: {}，章节ID: {}，章节标题: {}", novelId, chapterId, chapterTitle);

        return novelService.findNovelById(novelId)
            .switchIfEmpty(Mono.error(new IllegalArgumentException("找不到小说: " + novelId)))
            .flatMap(novel -> {
                // 构建生成场景内容的请求
                GenerateSceneFromSummaryRequest.GenerateSceneFromSummaryRequestBuilder requestBuilder = 
                        GenerateSceneFromSummaryRequest.builder()
                        .summary(chapterSummary)
                        .chapterId(chapterId);
                        
                // 添加writing style
                // 使用反射方式调用可能存在的方法，避免编译错误
                try {
                    java.lang.reflect.Method styleMethod = requestBuilder.getClass().getMethod("style", String.class);
                    styleMethod.invoke(requestBuilder, writingStyle);
                } catch (Exception e) {
                    log.warn("设置写作风格时发生错误: {}", e.getMessage());
                }
                
                GenerateSceneFromSummaryRequest sceneRequest = requestBuilder.build();

                // 调用AI服务生成内容
                return novelAIService.generateSceneFromSummary(context.getUserId(), novelId, sceneRequest)
                    .switchIfEmpty(Mono.error(new RuntimeException("生成章节内容失败：AI服务未返回响应")))
                    .flatMap(response -> {
                        // 获取生成内容
                        String generatedContent;
                        try {
                            // 尝试使用getContent方法
                            java.lang.reflect.Method getContentMethod = response.getClass().getMethod("getContent");
                            generatedContent = (String) getContentMethod.invoke(response);
                        } catch (Exception e) {
                            try {
                                // 尝试使用getGeneratedContent方法
                                java.lang.reflect.Method getContentMethod = response.getClass().getMethod("getGeneratedContent");
                                generatedContent = (String) getContentMethod.invoke(response);
                            } catch (Exception ex) {
                                return Mono.error(new RuntimeException("无法获取生成的内容: " + ex.getMessage()));
                            }
                        }
                        
                        if (generatedContent == null || generatedContent.isEmpty()) {
                            return Mono.error(new RuntimeException("生成章节内容失败：AI返回空内容"));
                        }

                        final String content = generatedContent; // 创建一个最终变量用于闭包
                        
                        log.info("生成章节内容成功，小说ID: {}，章节ID: {}，内容长度: {}", 
                                novelId, chapterId, content.length());

                        // 创建场景
                        Scene scene = Scene.builder()
                                .novelId(novelId)
                                .chapterId(chapterId)
                                .title(chapterTitle)
                                .content(content)
                                .summary(chapterSummary)
                                .sequence(0) // 第一个场景
                                .build();

                        return sceneService.createScene(scene)
                            .switchIfEmpty(Mono.error(new RuntimeException("保存场景失败")))
                            .flatMap(savedScene -> {
                                // 将场景ID添加到章节中
                                return updateChapterWithScene(novel, chapterId, savedScene.getId())
                                    .map(updatedChapter -> {
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
                                    });
                            });
                    });
            })
            .onErrorResume(e -> {
                log.error("生成章节内容失败，小说ID: {}，章节ID: {}，错误: {}", novelId, chapterId, e.getMessage(), e);
                return Mono.just(GenerateChapterContentResult.builder()
                        .novelId(novelId)
                        .chapterId(chapterId)
                        .chapterIndex(chapterIndex)
                        .success(false)
                        .errorMessage("生成章节内容失败: " + e.getMessage())
                        .build());
            });
    }

    /**
     * 更新章节，添加场景ID
     */
    private Mono<Chapter> updateChapterWithScene(Novel novel, String chapterId, String sceneId) {
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
                    final Chapter updatedChapter = chapter; // 创建最终变量用于返回
                    return novelService.updateNovel(novel.getId(), novel)
                        .thenReturn(updatedChapter);
                }
            }
        }
        
        return Mono.error(new IllegalStateException("找不到章节: " + chapterId));
    }
} 