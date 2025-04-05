package com.ainovel.server.service.impl;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;
import java.util.stream.Stream;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.http.codec.multipart.FilePart;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.dto.ParsedNovelData;
import com.ainovel.server.domain.dto.ParsedSceneData;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.repository.NovelRepository;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.ImportService;
import com.ainovel.server.service.IndexingService;
import com.ainovel.server.service.NovelParser;
import com.ainovel.server.web.dto.ImportStatus;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.publisher.Sinks;
import reactor.core.scheduler.Schedulers;

/**
 * 小说导入服务实现类
 */
@Slf4j
@Service
public class ImportServiceImpl implements ImportService {

    private final NovelRepository novelRepository;
    private final SceneRepository sceneRepository;
    private final IndexingService indexingService;
    private final List<NovelParser> parsers;

    // 使用ConcurrentHashMap存储活跃的导入任务Sink
    private final Map<String, Sinks.Many<ServerSentEvent<ImportStatus>>> activeJobSinks = new ConcurrentHashMap<>();
    
    // 用于跟踪任务是否被取消的标记
    private final Map<String, Boolean> cancelledJobs = new ConcurrentHashMap<>();
    
    // 用于跟踪处理任务的临时文件路径
    private final Map<String, Path> jobTempFiles = new ConcurrentHashMap<>();
    
    // 用于存储jobId到novelId的映射关系
    private final Map<String, String> jobToNovelIdMap = new ConcurrentHashMap<>();
    
    // 用于存储进度更新订阅
    private final Map<String, reactor.core.Disposable> progressUpdateSubscriptions = new ConcurrentHashMap<>();

    @Autowired
    public ImportServiceImpl(
            NovelRepository novelRepository,
            SceneRepository sceneRepository,
            IndexingService indexingService,
            List<NovelParser> parsers) {
        this.novelRepository = novelRepository;
        this.sceneRepository = sceneRepository;
        this.indexingService = indexingService;
        this.parsers = parsers;
    }

    @Override
    public Mono<String> startImport(FilePart filePart, String userId) {
        String jobId = UUID.randomUUID().toString();
        Path tempFilePath = null; // 用于后续清理
        try {
            // 1. 创建 Sink 并存储
            Sinks.Many<ServerSentEvent<ImportStatus>> sink = Sinks.many().multicast().onBackpressureBuffer();
            activeJobSinks.put(jobId, sink);
            log.info("创建 Sink 并存储 {}", jobId);

            // 2. 创建临时文件路径 (不立即创建文件)
            tempFilePath = Files.createTempFile("import-", "-" + filePart.filename());
            jobTempFiles.put(jobId, tempFilePath);
            final Path finalTempFilePath = tempFilePath; // For use in lambda

            // 3. 定义文件传输和处理的响应式管道
            Mono<Void> processingPipeline = filePart.transferTo(finalTempFilePath) // transferTo 是响应式的
                    .then(Mono.defer(() -> processAndSaveNovel(jobId, finalTempFilePath, filePart.filename(), userId, sink)) // 核心处理逻辑
                            .subscribeOn(Schedulers.boundedElastic()) // 在弹性线程池执行核心逻辑
                    )
                    .doOnError(e -> { // 处理管道中的错误
                        log.error("Import pipeline error for job {}", jobId, e);
                        sink.tryEmitNext(createStatusEvent(jobId, "FAILED", "导入失败: " + e.getMessage()));
                        sink.tryEmitComplete();
                        activeJobSinks.remove(jobId); // 清理 Sink
                        cancelledJobs.remove(jobId); // 清理取消标记
                        cleanupTempFile(jobId); // 清理临时文件
                    })
                    .doFinally(signalType -> { // 清理临时文件
                        cleanupTempFile(jobId); // 清理临时文件
                        
                        // 确保 Sink 被移除，即使没有错误但正常完成
                        if (activeJobSinks.containsKey(jobId)) {
                            activeJobSinks.remove(jobId);
                        }
                        
                        // 移除取消标记
                        cancelledJobs.remove(jobId);
                    });

            // 4. 异步订阅并启动管道 (Fire-and-forget)
            processingPipeline.subscribe(
                    null, // onNext - not needed for Mono<Void>
                    error -> log.error("Error subscribing to processing pipeline for job {}", jobId, error) // Log subscription errors
            );

            // 5. 立即返回 Job ID
            return Mono.just(jobId);

        } catch (IOException e) {
            log.error("Failed to create temporary file for import", e);
            // 如果创建临时文件失败，也需要处理
            cleanupTempFile(jobId);
            
            // 移除可能已添加的Sink和取消标记
            activeJobSinks.remove(jobId);
            cancelledJobs.remove(jobId);
            
            return Mono.error(new RuntimeException("无法启动导入任务：无法创建临时文件", e));
        }
    }

