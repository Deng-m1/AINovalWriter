package com.ainovel.server.service.impl;

import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.NextOutline;
import com.ainovel.server.domain.model.UserAIModelConfig;
import com.ainovel.server.repository.NextOutlineRepository;
import com.ainovel.server.repository.NovelRepository;
import com.ainovel.server.service.NextOutlineService;
import com.ainovel.server.service.NovelAIService;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.service.SceneService;
import com.ainovel.server.service.UserAIModelConfigService;
import com.ainovel.server.service.UserService;
import com.ainovel.server.web.dto.NextOutlineDTO;
import com.ainovel.server.web.dto.OutlineGenerationChunk;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 剧情推演服务实现
 */
@Slf4j
@Service
public class NextOutlineServiceImpl implements NextOutlineService {

    private final NovelAIService novelAIService;
    private final NextOutlineRepository nextOutlineRepository;
    private final ObjectMapper objectMapper;

    // 添加用于缓存原始上下文的Map，提高单项刷新的一致性
    private final Map<String, Map<String, Object>> optionContextCache = new ConcurrentHashMap<>();
    
    // 设置上下文最大长度限制
    private static final int MAX_CONTEXT_LENGTH = 10000;

    @Autowired
    private NovelService novelService;

    @Autowired
    private SceneService sceneService;

    @Autowired
    private UserAIModelConfigService userAIModelConfigService;

    /**
     * 设置NovelService（用于测试）
     *
     * @param novelService NovelService
     */
    public void setNovelService(NovelService novelService) {
        this.novelService = novelService;
    }

    /**
     * 设置SceneService（用于测试）
     *
     * @param sceneService SceneService
     */
    public void setSceneService(SceneService sceneService) {
        this.sceneService = sceneService;
    }

