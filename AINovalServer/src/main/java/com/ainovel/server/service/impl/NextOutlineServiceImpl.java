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

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 剧情推演服务实现
 */
@Slf4j
@Service
public class NextOutlineServiceImpl implements NextOutlineService {

    private final NovelAIService novelAIService;
    private final NextOutlineRepository nextOutlineRepository;
    private final ObjectMapper objectMapper;

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
        log.info("生成剧情大纲: novelId={}, targetChapter={}, numOptions={}",
                novelId, request.getTargetChapter(), request.getNumOptions());

        // 获取当前用户ID
        return getCurrentUserId()
                .flatMap(userId -> {
                    // 获取用户的AI模型配置
                    return userAIModelConfigService.getValidatedDefaultConfiguration(userId)
                            .defaultIfEmpty(UserAIModelConfig.builder().build()) // 如果没有配置，使用空配置
                            .flatMap(userConfig -> {
                                // 调用AI服务生成大纲，传入用户配置
                                return novelAIService.generateNextOutlines(
                                        novelId,
                                        request.getTargetChapter(),
                                        request.getNumOptions(),
                                        request.getAuthorGuidance()
                                )
                                .flatMap(aiResponse -> {
                                    log.info("AI生成剧情大纲成功: {}", aiResponse.getContent());

                                    // 解析AI响应，生成大纲列表
                                    return parseAIResponseToOutlines(aiResponse, novelId, userId)
                                            .flatMap(outlines -> {
                                                // 保存大纲到数据库
                                                return saveOutlines(outlines)
                                                        .thenReturn(outlines);
                                            })
                                            .map(outlines -> {
                                                // 转换为DTO响应
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
    public Flux<String> generateNextOutlinesStream(String novelId, NextOutlineDTO.GenerateRequest request) {
        log.info("流式生成剧情大纲: novelId={}, startChapter={}, endChapter={}, numOptions={}",
                novelId, request.getStartChapterId(), request.getEndChapterId(), request.getNumOptions());

        // 获取当前用户ID
        return getCurrentUserId()
                .flatMapMany(userId -> {
                    // 获取用户的AI模型配置
                    return userAIModelConfigService.getValidatedDefaultConfiguration(userId)
                            .defaultIfEmpty(UserAIModelConfig.builder().build()) // 如果没有配置，使用空配置
                            .flatMapMany(userConfig -> {
                                // 调用AI服务流式生成大纲，传入用户配置
                                if (request.getStartChapterId() != null && request.getEndChapterId() != null) {
                                    // 使用起止章节范围作为上下文
                                    return novelAIService.generateNextOutlinesStream(
                                            novelId,
                                            request.getStartChapterId(),
                                            request.getEndChapterId(),
                                            request.getNumOptions(),
                                            request.getAuthorGuidance()
                                    );
                                } else {
                                    // 兼容老接口，使用单一章节作为上下文
                                    String contextChapterId = request.getStartChapterId() != null ? 
                                            request.getStartChapterId() : request.getTargetChapter();
                                    
                                    return novelAIService.generateNextOutlinesStream(
                                            novelId,
                                            contextChapterId,
                                            request.getNumOptions(),
                                            request.getAuthorGuidance()
                                    );
                                }
                            });
                });
    }

    @Override
    public Mono<NextOutlineDTO.SaveResponse> saveNextOutline(String novelId, NextOutlineDTO.SaveRequest request) {
        log.info("保存剧情大纲: novelId={}, outlineId={}, insertType={}",
                novelId, request.getOutlineId(), request.getInsertType());

        // 获取当前用户ID
        return getCurrentUserId()
                .flatMap(userId -> {
                    // 查找大纲
                    return nextOutlineRepository.findById(request.getOutlineId())
                            .switchIfEmpty(Mono.error(new RuntimeException("大纲不存在")))
                            .flatMap(outline -> {
                                // 设置为选中状态
                                outline.setSelected(true);

                                // 保存大纲
                                return nextOutlineRepository.save(outline)
                                        .flatMap(savedOutline -> {
                                            // 根据插入类型处理
                                            String insertType = request.getInsertType();
                                            if (insertType == null) {
                                                insertType = "NEW_CHAPTER";
                                            }

                                            switch (insertType) {
                                                case "NEW_CHAPTER":
                                                    // 创建新章节和场景
                                                    return createNewChapterAndScene(novelId, savedOutline, request);
                                                case "CHAPTER_END":
                                                    // 在现有章节末尾添加场景
                                                    return addSceneToChapterEnd(novelId, savedOutline, request);
                                                case "BEFORE_SCENE":
                                                    // 在指定场景之前添加场景
                                                    return addSceneBeforeTarget(novelId, savedOutline, request);
                                                case "AFTER_SCENE":
                                                    // 在指定场景之后添加场景
                                                    return addSceneAfterTarget(novelId, savedOutline, request);
                                                default:
                                                    // 默认创建新章节和场景
                                                    return createNewChapterAndScene(novelId, savedOutline, request);
                                            }
                                        });
                            });
                });
    }

    @Override
    public Flux<String> regenerateOutlineOption(String novelId, NextOutlineDTO.RegenerateOptionRequest request) {
        log.info("重新生成单个剧情大纲: novelId={}, optionId={}, configId={}",
                novelId, request.getOptionId(), request.getSelectedConfigId());

        // 获取当前用户ID
        return getCurrentUserId()
                .flatMapMany(userId -> {
                    // 查询原始大纲，获取上下文信息
                    return nextOutlineRepository.findById(request.getOptionId())
                            .switchIfEmpty(Mono.error(new RuntimeException("未找到指定的大纲选项")))
                            .flatMap(outline -> {
                                // 获取用户的AI模型配置
                                return userAIModelConfigService.getConfigurationById(userId, request.getSelectedConfigId())
                                        .switchIfEmpty(Mono.error(new RuntimeException("未找到指定的模型配置")))
                                        .flatMap(userConfig -> {
                                            // 先保存上下文，以便后续使用
                                            final NextOutline outlineToUpdate = outline;
                                            
                                            // 使用新的模型配置和提示重新生成
                                            return novelAIService.generateNextOutlinesStream(
                                                    novelId,
                                                    outline.getId(), // 使用原大纲ID作为上下文
                                                    1, // 只重新生成一个选项
                                                    request.getRegenerateHint() // 添加新的提示
                                            )
                                            // 收集所有生成的内容片段
                                            .collectList()
                                            .flatMap(contentList -> {
                                                // 拼接内容
                                                StringBuilder contentBuilder = new StringBuilder();
                                                for (Object chunk : contentList) {
                                                    contentBuilder.append(chunk.toString());
                                                }
                                                String fullContent = contentBuilder.toString();
                                                
                                                // 更新大纲
                                                outlineToUpdate.setContent(fullContent);
                                                outlineToUpdate.setTitle(extractTitle(fullContent)); // 从内容中提取标题
                                                outlineToUpdate.setConfigId(request.getSelectedConfigId()); // 更新使用的模型配置ID
                                                
                                                // 保存到数据库
                                                return nextOutlineRepository.save(outlineToUpdate)
                                                        .thenReturn(contentList);
                                            });
                                        });
                            })
                            // 将保存后的结果转换为流
                            .flatMapMany(contentList -> {
                                // 转换每个内容片段为字符串流
                                return Flux.fromIterable(contentList)
                                        .map(Object::toString);
                            });
                });
    }

    /**
     * 解析AI响应，生成大纲列表
     *
     * @param aiResponse AI响应
     * @param novelId 小说ID
     * @param userId 用户ID
     * @return 大纲列表
     */
    private Mono<List<NextOutline>> parseAIResponseToOutlines(AIResponse aiResponse, String novelId, String userId) {
        try {
            // 尝试解析为JSON格式的大纲列表
            List<NextOutline> outlines = parseJsonResponse(aiResponse.getContent(), novelId);
            if (!outlines.isEmpty()) {
                return Mono.just(outlines);
            }
        } catch (Exception e) {
            log.warn("解析JSON格式大纲失败，尝试解析文本格式: {}", e.getMessage());
        }

        // 如果JSON解析失败，尝试解析文本格式
        List<NextOutline> outlines = parseTextResponse(aiResponse.getContent(), novelId);
        return Mono.just(outlines);
    }

    /**
     * 解析JSON格式的AI响应
     *
     * @param content AI响应内容
     * @param novelId 小说ID
     * @return 大纲列表
     */
    private List<NextOutline> parseJsonResponse(String content, String novelId) throws JsonProcessingException {
        // 尝试解析为JSON数组
        try {
            // 这里根据实际的JSON格式进行解析
            // 假设返回的是一个大纲数组
            List<NextOutline> outlines = new ArrayList<>();

            // TODO: 实现JSON解析逻辑

            return outlines;
        } catch (Exception e) {
            log.warn("解析JSON格式大纲失败: {}", e.getMessage());
            throw e;
        }
    }

    /**
     * 解析文本格式的AI响应
     *
     * @param content AI响应内容
     * @param novelId 小说ID
     * @return 大纲列表
     */
    private List<NextOutline> parseTextResponse(String content, String novelId) {
        List<NextOutline> outlines = new ArrayList<>();

        // 简单的文本解析逻辑，根据实际AI输出格式调整
        // 假设每个大纲以"选项X："开头
        String[] sections = content.split("(?=选项\\s*\\d+\\s*[:：])|(?=大纲\\s*\\d+\\s*[:：])|(?=剧情选项\\s*\\d+\\s*[:：])");

        for (int i = 0; i < sections.length; i++) {
            String section = sections[i].trim();
            if (section.isEmpty()) continue;

            // 提取标题和内容
            String title = "剧情选项 " + (i + 1);
            String outlineContent = section;

            // 尝试提取标题
            int titleEnd = section.indexOf("\n");
            if (titleEnd > 0) {
                title = section.substring(0, titleEnd).trim();
                outlineContent = section.substring(titleEnd).trim();
            }

            // 创建大纲对象
            NextOutline outline = NextOutline.builder()
                    .id(UUID.randomUUID().toString())
                    .novelId(novelId)
                    .title(title)
                    .content(outlineContent)
                    .createdAt(LocalDateTime.now())
                    .selected(false)
                    .build();

            outlines.add(outline);
        }

        // 如果没有解析出大纲，创建一个默认大纲
        if (outlines.isEmpty()) {
            NextOutline outline = NextOutline.builder()
                    .id(UUID.randomUUID().toString())
                    .novelId(novelId)
                    .title("剧情选项")
                    .content(content)
                    .createdAt(LocalDateTime.now())
                    .selected(false)
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
        // 保存大纲到数据库
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
                .configId(outline.getConfigId()) // 包含模型配置ID
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
        // 获取小说信息
        return novelService.findNovelById(novelId)
                .flatMap(novel -> {
                    // 获取第一个卷的ID，如果没有卷则创建一个
                    String actId;
                    if (novel.getStructure() == null || novel.getStructure().getActs() == null || novel.getStructure().getActs().isEmpty()) {
                        // 创建新卷
                        return novelService.addAct(novelId, "第一卷", null)
                                .flatMap(updatedNovel -> {
                                    String newActId = updatedNovel.getStructure().getActs().get(0).getId();
                                    // 创建新章节
                                    return novelService.addChapter(novelId, newActId, outline.getTitle(), null);
                                })
                                .flatMap(updatedNovel -> {
                                    // 获取新创建的章节ID
                                    String newChapterId = updatedNovel.getStructure().getActs().get(0).getChapters().get(0).getId();

                                    // 创建新场景
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
                        // 使用现有的第一个卷
                        actId = novel.getStructure().getActs().get(0).getId();

                        // 创建新章节
                        return novelService.addChapter(novelId, actId, outline.getTitle(), null)
                                .flatMap(updatedNovel -> {
                                    // 获取新创建的章节ID
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

                                    // 创建新场景
                                    if (request.isCreateNewScene()) {
                                        final String chapterId = newChapterId;
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

        // 创建新场景
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

        // 获取目标场景所属章节
        return sceneService.findSceneById(request.getTargetSceneId())
                .flatMap(targetScene -> {
                    // 创建新场景
                    // 获取目标场景的序号
                    int targetPosition = targetScene.getSequence();
                    // 在目标场景之前创建新场景
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

        // 获取目标场景所属章节
        return sceneService.findSceneById(request.getTargetSceneId())
                .flatMap(targetScene -> {
                    // 创建新场景
                    // 获取目标场景的序号
                    int targetPosition = targetScene.getSequence() + 1; // 在目标场景之后
                    // 在目标场景之后创建新场景
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

    /**
     * 从内容中提取标题
     * 
     * @param content 内容
     * @return 提取的标题
     */
    private String extractTitle(String content) {
        // 简单实现：取第一行或前50个字符作为标题
        if (content == null || content.isEmpty()) {
            return "剧情选项";
        }
        
        // 尝试获取第一行
        int firstLineEnd = content.indexOf('\n');
        if (firstLineEnd > 0 && firstLineEnd < 100) {
            return content.substring(0, firstLineEnd).trim();
        }
        
        // 如果没有换行或第一行太长，取前50个字符
        int titleLength = Math.min(content.length(), 50);
        return content.substring(0, titleLength).trim() + (content.length() > 50 ? "..." : "");
    }
}