    /**
     * 清理临时文件
     */
    private void cleanupTempFile(String jobId) {
        Path tempPath = jobTempFiles.remove(jobId);
        if (tempPath != null && Files.exists(tempPath)) {
            try {
                Files.delete(tempPath);
                log.info("Deleted temporary file for job {}: {}", jobId, tempPath);
            } catch (IOException e) {
                log.error("Failed to delete temporary file for job {}: {}", jobId, tempPath, e);
            }
        }
    }

    @Override
    public Flux<ServerSentEvent<ImportStatus>> getImportStatusStream(String jobId) {
        log.info(">>> getImportStatusStream started for jobID: {}", jobId);
        Sinks.Many<ServerSentEvent<ImportStatus>> sink = activeJobSinks.get(jobId);
        log.info(">>> Sink found for job {}: {}", jobId, (sink != null));

        if (sink != null) {
            // 添加心跳机制，每30秒发送一次注释行作为心跳
            log.info(">>> Returning sink.asFlux() for job {}", jobId);
            return sink.asFlux().log("sse-stream-" + jobId); // Return the business event stream directly

        } else {
            log.warn(">>> Sink not found for job {}, returning ERROR event.", jobId);
             return Flux.just(
                    ServerSentEvent.<ImportStatus>builder()
                            .id(jobId)
                            .event("import-status")
                            .data(new ImportStatus("ERROR", "任务不存在或已完成"))
                            .build()
            );
        }
    }