    @Autowired
    public NextOutlineServiceImpl(NovelAIService novelAIService, NextOutlineRepository nextOutlineRepository, ObjectMapper objectMapper) {
        this.novelAIService = novelAIService;
        this.nextOutlineRepository = nextOutlineRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    public Mono<NextOutlineDTO.GenerateResponse> generateNextOutlines(String novelId, NextOutlineDTO.GenerateRequest request) {
        log.info("非流式生成剧情大纲: novelId={}, targetChapter={}, numOptions={}, startChapter={}, endChapter={}",
                novelId, request.getTargetChapter(), request.getNumOptions(), request.getStartChapterId(), request.getEndChapterId());

        return getCurrentUserId()
                .flatMap(userId -> {
                    return userAIModelConfigService.getValidatedDefaultConfiguration(userId)
                            .defaultIfEmpty(UserAIModelConfig.builder().build())
                            .flatMap(userConfig -> {
                                Mono<AIResponse> aiResponseMono;
                                if (request.getStartChapterId() != null || request.getEndChapterId() != null) {
                                    log.warn("非流式生成暂不支持章节范围，将尝试使用 targetChapter 作为上下文");
                                    aiResponseMono = novelAIService.generateNextOutlines(
                                            novelId,
                                            request.getTargetChapter(),
                                            request.getNumOptions(),
                                            request.getAuthorGuidance()
                                    );
                                } else {
                                    aiResponseMono = novelAIService.generateNextOutlines(
                                            novelId,
                                            request.getTargetChapter(),
                                            request.getNumOptions(),
                                            request.getAuthorGuidance()
                                    );
                                }

                                return aiResponseMono.flatMap(aiResponse -> {
                                    log.info("AI生成剧情大纲成功: {}", aiResponse.getContent());
                                    return parseAIResponseToOutlines(aiResponse, novelId, userId, request.getStartChapterId(), request.getEndChapterId(), request.getAuthorGuidance())
                                            .flatMap(outlines -> {
                                                return saveOutlines(outlines)
                                                        .thenReturn(outlines);
                                            })
                                            .map(outlines -> {
                                                List<NextOutlineDTO.OutlineItem> outlineItems = outlines.stream()
                                                        .map(this::convertToOutlineItem)
                                                        .collect(Collectors.toList());
                                                return NextOutlineDTO.GenerateResponse.builder()
                                                        .outlines(outlineItems)
                                                        .build();
                                            });
                                });
                            });
                });
    }

    @Override
    public Flux<OutlineGenerationChunk> generateNextOutlinesStream(String novelId, NextOutlineDTO.GenerateRequest request) {
        log.info("流式生成剧情大纲: novelId={}, numOptions={}, startChapter={}, endChapter={}",
                novelId, request.getNumOptions(), request.getStartChapterId(), request.getEndChapterId());

        Integer numOptions = request.getNumOptions();
        int optionsCount = (numOptions != null) ? numOptions : 3;
        String authorGuidance = request.getAuthorGuidance() != null ? request.getAuthorGuidance() : "";
        String startChapterId = request.getStartChapterId();
        String endChapterId = request.getEndChapterId();
        List<String> selectedConfigIds = request.getSelectedConfigIds();

        // 如果章节范围过大，向前端发出警告
        if (startChapterId != null && endChapterId != null) {
            novelService.getChapterRangeSummaries(novelId, startChapterId, endChapterId)
                .doOnNext(summaries -> {
                    if (summaries.length() > MAX_CONTEXT_LENGTH) {
                        log.warn("章节摘要超过最大长度({})，可能影响生成质量: novelId={}, startChapter={}, endChapter={}, 长度={}",
                            MAX_CONTEXT_LENGTH, novelId, startChapterId, endChapterId, summaries.length());
                    }
                })
                .subscribe();
        }

        Flux<OutlineGenerationChunk> generationStream;

        if (startChapterId != null || endChapterId != null) {
            generationStream = novelAIService.generateNextOutlinesStream(
                    novelId,
                    startChapterId,
                    endChapterId,
                    optionsCount,
                    authorGuidance,
                    selectedConfigIds
            );
        } else {
            String contextChapter = request.getTargetChapter();
            log.warn("未指定章节范围，将使用 targetChapter={} 作为上下文 (如果存在)", contextChapter);
            generationStream = novelAIService.generateNextOutlinesStream(
                    novelId,
                    contextChapter,
                    optionsCount,
                    authorGuidance,
                    selectedConfigIds
            );
        }

        Map<String, NextOutline> pendingOutlines = new ConcurrentHashMap<>();

        return getCurrentUserId().flatMapMany(userId -> 
            generationStream
                .doOnNext(chunk -> {
                    if (!pendingOutlines.containsKey(chunk.getOptionId())) {
                        NextOutline outline = NextOutline.builder()
                            .id(chunk.getOptionId())
                            .novelId(novelId)
                            .title(chunk.getOptionTitle())
                            .content("")
                            .createdAt(LocalDateTime.now())
                            .selected(false)
                            .originalStartChapterId(startChapterId)
                            .originalEndChapterId(endChapterId)
                            .originalAuthorGuidance(authorGuidance)
                            .build();
                        pendingOutlines.put(chunk.getOptionId(), outline);
                        
                        // 缓存该选项的上下文信息
                        Map<String, Object> contextMap = new ConcurrentHashMap<>();
                        contextMap.put("novelId", novelId);
                        contextMap.put("userId", userId);
                        contextMap.put("startChapterId", startChapterId);
                        contextMap.put("endChapterId", endChapterId);
                        contextMap.put("authorGuidance", authorGuidance);
                        contextMap.put("timestamp", System.currentTimeMillis());
                        optionContextCache.put(chunk.getOptionId(), contextMap);
                        
                        // 设置缓存超时清理
                        scheduleContextCacheCleaning(chunk.getOptionId());
                    } else {
                        NextOutline existing = pendingOutlines.get(chunk.getOptionId());
                        if (chunk.getOptionTitle() != null && !chunk.getOptionTitle().equals(existing.getTitle())) {
                            existing.setTitle(chunk.getOptionTitle());
                        }
                        existing.setContent(existing.getContent() + chunk.getTextChunk());
                    }

                    if (chunk.isFinalChunk() && chunk.getError() == null) {
                        NextOutline finalOutline = pendingOutlines.remove(chunk.getOptionId());
                        if (finalOutline != null) {
                            nextOutlineRepository.save(finalOutline)
                                .subscribe(
                                    saved -> log.debug("流式生成的大纲选项 {} 已保存", saved.getId()),
                                    error -> log.error("保存流式生成的大纲选项 {} 失败: {}", finalOutline.getId(), error.getMessage())
                                );
                        }
                    }
                })
                .doOnError(error -> {
                    log.error("流式生成剧情大纲时出错: {}", error.getMessage(), error);
                    pendingOutlines.clear();
                })
                .doOnComplete(() -> {
                    if (!pendingOutlines.isEmpty()) {
                        log.warn("流处理完成时仍有 {} 个未保存的暂存大纲，将尝试保存...", pendingOutlines.size());
                        Flux.fromIterable(pendingOutlines.values())
                            .flatMap(nextOutlineRepository::save)
                            .subscribe(
                                saved -> log.debug("清理保存暂存大纲 {} 成功", saved.getId()),
                                error -> log.error("清理保存暂存大纲失败: {}", error.getMessage())
                            );
                        pendingOutlines.clear();
                    }
                })
        );
    }

    @Override
    public Mono<NextOutlineDTO.SaveResponse> saveNextOutline(String novelId, NextOutlineDTO.SaveRequest request) {
        log.info("保存剧情大纲: novelId={}, outlineId={}, insertType={}",
                novelId, request.getOutlineId(), request.getInsertType());

        return getCurrentUserId()
                .flatMap(userId -> {
                    return nextOutlineRepository.findById(request.getOutlineId())
                            .switchIfEmpty(Mono.error(new RuntimeException("大纲不存在")))
                            .flatMap(outline -> {
                                outline.setSelected(true);
                                return nextOutlineRepository.save(outline)
                                        .flatMap(savedOutline -> {
                                            String insertType = request.getInsertType();
                                            if (insertType == null) insertType = "NEW_CHAPTER";
                                            switch (insertType) {
                                                case "NEW_CHAPTER":
                                                    return createNewChapterAndScene(novelId, savedOutline, request);
                                                case "CHAPTER_END":
                                                    return addSceneToChapterEnd(novelId, savedOutline, request);
                                                case "BEFORE_SCENE":
                                                    return addSceneBeforeTarget(novelId, savedOutline, request);
                                                case "AFTER_SCENE":
                                                    return addSceneAfterTarget(novelId, savedOutline, request);
                                                default:
                                                    return createNewChapterAndScene(novelId, savedOutline, request);
                                            }
                                        });
                            });
                });
    }

    @Override
    public Flux<OutlineGenerationChunk> regenerateOutlineOption(String novelId, NextOutlineDTO.RegenerateOptionRequest request) {
        log.info("流式重新生成单个剧情大纲: novelId={}, optionId={}, configId={}",
                novelId, request.getOptionId(), request.getSelectedConfigId());

        String optionId = request.getOptionId();

        return getCurrentUserId()
            .flatMapMany(userId -> {
                return userAIModelConfigService.getConfigurationById(userId, request.getSelectedConfigId())
                    .switchIfEmpty(Mono.error(new RuntimeException("未找到指定的模型配置")))
                    .flatMapMany(config -> {
                        // 首先尝试从缓存获取上下文信息
                        Map<String, Object> cachedContext = optionContextCache.get(optionId);
                        if (cachedContext != null) {
                            log.info("使用缓存的上下文信息重新生成大纲 {}", optionId);
                            String cachedStartChapterId = (String) cachedContext.get("startChapterId");
                            String cachedEndChapterId = (String) cachedContext.get("endChapterId");
                            String cachedAuthorGuidance = (String) cachedContext.get("authorGuidance");
                            
                            return novelAIService.regenerateSingleOutlineStream(
                                novelId,
                                optionId,
                                userId,
                                request.getSelectedConfigId(),
                                request.getRegenerateHint(),
                                cachedStartChapterId,
                                cachedEndChapterId,
                                cachedAuthorGuidance
                            )
                            .doOnNext(chunk -> handleRegenerationChunk(chunk, optionId, request));
                        }
                        
                        // 缓存未命中，回退到数据库查询
                        return nextOutlineRepository.findById(optionId)
                            .switchIfEmpty(Mono.error(new RuntimeException("未找到指定的大纲选项: " + optionId)))
                            .flatMapMany(outline -> {
                                String originalStartChapterId = outline.getOriginalStartChapterId();
                                String originalEndChapterId = outline.getOriginalEndChapterId();
                                String originalAuthorGuidance = outline.getOriginalAuthorGuidance();

                                log.info("使用数据库中的原始参数重新生成大纲 {}: start={}, end={}, guidance='{}'",
                                    optionId, originalStartChapterId, originalEndChapterId, originalAuthorGuidance);

                                // 更新缓存，以便后续请求使用
                                Map<String, Object> newContextMap = new ConcurrentHashMap<>();
                                newContextMap.put("novelId", novelId);
                                newContextMap.put("userId", userId);
                                newContextMap.put("startChapterId", originalStartChapterId);
                                newContextMap.put("endChapterId", originalEndChapterId);
                                newContextMap.put("authorGuidance", originalAuthorGuidance);
                                newContextMap.put("timestamp", System.currentTimeMillis());
                                optionContextCache.put(optionId, newContextMap);

                                // 设置缓存超时清理
                                scheduleContextCacheCleaning(optionId);

                                return novelAIService.regenerateSingleOutlineStream(
                                    novelId,
                                    optionId,
                                    userId,
                                    request.getSelectedConfigId(),
                                    request.getRegenerateHint(),
                                    originalStartChapterId,
                                    originalEndChapterId,
                                    originalAuthorGuidance
                                )
                                .doOnNext(chunk -> handleRegenerationChunk(chunk, optionId, request));
                            });
                    })
                    .onErrorResume(e -> {
                        log.error("重新生成大纲选项 {} 时出错: {}", optionId, e.getMessage(), e);
                        return Flux.just(
                            new OutlineGenerationChunk(
                                optionId,
                                "错误",
                                "重新生成失败: " + e.getMessage(),
                                true,
                                e.getMessage()
                            )
                        );
                    });
            });
    }
    
    /**
     * 处理重新生成的chunk
     */
    private void handleRegenerationChunk(OutlineGenerationChunk chunk, String optionId, NextOutlineDTO.RegenerateOptionRequest request) {
        if (chunk.isFinalChunk() && chunk.getError() == null) {
            nextOutlineRepository.findById(optionId)
                .flatMap(outline -> {
                    outline.setConfigId(request.getSelectedConfigId());
                    if (chunk.getOptionTitle() != null) {
                        outline.setTitle(chunk.getOptionTitle());
                    }
                    return nextOutlineRepository.save(outline);
                })
                .subscribe(
                    saved -> log.debug("重新生成后的大纲选项 {} 已更新并保存", optionId),
                    error -> log.error("更新重新生成的大纲选项 {} 失败: {}", optionId, error.getMessage())
                );
        }
    }
    
    /**
     * 设置上下文缓存的超时清理 (30分钟)
     */
    private void scheduleContextCacheCleaning(String optionId) {
        Mono.delay(Duration.ofMinutes(30))
            .subscribe(v -> {
                optionContextCache.remove(optionId);
                log.debug("已清理过期的上下文缓存: optionId={}", optionId);
            });
    }

    /**
     * 解析AI响应，生成大纲列表
     *
     * @param aiResponse AI响应
     * @param novelId 小说ID
     * @param userId 用户ID
     * @param originalStartChapterId 原始起始章节ID
     * @param originalEndChapterId 原始结束章节ID
     * @param originalAuthorGuidance 原始作者引导
     * @return 大纲列表
     */
    private Mono<List<NextOutline>> parseAIResponseToOutlines(AIResponse aiResponse, String novelId, String userId,
                                                            String originalStartChapterId, String originalEndChapterId, String originalAuthorGuidance) {
        try {
            List<NextOutline> outlines = parseJsonResponse(aiResponse.getContent(), novelId, originalStartChapterId, originalEndChapterId, originalAuthorGuidance);
            if (!outlines.isEmpty()) {
                 log.debug("成功解析JSON格式的AI大纲响应");
                 return Mono.just(outlines);
            }
        } catch (Exception e) {
            log.warn("解析JSON格式大纲失败，尝试解析文本格式: {}", e.getMessage());
        }
        List<NextOutline> outlines = parseTextResponse(aiResponse.getContent(), novelId, originalStartChapterId, originalEndChapterId, originalAuthorGuidance);
         log.debug("解析文本格式的AI大纲响应，共 {} 个选项", outlines.size());
        return Mono.just(outlines);
    }

    /**
     * 解析JSON格式的AI响应
     *
     * @param content AI响应内容
     * @param novelId 小说ID
     * @param originalStartChapterId 原始起始章节ID
     * @param originalEndChapterId 原始结束章节ID
     * @param originalAuthorGuidance 原始作者引导
     * @return 大纲列表
     */
    private List<NextOutline> parseJsonResponse(String content, String novelId,
                                                String originalStartChapterId, String originalEndChapterId, String originalAuthorGuidance) throws JsonProcessingException {
        List<NextOutline> outlines = new ArrayList<>();
        /*
        for (Map<String, String> rawOutline : rawOutlines) {
            NextOutline outline = NextOutline.builder()
                    .id(UUID.randomUUID().toString())
                    .novelId(novelId)
                    .title(rawOutline.getOrDefault("title", "剧情选项"))
                    .content(rawOutline.getOrDefault("content", ""))
                    .createdAt(LocalDateTime.now())
                    .selected(false)
                    .originalStartChapterId(originalStartChapterId)
                    .originalEndChapterId(originalEndChapterId)
                    .originalAuthorGuidance(originalAuthorGuidance)
                    .build();
            outlines.add(outline);
        }
        */
        if (outlines.isEmpty() && !content.trim().startsWith("[")) {
             throw new JsonProcessingException("Content does not appear to be a JSON array") {};
        }
        return outlines;
    }

    /**
     * 解析文本格式的AI响应
     *
     * @param content AI响应内容
     * @param novelId 小说ID
     * @param originalStartChapterId 原始起始章节ID
     * @param originalEndChapterId 原始结束章节ID
     * @param originalAuthorGuidance 原始作者引导
     * @return 大纲列表
     */
    private List<NextOutline> parseTextResponse(String content, String novelId,
                                                String originalStartChapterId, String originalEndChapterId, String originalAuthorGuidance) {
        List<NextOutline> outlines = new ArrayList<>();
        // 修复Linter错误，将[:：]改为正确的转义形式
        String[] sections = content.split("(?im)^\\s*(选项|大纲|剧情选项)\\s*\\d+\\s*[:\\：]\\s*");

        // 修复Linter错误，同时增强标题提取
        Pattern titlePattern = Pattern.compile("^(选项|大纲|剧情选项)\\s*\\d+\\s*[:\\：]\\s*(.*?)$", Pattern.MULTILINE);
        Matcher titleMatcher = titlePattern.matcher(content);
        List<String> titles = new ArrayList<>();
        while (titleMatcher.find()) {
             titles.add(titleMatcher.group(2).trim());
        }
        
        // 增强对标题-内容格式的识别，支持更多可能的AI输出格式
        Pattern titleContentPattern = Pattern.compile("(?im)^\\s*(标题|TITLE|Title)\\s*[:\\：]\\s*(.*?)\\s*(?:\\n|$)\\s*(内容|CONTENT|Content)\\s*[:\\：]\\s*(.+)", Pattern.DOTALL);
        Matcher titleContentMatcher = titleContentPattern.matcher(content);
        
        // 如果识别到明确的"标题:...内容:..."格式，优先处理这种格式
        if (titleContentMatcher.find()) {
            NextOutline outline = NextOutline.builder()
                .id(UUID.randomUUID().toString())
                .novelId(novelId)
                .title(titleContentMatcher.group(2).trim())
                .content(titleContentMatcher.group(4).trim())
                .createdAt(LocalDateTime.now())
                .selected(false)
                .originalStartChapterId(originalStartChapterId)
                .originalEndChapterId(originalEndChapterId)
                .originalAuthorGuidance(originalAuthorGuidance)
                .build();
            outlines.add(outline);
            
            // 重置matcher位置，尝试查找更多匹配项
            titleContentMatcher.reset();
            int matchCount = 0;
            while (titleContentMatcher.find()) {
                matchCount++;
                if (matchCount > 1) { // 跳过第一个，因为已经处理过
                    outline = NextOutline.builder()
                        .id(UUID.randomUUID().toString())
                        .novelId(novelId)
                        .title(titleContentMatcher.group(2).trim())
                        .content(titleContentMatcher.group(4).trim())
                        .createdAt(LocalDateTime.now())
                        .selected(false)
                        .originalStartChapterId(originalStartChapterId)
                        .originalEndChapterId(originalEndChapterId)
                        .originalAuthorGuidance(originalAuthorGuidance)
                        .build();
                    outlines.add(outline);
                }
            }
            
            if (!outlines.isEmpty()) {
                log.info("使用标题-内容格式成功解析 {} 个大纲选项", outlines.size());
                return outlines;
            }
        }
        
        // 回退到原始解析逻辑
        int titleIndex = 0;
        for (int i = 0; i < sections.length; i++) {
            String section = sections[i].trim();
            if (section.isEmpty() || section.matches("^(选项|大纲|剧情选项)\\s*\\d+\\s*[:\\：]")) {
                 continue;
            }

            String title;
            if (titleIndex < titles.size()) {
                 title = titles.get(titleIndex++);
            } else {
                 title = "剧情选项 " + (outlines.size() + 1);
                 log.warn("无法为第 {} 个文本大纲选项提取标题，使用默认标题: {}", outlines.size() + 1, title);
            }
            String outlineContent = section;

            NextOutline outline = NextOutline.builder()
                    .id(UUID.randomUUID().toString())
                    .novelId(novelId)
                    .title(title)
                    .content(outlineContent)
                    .createdAt(LocalDateTime.now())
                    .selected(false)
                    .originalStartChapterId(originalStartChapterId)
                    .originalEndChapterId(originalEndChapterId)
                    .originalAuthorGuidance(originalAuthorGuidance)
                    .build();
            outlines.add(outline);
        }

        if (outlines.isEmpty() && content != null && !content.isBlank()) {
             log.warn("无法按预期分割文本大纲响应，将整个内容视为单个选项");
            
            // 尝试标题和内容提取
            String title = "剧情选项";
            String contentText = content.trim();
            
            // 尝试从内容中提取标题
            Pattern extractTitlePattern = Pattern.compile("(?im)^\\s*(.*?)\\s*(?:\\n|$)");
            Matcher extractTitleMatcher = extractTitlePattern.matcher(contentText);
            if (extractTitleMatcher.find()) {
                String possibleTitle = extractTitleMatcher.group(1).trim();
                // 如果第一行不超过50个字符，可能是一个标题
                if (possibleTitle.length() <= 50) {
                    title = possibleTitle;
                    contentText = contentText.substring(extractTitleMatcher.end()).trim();
                }
            }
            
            NextOutline outline = NextOutline.builder()
                    .id(UUID.randomUUID().toString())
                    .novelId(novelId)
                    .title(title)
                    .content(contentText)
                    .createdAt(LocalDateTime.now())
                    .selected(false)
                    .originalStartChapterId(originalStartChapterId)
                    .originalEndChapterId(originalEndChapterId)
                    .originalAuthorGuidance(originalAuthorGuidance)
                    .build();
            outlines.add(outline);
        }
        return outlines;
    }

    /**
     * 保存大纲列表
     *
     * @param outlines 大纲列表
     * @return 完成信号
     */
    private Mono<Void> saveOutlines(List<NextOutline> outlines) {
        return Mono.when(
                outlines.stream()
                        .map(nextOutlineRepository::save)
                        .collect(Collectors.toList())
        );
    }

    /**
     * 将大纲转换为DTO
     *
     * @param outline 大纲
     * @return 大纲DTO
     */
    private NextOutlineDTO.OutlineItem convertToOutlineItem(NextOutline outline) {
        return NextOutlineDTO.OutlineItem.builder()
                .id(outline.getId())
                .title(outline.getTitle())
                .content(outline.getContent())
                .isSelected(outline.isSelected())
                .configId(outline.getConfigId())
                .build();
    }

    /**
     * 获取当前用户ID
     *
     * @return 当前用户ID
     */
    private Mono<String> getCurrentUserId() {
        return ReactiveSecurityContextHolder.getContext()
                .map(SecurityContext::getAuthentication)
                .filter(Authentication::isAuthenticated)
                .map(Authentication::getPrincipal)
                .cast(com.ainovel.server.domain.model.User.class)
                .map(com.ainovel.server.domain.model.User::getId)
                .switchIfEmpty(Mono.error(new RuntimeException("用户未登录")));
    }

    /**
     * 创建新章节和场景
     *
     * @param novelId 小说ID
     * @param outline 大纲
     * @param request 保存请求
     * @return 保存响应
     */
    private Mono<NextOutlineDTO.SaveResponse> createNewChapterAndScene(String novelId, NextOutline outline, NextOutlineDTO.SaveRequest request) {
        return novelService.findNovelById(novelId)
                .flatMap(novel -> {
                    String actId;
                    if (novel.getStructure() == null || novel.getStructure().getActs() == null || novel.getStructure().getActs().isEmpty()) {
                        return novelService.addAct(novelId, "第一卷", null)
                                .flatMap(updatedNovel -> {
                                    String newActId = updatedNovel.getStructure().getActs().get(0).getId();
                                    return novelService.addChapter(novelId, newActId, outline.getTitle(), null);
                                })
                                .flatMap(updatedNovel -> {
                                    String newChapterId = updatedNovel.getStructure().getActs().get(0).getChapters().get(0).getId();
                                    if (request.isCreateNewScene()) {
                                        return sceneService.addScene(novelId, newChapterId, outline.getTitle(), outline.getContent(), null)
                                                .map(scene -> {
                                                    return NextOutlineDTO.SaveResponse.builder()
                                                            .success(true)
                                                            .outlineId(outline.getId())
                                                            .newChapterId(newChapterId)
                                                            .newSceneId(scene.getId())
                                                            .insertType("NEW_CHAPTER")
                                                            .outlineTitle(outline.getTitle())
                                                            .build();
                                                });
                                    } else {
                                        return Mono.just(NextOutlineDTO.SaveResponse.builder()
                                                .success(true)
                                                .outlineId(outline.getId())
                                                .newChapterId(newChapterId)
                                                .insertType("NEW_CHAPTER")
                                                .outlineTitle(outline.getTitle())
                                                .build());
                                    }
                                });
                    } else {
                        actId = novel.getStructure().getActs().get(0).getId();
                        return novelService.addChapter(novelId, actId, outline.getTitle(), null)
                                .flatMap(updatedNovel -> {
                                    String newChapterId = null;
                                    for (var act : updatedNovel.getStructure().getActs()) {
                                        if (act.getId().equals(actId)) {
                                            int lastIndex = act.getChapters().size() - 1;
                                            newChapterId = act.getChapters().get(lastIndex).getId();
                                            break;
                                        }
                                    }
                                    if (newChapterId == null) {
                                        return Mono.error(new RuntimeException("新章节创建失败"));
                                    }
                                    final String chapterId = newChapterId;
                                    if (request.isCreateNewScene()) {
                                        return sceneService.addScene(novelId, chapterId, outline.getTitle(), outline.getContent(), null)
                                                .map(scene -> {
                                                    return NextOutlineDTO.SaveResponse.builder()
                                                            .success(true)
                                                            .outlineId(outline.getId())
                                                            .newChapterId(chapterId)
                                                            .newSceneId(scene.getId())
                                                            .insertType("NEW_CHAPTER")
                                                            .outlineTitle(outline.getTitle())
                                                            .build();
                                                });
                                    } else {
                                        return Mono.just(NextOutlineDTO.SaveResponse.builder()
                                                .success(true)
                                                .outlineId(outline.getId())
                                                .newChapterId(newChapterId)
                                                .insertType("NEW_CHAPTER")
                                                .outlineTitle(outline.getTitle())
                                                .build());
                                    }
                                });
                    }
                });
    }

    /**
     * 在现有章节末尾添加场景
     *
     * @param novelId 小说ID
     * @param outline 大纲
     * @param request 保存请求
     * @return 保存响应
     */
    private Mono<NextOutlineDTO.SaveResponse> addSceneToChapterEnd(String novelId, NextOutline outline, NextOutlineDTO.SaveRequest request) {
        if (request.getTargetChapterId() == null || request.getTargetChapterId().isEmpty()) {
            return Mono.error(new RuntimeException("目标章节ID不能为空"));
        }
        return sceneService.addScene(novelId, request.getTargetChapterId(), outline.getTitle(), outline.getContent(), null)
                .map(scene -> {
                    return NextOutlineDTO.SaveResponse.builder()
                            .success(true)
                            .outlineId(outline.getId())
                            .targetChapterId(request.getTargetChapterId())
                            .newSceneId(scene.getId())
                            .insertType("CHAPTER_END")
                            .outlineTitle(outline.getTitle())
                            .build();
                });
    }

    /**
     * 在指定场景之前添加场景
     *
     * @param novelId 小说ID
     * @param outline 大纲
     * @param request 保存请求
     * @return 保存响应
     */
    private Mono<NextOutlineDTO.SaveResponse> addSceneBeforeTarget(String novelId, NextOutline outline, NextOutlineDTO.SaveRequest request) {
        if (request.getTargetSceneId() == null || request.getTargetSceneId().isEmpty()) {
            return Mono.error(new RuntimeException("目标场景ID不能为空"));
        }
        return sceneService.findSceneById(request.getTargetSceneId())
                .flatMap(targetScene -> {
                    int targetPosition = targetScene.getSequence();
                    return sceneService.addScene(novelId, targetScene.getChapterId(), outline.getTitle(), outline.getContent(), targetPosition)
                            .map(scene -> {
                                return NextOutlineDTO.SaveResponse.builder()
                                        .success(true)
                                        .outlineId(outline.getId())
                                        .targetChapterId(targetScene.getChapterId())
                                        .targetSceneId(request.getTargetSceneId())
                                        .newSceneId(scene.getId())
                                        .insertType("BEFORE_SCENE")
                                        .outlineTitle(outline.getTitle())
                                        .build();
                            });
                });
    }

    /**
     * 在指定场景之后添加场景
     *
     * @param novelId 小说ID
     * @param outline 大纲
     * @param request 保存请求
     * @return 保存响应
     */
    private Mono<NextOutlineDTO.SaveResponse> addSceneAfterTarget(String novelId, NextOutline outline, NextOutlineDTO.SaveRequest request) {
        if (request.getTargetSceneId() == null || request.getTargetSceneId().isEmpty()) {
            return Mono.error(new RuntimeException("目标场景ID不能为空"));
        }
        return sceneService.findSceneById(request.getTargetSceneId())
                .flatMap(targetScene -> {
                    int targetPosition = targetScene.getSequence() + 1;
                    return sceneService.addScene(novelId, targetScene.getChapterId(), outline.getTitle(), outline.getContent(), targetPosition)
                            .map(scene -> {
                                return NextOutlineDTO.SaveResponse.builder()
                                        .success(true)
                                        .outlineId(outline.getId())
                                        .targetChapterId(targetScene.getChapterId())
                                        .targetSceneId(request.getTargetSceneId())
                                        .newSceneId(scene.getId())
                                        .insertType("AFTER_SCENE")
                                        .outlineTitle(outline.getTitle())
                                        .build();
                            });
                });
    }
}
