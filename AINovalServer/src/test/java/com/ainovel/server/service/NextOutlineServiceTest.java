package com.ainovel.server.service;

import com.ainovel.server.domain.model.AIResponse;
import com.ainovel.server.domain.model.NextOutline;
import com.ainovel.server.repository.NextOutlineRepository;
import com.ainovel.server.service.impl.NextOutlineServiceImpl;
import com.ainovel.server.web.dto.NextOutlineDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

/**
 * 剧情推演服务测试
 */
public class NextOutlineServiceTest {

    @Mock
    private NovelAIService novelAIService;

    @Mock
    private NextOutlineRepository nextOutlineRepository;

    @Mock
    private NovelService novelService;

    @Mock
    private SceneService sceneService;

    private NextOutlineService nextOutlineService;

    @BeforeEach
    public void setUp() {
        MockitoAnnotations.openMocks(this);
        nextOutlineService = new NextOutlineServiceImpl(
                novelAIService,
                nextOutlineRepository,
                new com.fasterxml.jackson.databind.ObjectMapper()
        );

        // 注入依赖
        ((NextOutlineServiceImpl) nextOutlineService).setNovelService(novelService);
        ((NextOutlineServiceImpl) nextOutlineService).setSceneService(sceneService);
    }

    @Test
    public void testGenerateNextOutlines() {
        // 准备测试数据
        String novelId = UUID.randomUUID().toString();
        String userId = UUID.randomUUID().toString();
        NextOutlineDTO.GenerateRequest request = new NextOutlineDTO.GenerateRequest();
        request.setTargetChapter("Chapter 5");
        request.setNumOptions(3);
        request.setAuthorGuidance("More conflicts");

        // 模拟AI响应
        AIResponse aiResponse = new AIResponse();
        aiResponse.setContent("Sample outline content for testing");

        // 模拟大纲
        NextOutline outline = new NextOutline();
        outline.setId(UUID.randomUUID().toString());
        outline.setNovelId(novelId);
        outline.setTitle("Sample Outline");
        outline.setContent("Sample content");
        outline.setCreatedAt(LocalDateTime.now());
        outline.setSelected(false);

        // 设置Mock行为
        when(novelAIService.generateNextOutlines(anyString(), anyString(), any(), anyString()))
                .thenReturn(Mono.just(aiResponse));
        when(nextOutlineRepository.save(any(NextOutline.class))).thenReturn(Mono.just(outline));

        // 模拟安全上下文
        TestingAuthenticationToken auth = new TestingAuthenticationToken(userId, "credentials", "ROLE_USER");
        ReactiveSecurityContextHolder.withAuthentication(auth);

        // 执行测试
        Mono<NextOutlineDTO.GenerateResponse> result = nextOutlineService.generateNextOutlines(novelId, request);

        // 验证结果
        StepVerifier.create(result)
                .expectNextMatches(response -> {
                    List<NextOutlineDTO.OutlineItem> outlines = response.getOutlines();
                    return outlines != null && !outlines.isEmpty();
                })
                .verifyComplete();
    }

    @Test
    public void testSaveNextOutline() {
        // 准备测试数据
        String novelId = UUID.randomUUID().toString();
        String outlineId = UUID.randomUUID().toString();
        String userId = UUID.randomUUID().toString();
        NextOutlineDTO.SaveRequest request = new NextOutlineDTO.SaveRequest();
        request.setOutlineId(outlineId);

        // 模拟大纲
        NextOutline outline = new NextOutline();
        outline.setId(outlineId);
        outline.setNovelId(novelId);
        outline.setTitle("Sample Outline");
        outline.setContent("Sample content");
        outline.setCreatedAt(LocalDateTime.now());
        outline.setSelected(false);

        // 设置Mock行为
        when(nextOutlineRepository.findById(outlineId)).thenReturn(Mono.just(outline));
        when(nextOutlineRepository.save(any(NextOutline.class))).thenReturn(Mono.just(outline));

        // 模拟安全上下文
        TestingAuthenticationToken auth = new TestingAuthenticationToken(userId, "credentials", "ROLE_USER");
        ReactiveSecurityContextHolder.withAuthentication(auth);

        // 执行测试
        Mono<NextOutlineDTO.SaveResponse> result = nextOutlineService.saveNextOutline(novelId, request);

        // 验证结果
        StepVerifier.create(result)
                .expectNextMatches(response -> 
                    response.isSuccess() && outlineId.equals(response.getOutlineId())
                )
                .verifyComplete();
    }
}