    /**
     * 处理并保存小说（运行在boundedElastic调度器上）
     */
    private Mono<Void> processAndSaveNovel(
            String jobId,
            Path tempFilePath,
            String originalFilename,
            String userId,
            Sinks.Many<ServerSentEvent<ImportStatus>> sink) {

        return Mono.fromCallable(() -> {
            // 检查是否已取消
            if (isCancelled(jobId)) {
                log.info("Job {} 已被取消，不再继续处理", jobId);
                throw new InterruptedException("导入任务已被用户取消");
            }
            
            sink.tryEmitNext(createStatusEvent(jobId, "PROCESSING", "开始解析文件..."));
            log.info("Job {}: Processing file {}", jobId, originalFilename);

            NovelParser parser = getParserForFile(originalFilename);

            // 尝试使用不同的字符编码进行文件读取
            ParsedNovelData parsedData;
            try {
                // 检查是否已取消
                if (isCancelled(jobId)) {
                    throw new InterruptedException("导入任务已被用户取消");
                }
                
                // 首先尝试 UTF-8
                try (Stream<String> lines = Files.lines(tempFilePath, StandardCharsets.UTF_8)) {
                    parsedData = parser.parseStream(lines);
                }catch (java.nio.charset.MalformedInputException e) {
                    // 检查是否已取消
                    if (isCancelled(jobId)) {
                        throw new InterruptedException("导入任务已被用户取消");
                    }
                    
                    log.info("Job {}: UTF-8 encoding failed, trying GBK encoding", jobId);
                    sink.tryEmitNext(createStatusEvent(jobId, "PROCESSING", "UTF-8 编码识别失败，尝试 GBK 编码..."));

                    // UTF-8 失败，尝试 GBK 编码
                    try (java.io.BufferedReader reader = new java.io.BufferedReader(
                            new java.io.InputStreamReader(
                                    new java.io.FileInputStream(tempFilePath.toFile()),
                                    "GBK"))) {

                        Stream<String> lines = reader.lines();
                        parsedData = parser.parseStream(lines);
                    } catch (Exception e2) {
                        // 检查是否已取消
                        if (isCancelled(jobId)) {
                            throw new InterruptedException("导入任务已被用户取消");
                        }
                        
                        log.info("Job {}: GBK encoding failed, trying GB18030 encoding", jobId);
                        sink.tryEmitNext(createStatusEvent(jobId, "PROCESSING", "GBK 编码识别失败，尝试 GB18030 编码..."));

                        // GBK 也失败，最后尝试 GB18030
                        try (java.io.BufferedReader reader = new java.io.BufferedReader(
                                new java.io.InputStreamReader(
                                        new java.io.FileInputStream(tempFilePath.toFile()),
                                        "GB18030"))) {

                            Stream<String> lines = reader.lines();
                            parsedData = parser.parseStream(lines);
                        }
                }
            }

                // 检查是否已取消
                if (isCancelled(jobId)) {
                    throw new InterruptedException("导入任务已被用户取消");
                }
                
                // 设置小说标题（如果解析器未设置）
                if (parsedData.getNovelTitle() == null || parsedData.getNovelTitle().isEmpty()) {
                    String title = extractTitleFromFilename(originalFilename);
                    parsedData.setNovelTitle(title);
                }

                log.info("Job {}: Parsed data obtained. Scene count: {}", jobId, parsedData.getScenes().size());
                sink.tryEmitNext(createStatusEvent(jobId, "SAVING", "解析完成，发现 " + parsedData.getScenes().size() + " 个场景，正在保存小说结构..."));

                log.info("Job {}: About to call saveNovelAndScenesReactive...", jobId);
                // 现在调用 saveNovelAndScenesReactive
                return saveNovelAndScenesReactive(parsedData, userId)
                        .flatMap(savedNovel -> {
                            // 检查是否已取消
                            if (isCancelled(jobId)) {
                                return Mono.error(new InterruptedException("导入任务已被用户取消"));
                            }
                            
                            log.info("Job {}: Novel and scenes saved successfully. Novel ID: {}", jobId, savedNovel.getId());
                            sink.tryEmitNext(createStatusEvent(jobId, "INDEXING", "小说结构保存完成，正在为 RAG 创建索引..."));

                            // 创建一个定时发送进度更新的流
                            Flux<Long> progressUpdates = Flux.interval(java.time.Duration.ofSeconds(10))
                                .doOnNext(tick -> {
                                    // 检查是否被取消
                                    if (isCancelled(jobId)) {
                                        log.warn("Job {}: 检测到任务已取消，停止进度更新", jobId);
                                        throw new RuntimeException("任务已取消");
                                    }
                                    
                                    String message = String.format("正在为 RAG 创建索引，已处理 %d 秒，请耐心等待...", (tick + 1) * 10);
                                    log.info("Job {}: Sending progress update: {}", jobId, message);
                                    sink.tryEmitNext(createStatusEvent(jobId, "INDEXING", message));
                                });

                            // 触发 RAG 索引，同时发送进度更新
                            return Mono.defer(() -> {
                                // 开始发送进度更新，使用线程安全的方式存储 Disposable
                                final java.util.concurrent.atomic.AtomicReference<reactor.core.Disposable> progressRef = 
                                    new java.util.concurrent.atomic.AtomicReference<>();
                                
                                log.info("Job {}: Starting progress updates", jobId);
                                var subscription = progressUpdates
                                    .doOnSubscribe(s -> log.info("Job {}: Progress updates subscribed", jobId))
                                    .doOnCancel(() -> log.info("Job {}: Progress updates cancelled", jobId))
                                    .onErrorResume(error -> {
                                        // 如果是因为取消而产生的错误，记录日志但不继续传播错误
                                        if (error.getMessage() != null && error.getMessage().contains("任务已取消")) {
                                            log.info("Job {}: Progress updates stopped due to task cancellation", jobId);
                                            return Flux.empty();
                                        }
                                        log.warn("Job {}: Progress updates error: {}", jobId, error.getMessage());
                                        return Flux.error(error);
                                    })
                                    .subscribe();
                                
                                progressRef.set(subscription);
                                // 存储订阅以便可以在取消时使用
                                progressUpdateSubscriptions.put(jobId, subscription);
                                
                                // 执行实际的索引操作，使用 blocking 模式，确保索引完成
                                return indexingService.indexNovel(savedNovel.getId())
                                    .doOnSubscribe(s -> {
                                        // 保存jobId和novelId的映射关系，以便后续取消操作
                                        jobToNovelIdMap.put(jobId, savedNovel.getId());
                                        log.info("Job {}: 已建立与Novel ID: {}的映射关系", jobId, savedNovel.getId());
                                    })
                                    .doOnSuccess(result -> {
                                        // 检查是否被取消
                                        if (isCancelled(jobId)) {
                                            return;
                                        }
                                        
                                        log.info("Job {}: RAG indexing successfully completed for Novel ID: {}", jobId, savedNovel.getId());
                                        // 确保取消进度更新
                                        try {
                                            var disposable = progressRef.getAndSet(null);
                                            if (disposable != null) {
                                                disposable.dispose();
                                                log.info("Job {}: Progress updates disposed after success", jobId);
                                            }
                                            
                                            // 清理进度更新订阅
                                            progressUpdateSubscriptions.remove(jobId);
                                            
                                            // 清理映射关系
                                            jobToNovelIdMap.remove(jobId);
                                        } catch (Exception e) {
                                            log.error("Job {}: Error disposing progress updates", jobId, e);
                                        }
                                        // 发送完成通知
                                        sink.tryEmitNext(createStatusEvent(jobId, "COMPLETED", "导入和索引成功完成！"));
                                        sink.tryEmitComplete();
                                    })
                                    .doOnError(error -> {
                                        log.error("Job {}: RAG indexing failed for Novel ID: {}", jobId, savedNovel.getId(), error);
                                        // 确保取消进度更新
                                        try {
                                            var disposable = progressRef.getAndSet(null);
                                            if (disposable != null) {
                                                disposable.dispose();
                                                log.info("Job {}: Progress updates disposed after error", jobId);
                                            }
                                            
                                            // 清理进度更新订阅
                                            progressUpdateSubscriptions.remove(jobId);
                                            
                                            // 清理映射关系
                                            jobToNovelIdMap.remove(jobId);
                                        } catch (Exception e) {
                                            log.error("Job {}: Error disposing progress updates", jobId, e);
                                        }
                                        // 发送失败通知
                                        sink.tryEmitNext(createStatusEvent(jobId, "FAILED", "RAG 索引失败: " + error.getMessage()));
                                        sink.tryEmitComplete();
                                    });
                            });
                        });
            } catch (IOException e) {
                log.error("Job {}: Error reading temporary file {}", jobId, tempFilePath, e);
                throw new RuntimeException("文件读取错误", e); // 重新抛出以便上层处理
            } catch (InterruptedException e) {
                log.info("Job {}: 导入任务被取消", jobId);
                throw e; // 将中断异常传递给上层
            }
        }).flatMap(Function.identity()) // 展平 Mono<Mono<Void>>
                .doOnError(e -> { // 捕获 processAndSaveNovel 内部的同步异常或响应式链中的错误
                    // 检查是否是取消导致的错误
                    if (e instanceof InterruptedException) {
                        log.info("Job {}: Import was cancelled by user", jobId);
                        sink.tryEmitNext(createStatusEvent(jobId, "CANCELLED", "导入任务已被用户取消"));
                    } else {
                        log.error("Job {}: Processing failed.", jobId, e);
                        sink.tryEmitNext(createStatusEvent(jobId, "FAILED", "导入处理失败: " + e.getMessage()));
                    }
                    sink.tryEmitComplete();
                }).then(); // 转换为 Mono<Void>
    }
    
