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

            // 2. 创建临时文件路径 (不立即创建文件)
            tempFilePath = Files.createTempFile("import-", "-" + filePart.filename());
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
                    })
                    .doFinally(signalType -> { // 清理临时文件
                        try {
                            if (finalTempFilePath != null && Files.exists(finalTempFilePath)) {
                                Files.delete(finalTempFilePath);
                                log.info("Deleted temporary file for job {}: {}", jobId, finalTempFilePath);
                            }
                        } catch (IOException e) {
                            log.error("Failed to delete temporary file for job {}: {}", jobId, finalTempFilePath, e);
                        }
                        // 确保 Sink 被移除，即使没有错误但正常完成
                        if (activeJobSinks.containsKey(jobId)) {
                            activeJobSinks.remove(jobId);
                        }
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
            if (tempFilePath != null) {
                try {
                    Files.deleteIfExists(tempFilePath);
                } catch (IOException ignored) {
                }
            }
            return Mono.error(new RuntimeException("无法启动导入任务：无法创建临时文件", e));
        }
    }

    @Override
    public Flux<ServerSentEvent<ImportStatus>> getImportStatusStream(String jobId) {
        Sinks.Many<ServerSentEvent<ImportStatus>> sink = activeJobSinks.get(jobId);
        if (sink != null) {
            return sink.asFlux();
        } else {
            // 任务不存在或已完成
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
            sink.tryEmitNext(createStatusEvent(jobId, "PROCESSING", "开始解析文件..."));
            log.info("Job {}: Processing file {}", jobId, originalFilename);

            NovelParser parser = getParserForFile(originalFilename);

            // 使用 Files.lines 进行流式读取和解析
            try (Stream<String> lines = Files.lines(tempFilePath, StandardCharsets.UTF_8)) {
                // 解析文件内容
                ParsedNovelData parsedData = parser.parseStream(lines);

                // 设置小说标题（如果解析器未设置）
                if (parsedData.getNovelTitle() == null || parsedData.getNovelTitle().isEmpty()) {
                    String title = extractTitleFromFilename(originalFilename);
                    parsedData.setNovelTitle(title);
                }

                log.info("Job {}: Parsing complete, found {} scenes.", jobId, parsedData.getScenes().size());
                sink.tryEmitNext(createStatusEvent(jobId, "SAVING", "正在保存小说结构..."));

                // 保存 Novel 和 Scenes (响应式)
                return saveNovelAndScenesReactive(parsedData, userId)
                        .flatMap(savedNovel -> {
                            log.info("Job {}: Novel and scenes saved successfully. Novel ID: {}", jobId, savedNovel.getId());
                            sink.tryEmitNext(createStatusEvent(jobId, "INDEXING", "正在为 RAG 创建索引..."));

                            // 触发 RAG 索引
                            return indexingService.indexNovel(savedNovel.getId())
                                    .doOnSuccess(v -> {
                                        log.info("Job {}: RAG indexing triggered/completed for Novel ID: {}", jobId, savedNovel.getId());
                                        sink.tryEmitNext(createStatusEvent(jobId, "COMPLETED", "导入成功！"));
                                        sink.tryEmitComplete(); // 成功完成
                                    })
                                    .doOnError(e -> { // 处理索引错误
                                        log.error("Job {}: RAG indexing failed for Novel ID: {}", jobId, savedNovel.getId(), e);
                                        sink.tryEmitNext(createStatusEvent(jobId, "FAILED", "RAG 索引失败: " + e.getMessage()));
                                        sink.tryEmitComplete();
                                    });
                        });
            } catch (IOException e) {
                log.error("Job {}: Error reading temporary file {}", jobId, tempFilePath, e);
                throw new RuntimeException("文件读取错误", e); // 重新抛出以便上层处理
            }
        }).flatMap(Function.identity()) // 展平 Mono<Mono<Void>>
                .doOnError(e -> { // 捕获 processAndSaveNovel 内部的同步异常或响应式链中的错误
                    log.error("Job {}: Processing failed.", jobId, e);
                    sink.tryEmitNext(createStatusEvent(jobId, "FAILED", "导入处理失败: " + e.getMessage()));
                    sink.tryEmitComplete();
                }).then(); // 转换为 Mono<Void>
    }

    /**
     * 保存小说和场景（响应式方式）
     */
    private Mono<Novel> saveNovelAndScenesReactive(ParsedNovelData parsedData, String userId) {
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
        return novelRepository.save(novel)
                .flatMap(savedNovel -> {
                    List<Scene> scenes = new ArrayList<>();

                    // 创建场景列表 - 每个解析出的章节成为一个场景
                    for (int i = 0; i < parsedData.getScenes().size(); i++) {
                        ParsedSceneData parsedScene = parsedData.getScenes().get(i);

                        Scene scene = Scene.builder()
                                .novelId(savedNovel.getId())
                                .title(parsedScene.getSceneTitle())
                                .content(parsedScene.getSceneContent())
                                .sequence(parsedScene.getOrder())
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
                                        .order(0)
                                        .chapters(new ArrayList<>())
                                        .build();

                                for (int i = 0; i < savedScenes.size(); i++) {
                                    Scene scene = savedScenes.get(i);
                                    Novel.Chapter chapter = Novel.Chapter.builder()
                                            .id(UUID.randomUUID().toString())
                                            .title(scene.getTitle())
                                            .order(i)
                                            .sceneIds(List.of(scene.getId()))
                                            .build();

                                    act.getChapters().add(chapter);
                                }

                                savedNovel.getStructure().getActs().add(act);

                                // 保存更新后的小说信息
                                return novelRepository.save(savedNovel);
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
}
