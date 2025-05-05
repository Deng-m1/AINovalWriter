package com.ainovel.server.task.executor;

import com.ainovel.server.domain.model.Novel; // Import Novel
import com.ainovel.server.domain.model.Novel.Act; // Import Act
import com.ainovel.server.domain.model.Novel.Chapter; // Import Chapter
import com.ainovel.server.domain.model.Scene; // Import Scene
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.NovelAIService; // Import NovelAIService
import com.ainovel.server.service.SceneService; // Import SceneService
import com.ainovel.server.task.BackgroundTaskExecutable;
import com.ainovel.server.task.TaskContext;
import com.ainovel.server.task.dto.continuecontent.GenerateSingleChapterParameters;
import com.ainovel.server.task.dto.continuecontent.GenerateSingleChapterResult;
import com.ainovel.server.web.dto.CreatedChapterInfo;
import com.ainovel.server.web.dto.GenerateSceneFromSummaryRequest; // Import the request DTO
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import lombok.Data; // Import Lombok Data
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;
import java.util.Objects; // Import Objects
import java.time.Duration; // Import Duration
// 引入 DTO
import java.util.concurrent.atomic.AtomicReference; // 用于在lambda中传递sceneId

/**
 * 生成单章摘要和内容的任务执行器 (REQ-TASK-002 子任务)
 * 负责生成一章的摘要和内容，并在完成后触发下一个章节的生成（如果需要）。
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GenerateSingleChapterTaskExecutable implements BackgroundTaskExecutable<GenerateSingleChapterParameters, GenerateSingleChapterResult> {

    private final NovelService novelService;
    private final NovelAIService novelAIService; // Inject NovelAIService
    private final SceneService sceneService; // Inject SceneService
    // private final ChapterPersistenceService chapterPersistenceService; // Assume a service to handle chapter creation/updates

    @Override
    public Mono<GenerateSingleChapterResult> execute(TaskContext<GenerateSingleChapterParameters> context) {
        GenerateSingleChapterParameters params = context.getParameters();
        String taskId = context.getTaskId();
        String userId = context.getUserId();
        if (userId == null) {
             log.error("Task {} cannot proceed without a userId.", taskId);
             return Mono.error(new IllegalStateException("User ID not available in TaskContext"));
        }

        log.info("执行 GenerateSingleChapterTask: {}, User: {}, 章节索引: {}/{}, 持久化: {}",
                 taskId, userId, params.getChapterIndex(), params.getTotalChapters(), params.isPersistChanges());

        // 用于在 flatMap 链中传递生成的 chapterId 和 sceneId
        AtomicReference<String> generatedChapterIdRef = new AtomicReference<>();
        AtomicReference<String> generatedSceneIdRef = new AtomicReference<>(); // 新增 sceneId 引用
        AtomicReference<String> generatedSummaryRef = new AtomicReference<>(); // 新增 summary 引用

        // --- 步骤 1: 生成本章摘要并创建章节和初始场景 ---
        return generateSummaryAndInitialChapter(userId, params, context)
            .flatMap((CreatedChapterInfo chapterInfo) -> {
                generatedChapterIdRef.set(chapterInfo.getChapterId());
                generatedSceneIdRef.set(chapterInfo.getSceneId());
                generatedSummaryRef.set(chapterInfo.getGeneratedSummary()); // Use getter from @Data
                context.updateProgress("SUMMARY_GENERATED_AND_CHAPTER_CREATED").subscribe();

                String chapterId = chapterInfo.getChapterId();
                String generatedSummary = chapterInfo.getGeneratedSummary();

                // --- 步骤 2: (可选) 评审环节 ---
                if (params.isRequiresReview()) {
                    log.info("任务 {} 第 {} 章摘要生成完毕，等待评审。章节ID: {}", taskId, params.getChapterIndex(), chapterId);
                    // TODO: Publish ChapterSummaryReadyForReviewEvent with chapterId
                    // 返回的结果需要包含 sceneId 以便后续步骤使用
                    return Mono.just(GenerateSingleChapterResult.builder()
                            .generatedChapterId(chapterId)
                            .generatedInitialSceneId(chapterInfo.getSceneId()) // 传递 sceneId
                            .generatedSummary(generatedSummary)
                            .chapterIndex(params.getChapterIndex())
                            .contentGenerated(false)
                            .contentPersisted(false) // Content not persisted yet
                            .build());
                }

                // --- 步骤 3: 生成本章内容并更新场景 ---
                return generateContentAndUpdateScene(userId, params, chapterId, generatedSceneIdRef.get(), generatedSummary, context) // 传递 sceneId
                    .flatMap((GenerateSingleChapterResult contentResult) -> {
                        context.updateProgress("CONTENT_GENERATED").subscribe();

                        // --- 步骤 4: 准备并提交下一个子任务 (如果需要) ---
                        if (params.getChapterIndex() < params.getTotalChapters()) {
                            // 需要获取实际生成的内容来构建下一个上下文
                            // 这里假设 generateContentAndUpdateScene 的结果里没有内容本身，需要调整
                            // 或者在 generateContentAndUpdateScene 内部直接获取内容并调用 prepareAndSubmitNextTask

                            // **临时方案：** 在这里重新获取场景内容用于上下文，这不高效，后续应优化
                            return sceneService.findSceneById(generatedSceneIdRef.get()) // Use SceneService
                                   .flatMap(scene -> prepareAndSubmitNextTask(params, generatedSummaryRef.get(), scene.getContent(), context))
                                   .thenReturn(contentResult);

                        } else {
                            log.info("任务 {} 已完成最后一章 ({}/{}) 的内容生成。章节ID: {}", taskId, params.getChapterIndex(), params.getTotalChapters(), chapterId);
                            return Mono.just(contentResult);
                        }
                    });
            })
            .doOnError(e -> log.error("GenerateSingleChapterTask {} 执行失败: {}", taskId, e.getMessage()));
    }

    // 修改 generateSummary 以调用新服务方法并返回 ChapterCreationInfo
    private Mono<CreatedChapterInfo> generateSummaryAndInitialChapter(String userId, GenerateSingleChapterParameters params, TaskContext<?> context) {
        log.info("任务 {}: 正在为第 {} 章生成摘要...", context.getTaskId(), params.getChapterIndex());

        Mono<String> summaryMono = novelAIService.generateNextSingleSummary(
                userId,
                params.getNovelId(),
                params.getCurrentContext(),
                params.getAiConfigIdSummary(),
                params.getWritingStyle()
            )
            .doOnError(e -> log.error("为章节 {} 生成摘要时出错: {}", params.getChapterIndex(), e.getMessage(), e));

        return summaryMono
            .flatMap((String summary) -> {
                log.info("任务 {}: 摘要生成成功，长度: {} 字符", context.getTaskId(), summary.length());
                Mono<CreatedChapterInfo> chapterCreationMono;

                if (params.isPersistChanges()) {
                    log.info("任务 {}: 持久化摘要并创建章节和初始场景 (章节索引 {})", context.getTaskId(), params.getChapterIndex());
                    String chapterTitle = "第 " + params.getChapterIndex() + " 章"; // Or generate a better title
                    String sceneTitle = chapterTitle + " - 场景 1"; // Or use summary as title?

                    // 调用新的 Service 方法
                    chapterCreationMono = novelService.addChapterWithInitialScene(params.getNovelId(), chapterTitle, summary, sceneTitle);

                } else {
                    log.info("任务 {}: 跳过持久化 (章节索引 {})", context.getTaskId(), params.getChapterIndex());
                    // 如果不持久化，需要生成临时的 chapterId 和 sceneId
                    String tempChapterId = "temp-chapter-" + params.getNovelId() + "-" + params.getChapterIndex() + "-" + System.currentTimeMillis();
                    String tempSceneId = "temp-scene-" + tempChapterId + "-1";
                    chapterCreationMono = Mono.just(new CreatedChapterInfo(tempChapterId, tempSceneId, summary));
                }

                return chapterCreationMono;
            })
            .onErrorResume(e -> {
                log.error("任务 {}: 摘要生成及章节创建处理失败: {}", context.getTaskId(), e.getMessage(), e);
                return Mono.error(new RuntimeException("生成章节摘要或创建章节失败: " + e.getMessage(), e));
            });
    }

    // 修改 generateContent 以调用新服务方法并返回 GenerateSingleChapterResult
    private Mono<GenerateSingleChapterResult> generateContentAndUpdateScene(String userId, GenerateSingleChapterParameters params, String chapterId, String sceneId, String summary, TaskContext<?> context) {
        boolean canPersist = params.isPersistChanges() && !chapterId.startsWith("temp-chapter-");
        log.info("任务 {}: 正在为章节 {} (场景 {}, 索引 {}) 生成内容... Persist={}", context.getTaskId(), chapterId, sceneId, params.getChapterIndex(), canPersist);
        String contentContext = params.getCurrentContext() + "\n\n章节摘要:\n" + summary;

        GenerateSceneFromSummaryRequest aiRequestDto = new GenerateSceneFromSummaryRequest();
        aiRequestDto.setChapterId(chapterId);
        aiRequestDto.setSceneId(sceneId); // Pass the target scene ID
        aiRequestDto.setSummary(summary);
        aiRequestDto.setAdditionalInstructions(params.getWritingStyle());

        Mono<String> contentMono = novelAIService.generateSceneFromSummaryStream(userId, params.getNovelId(), aiRequestDto)
            .filter(chunk -> !"[DONE]".equals(chunk) && !"heartbeat".equals(chunk))
            .collect(StringBuilder::new, StringBuilder::append)
            .map(StringBuilder::toString)
            .doOnError(e -> log.error("AI内容生成失败: {}", e.getMessage()));

        return contentMono
            .flatMap((String content) -> {
                log.info("任务 {}: 内容生成成功。", context.getTaskId());
                Mono<Scene> scenePersistenceMono;

                if (canPersist) {
                    log.info("任务 {}: 持久化场景 {} 的内容。", context.getTaskId(), sceneId);
                    // 调用新的 Service 方法更新场景内容
                    scenePersistenceMono = novelService.updateSceneContent(params.getNovelId(), chapterId, sceneId, content);
                } else {
                    log.info("任务 {}: 跳过内容持久化 (场景 {})", context.getTaskId(), sceneId);
                    scenePersistenceMono = Mono.empty(); // Or find the non-persistent scene object if needed later
                }

                return scenePersistenceMono
                    .map(savedScene -> true) // Indicate persistence happened
                    .defaultIfEmpty(false) // Indicate persistence didn't happen or wasn't needed
                    .map(contentWasPersisted -> {
                        // 构建最终结果 DTO
                        return GenerateSingleChapterResult.builder()
                            .generatedChapterId(chapterId)
                            .generatedInitialSceneId(sceneId) // Pass sceneId in result
                            .generatedSummary(summary)
                            .contentGenerated(true)
                            .contentPersisted(contentWasPersisted) // Add persistence info
                            .chapterIndex(params.getChapterIndex())
                            .build();
                    });
            })
             .onErrorResume(e -> {
                log.error("任务 {}: 内容生成或更新处理失败: {}", context.getTaskId(), e.getMessage(), e);
                // 返回一个包含错误信息的 DTO 或重新抛出异常
                 return Mono.error(new RuntimeException("生成或更新场景内容失败: " + e.getMessage(), e));
            });
    }

    // 调整 prepareAndSubmitNextTask 以接收实际生成的内容
     private Mono<String> prepareAndSubmitNextTask(GenerateSingleChapterParameters currentParams, String generatedSummary, String actualGeneratedContent, TaskContext<?> context) {
        int nextChapterIndex = currentParams.getChapterIndex() + 1;
        log.info("任务 {}: 准备提交下一个章节任务 (索引 {})", context.getTaskId(), nextChapterIndex);

        String nextContext = manageContextWindow(
            currentParams.getCurrentContext(),
            currentParams.getChapterIndex(),
            generatedSummary,
            actualGeneratedContent // 使用实际内容
        );

        GenerateSingleChapterParameters nextParams = GenerateSingleChapterParameters.builder()
                .novelId(currentParams.getNovelId())
                .chapterIndex(nextChapterIndex)
                .currentContext(nextContext)
                // ... (复制其他参数) ...
                .persistChanges(currentParams.isPersistChanges())
                .build();

        return context.submitSubTask("GENERATE_SINGLE_CHAPTER", nextParams)
                .doOnNext(nextTaskId -> log.info("任务 {} 已提交下一个子任务: {} (章节索引 {})", context.getTaskId(), nextTaskId, nextChapterIndex));
    }
    
    /**
     * 智能管理上下文窗口，避免上下文过长超出LLM处理能力
     * 策略: 保留前文摘要+最后N章详细内容
     * @param currentContext 当前上下文
     * @param chapterIndex 当前章节索引
     * @param summary 当前章节摘要
     * @param content 当前章节内容
     * @return 优化后的下一章上下文
     */
    private String manageContextWindow(String currentContext, int chapterIndex, String summary, String content) {
        final int MAX_CONTEXT_LENGTH = 16000; // 设置合理的上下文最大长度
        final int KEEP_LAST_CHAPTERS = 2; // 保留最近几章的详细内容
        
        // 为本章内容添加标记，方便日后识别和截取
        String currentChapterSection = "\n\n==== 第" + chapterIndex + "章 ====\n摘要:\n" + summary + "\n\n内容:\n" + content;
        
        // 如果加入当前章节后仍然在上下文长度限制内，直接返回
        String fullContext = currentContext + currentChapterSection;
        if (fullContext.length() <= MAX_CONTEXT_LENGTH) {
            return fullContext;
        }
        
        log.info("上下文长度超出限制 ({} > {}), 启用智能窗口管理", fullContext.length(), MAX_CONTEXT_LENGTH);
        
        // 查找章节分隔标记，提取各章节内容
        String[] sections = fullContext.split("==== 第\\d+章 ====");
        if (sections.length <= KEEP_LAST_CHAPTERS + 1) {
            // 章节数量不多，但总长度超限，需要压缩前文
            String header = sections[0]; // 保留小说基本信息
            
            // 如果header太长，需要截断
            if (header.length() > MAX_CONTEXT_LENGTH / 3) {
                header = header.substring(0, MAX_CONTEXT_LENGTH / 3) + "\n...(部分内容省略)...\n";
            }
            
            // 重建上下文，只保留头部信息和最后N章
            StringBuilder optimizedContext = new StringBuilder(header);
            for (int i = Math.max(1, sections.length - KEEP_LAST_CHAPTERS); i < sections.length; i++) {
                optimizedContext.append("==== 第").append(chapterIndex - (sections.length - i)).append("章 ====");
                optimizedContext.append(sections[i]);
            }
            
            return optimizedContext.toString();
        } else {
            // 章节数量超过保留限制，只保留前文概要和最近N章
            String header = sections[0]; // 小说基本信息
            
            // 压缩前面章节为摘要形式
            StringBuilder summaryBuilder = new StringBuilder(header);
            summaryBuilder.append("\n\n==== 前文摘要 ====\n");
            
            // 对早期章节进行摘要，只提取摘要部分(不包含详细内容)
            for (int i = 1; i < sections.length - KEEP_LAST_CHAPTERS; i++) {
                String section = sections[i];
                int summaryEndPos = section.indexOf("\n\n内容:");
                if (summaryEndPos > 0) {
                    // 只保留摘要部分
                    summaryBuilder.append("- 第").append(chapterIndex - (sections.length - i)).append("章: ");
                    summaryBuilder.append(section.substring(section.indexOf("摘要:") + 4, summaryEndPos).trim());
                    summaryBuilder.append("\n");
                }
            }
            
            // 添加最近几章的完整内容
            for (int i = sections.length - KEEP_LAST_CHAPTERS; i < sections.length; i++) {
                summaryBuilder.append("==== 第").append(chapterIndex - (sections.length - i)).append("章 ====");
                summaryBuilder.append(sections[i]);
            }
            
            String result = summaryBuilder.toString();
            
            // 最后检查优化后的长度，如果仍然超限，进行强制截断
            if (result.length() > MAX_CONTEXT_LENGTH) {
                log.warn("优化后上下文仍超过长度限制 ({}), 执行强制截断", result.length());
                // 保留前1/3和后2/3的内容，中间部分省略
                int firstPartLength = MAX_CONTEXT_LENGTH / 3;
                int lastPartLength = (MAX_CONTEXT_LENGTH * 2) / 3;
                result = result.substring(0, firstPartLength) + 
                         "\n\n... (内容过长，中间部分已省略) ...\n\n" + 
                         result.substring(result.length() - lastPartLength);
            }
            
            return result;
        }
    }

    @Override
    public String getTaskType() {
        return "GENERATE_SINGLE_CHAPTER";
    }
} 