    /**
     * 检查任务是否已被取消
     */
    private boolean isCancelled(String jobId) {
        boolean cancelled = cancelledJobs.getOrDefault(jobId, false);
        if (cancelled) {
            log.debug("任务已被标记为取消状态: {}", jobId);
        }
        return cancelled;
    }

    /**
     * 保存小说和场景（响应式方式）
     */
    private Mono<Novel> saveNovelAndScenesReactive(ParsedNovelData parsedData, String userId) {
        log.info(">>> saveNovelAndScenesReactive started for novel: {} userId: {} ", parsedData.getNovelTitle(),userId);
        LocalDateTime now = LocalDateTime.now();

        // 创建Novel对象
        Novel novel = Novel.builder()
                .title(parsedData.getNovelTitle())
                .author(Novel.Author.builder().id(userId).build())
                .status("draft")
                .createdAt(now)
                .updatedAt(now)
                .build();

        // 先保存小说
        log.info(">>> Attempting to save novel: {}", novel.getTitle());
        return novelRepository.save(novel)
                .flatMap(savedNovel -> {
                    log.info(">>> Novel saved successfully with ID: {}", savedNovel.getId()); // 保存成功日志
                    List<Scene> scenes = new ArrayList<>();

                    // 创建场景列表 - 每个解析出的章节单独一个章节，每个章节默认创建一个场景
                    for (int i = 0; i < parsedData.getScenes().size(); i++) {
                        ParsedSceneData parsedScene = parsedData.getScenes().get(i);
                        
                        // 使用UUID生成场景ID，与前端保持一致
                        String sceneId = UUID.randomUUID().toString();

                        
                        // 将普通文本转换为富文本格式
                        String richTextContent = convertToRichText(parsedScene.getSceneContent());
                        
                        Scene scene = Scene.builder()
                                .id(sceneId)
                                .novelId(savedNovel.getId())
                                .title(parsedScene.getSceneTitle())
                                .content(richTextContent)
                                .summary("")
                                .sequence(parsedScene.getOrder())
                                .sceneType("NORMAL")
                                .characterIds(new ArrayList<>())
                                .locations(new ArrayList<>())
                                .version(0)
                                .history(new ArrayList<>())
                                .createdAt(now)
                                .updatedAt(now)
                                .build();

                        scenes.add(scene);
                    }

                    // 批量保存场景
                    return sceneRepository.saveAll(scenes)
                            .collectList()
                            .flatMap(savedScenes -> {
                                // 统计字数
                                int totalWords = savedScenes.stream()
                                        .mapToInt(scene -> scene.getContent() != null ? scene.getContent().length() : 0)
                                        .sum();

                                // 估算阅读时间 (假设平均阅读速度为每分钟300字)
                                int readTimeMinutes = (int) Math.ceil(totalWords / 300.0);

                                // 更新Novel的元数据
                                savedNovel.getMetadata().setWordCount(totalWords);
                                savedNovel.getMetadata().setReadTime(readTimeMinutes);
                                savedNovel.getMetadata().setLastEditedAt(now);
                                savedNovel.getMetadata().setVersion(1);

                                // 创建基本结构 - 一个卷，每个场景一个章节
                                Novel.Act act = Novel.Act.builder()
                                        .id(UUID.randomUUID().toString())
                                        .title("第一卷")
                                        .description("")
                                        .order(0)
                                        .chapters(new ArrayList<>())
                                        .build();

                                // 创建章节并更新场景的chapterId
                                List<Scene> updatedScenes = new ArrayList<>();
                                
                                for (int i = 0; i < savedScenes.size(); i++) {
                                    Scene scene = savedScenes.get(i);
                                    // 生成章节ID，格式为"chapter_" + UUID
                                    String chapterId = "chapter_" + UUID.randomUUID().toString();
                                    
                                    Novel.Chapter chapter = Novel.Chapter.builder()
                                            .id(chapterId)
                                            .title(scene.getTitle())
                                            .description("")
                                            .order(i)
                                            .sceneIds(List.of(scene.getId()))
                                            .build();
                                    
                                    // 更新场景的chapterId
                                    scene.setChapterId(chapterId);
                                    updatedScenes.add(scene);
                                    
                                    // 添加章节到卷中
                                    act.getChapters().add(chapter);
                                    if (i==0)savedNovel.setLastEditedChapterId(chapterId);
                                }

                                savedNovel.getStructure().getActs().add(act);

                                // 保存更新后的场景和小说
                                return sceneRepository.saveAll(updatedScenes)
                                        .collectList()
                                        .then(novelRepository.save(savedNovel));
                            });
                });
    }

    /**
     * 根据文件名获取对应的解析器
     */
    private NovelParser getParserForFile(String filename) {
        String extension = getFileExtension(filename).toLowerCase();

        // 查找支持该扩展名的解析器
        return parsers.stream()
                .filter(parser -> parser.getSupportedExtension().equalsIgnoreCase(extension))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("不支持的文件类型: " + extension));
    }

    /**
     * 从文件名中提取文件扩展名
     */
    private String getFileExtension(String filename) {
        int lastDotPosition = filename.lastIndexOf('.');
        if (lastDotPosition > 0) {
            return filename.substring(lastDotPosition + 1);
        }
        return "";
    }

    /**
     * 从文件名中提取小说标题
     */
    private String extractTitleFromFilename(String filename) {
        int lastDotPosition = filename.lastIndexOf('.');
        if (lastDotPosition > 0) {
            String nameWithoutExtension = filename.substring(0, lastDotPosition);
            return nameWithoutExtension.replaceAll("[-_]", " ").trim();
        }
        return filename;
    }

    /**
     * 创建SSE状态事件
     */
    private ServerSentEvent<ImportStatus> createStatusEvent(String jobId, String status, String message) {
        return ServerSentEvent.<ImportStatus>builder()
                .id(jobId)
                .event("import-status")
                .data(new ImportStatus(status, message))
                .build();
    }
    
    /**
     * 取消导入任务
     */
    @Override
    public Mono<Boolean> cancelImport(String jobId) {
        log.info("接收到取消导入任务请求: {}", jobId);
        
        // 获取任务的Sink
        Sinks.Many<ServerSentEvent<ImportStatus>> sink = activeJobSinks.get(jobId);
        
        if (sink == null) {
            log.warn("取消导入任务失败: 任务 {} 不存在或已完成", jobId);
            return Mono.just(false);
        }
        
        try {
            // 先取消进度更新订阅，避免继续发送进度消息
            reactor.core.Disposable subscription = progressUpdateSubscriptions.remove(jobId);
            if (subscription != null && !subscription.isDisposed()) {
                subscription.dispose();
                log.info("Job {}: 已取消进度更新订阅", jobId);
            }
            
            // 标记任务为已取消
            cancelledJobs.put(jobId, true);
            
            // 发送取消状态到客户端
            sink.tryEmitNext(createStatusEvent(jobId, "CANCELLED", "导入任务已取消"));
            
            // 完成Sink
            sink.tryEmitComplete();
            
            // 从活跃任务中移除
            activeJobSinks.remove(jobId);
            
            // 清理临时文件
            cleanupTempFile(jobId);
            
            // 尝试取消索引任务
            try {
                // 首先，尝试使用jobId直接取消（可能正在执行的是前置任务）
                boolean cancelled = indexingService.cancelIndexingTask(jobId);
                
                // 其次，检查是否有关联的novelId，如果有，也尝试取消它
                String novelId = jobToNovelIdMap.get(jobId);
                if (novelId != null) {
                    // 使用关联的novelId取消索引任务
                    boolean novelCancelled = indexingService.cancelIndexingTask(novelId);
                    log.info("使用novelId({})取消索引任务: {}", novelId, novelCancelled ? "成功" : "失败或不需要");
                    cancelled = cancelled || novelCancelled;
                }
                
                // 清理映射关系
                jobToNovelIdMap.remove(jobId);
                
                log.info("已经发送取消信号到索引任务: {} (结果: {})", jobId, cancelled ? "成功" : "失败或不需要");
            } catch (Exception e) {
                log.warn("尝试取消索引任务时出错，但不影响导入取消操作: {}", e.getMessage());
            }
            
            log.info("成功取消导入任务: {}", jobId);
            return Mono.just(true);
        } catch (Exception e) {
            log.error("取消导入任务异常: {}", jobId, e);
            return Mono.just(false);
        }
    }

    /**
     * 将普通文本转换为富文本JSON格式
     * 富文本格式示例: [{\"insert\":\"文本内容\\n\"}]
     */
    private String convertToRichText(String plainText) {
        if (plainText == null || plainText.isEmpty()) {
            return "[{\"insert\":\"\\n\"}]";
        }
        
        // 处理文本中的特殊字符
        String escaped = plainText
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\r\n", "\\n")
                .replace("\n", "\\n")
                .replace("\t", "    ");
        
        // 确保文本以换行符结束
        if (!escaped.endsWith("\\n")) {
            escaped += "\\n";
        }
        
        return "[{\"insert\":\"" + escaped + "\"}]";
    }
}
