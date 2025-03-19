package com.ainovel.server.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import static org.mockito.ArgumentMatchers.any;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import static org.mockito.Mockito.when;
import org.mockito.junit.jupiter.MockitoExtension;

import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Scene.HistoryEntry;
import com.ainovel.server.domain.model.SceneVersionDiff;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.impl.SceneServiceImpl;

import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

/**
 * 场景版本控制功能的单元测试
 */
@ExtendWith(MockitoExtension.class)
public class SceneServiceVersionTest {

    @Mock
    private SceneRepository sceneRepository;

    @InjectMocks
    private SceneServiceImpl sceneService;

    private Scene scene;

    @BeforeEach
    void setUp() {
        // 创建测试用的场景对象
        scene = new Scene();
        scene.setId("scene-1");
        scene.setNovelId("novel-1");
        scene.setChapterId("chapter-1");
        scene.setTitle("测试场景");
        scene.setContent("这是原始内容。\n第二行内容。\n第三行内容。");
        scene.setVersion(1);
        scene.setCreatedAt(Instant.now());
        scene.setUpdatedAt(Instant.now());
        scene.setHistory(new ArrayList<>());
    }

    @Test
    void updateSceneContent_ShouldCreateHistoryEntry() {
        // 准备
        String newContent = "这是更新后的内容。\n第二行内容。\n修改后的第三行。";
        String userId = "user-1";
        String reason = "修改场景内容";

        when(sceneRepository.findById("scene-1")).thenReturn(Mono.just(scene));
        when(sceneRepository.save(any(Scene.class))).thenAnswer(invocation -> Mono.just(invocation.getArgument(0)));

        // 执行
        Mono<Scene> result = sceneService.updateSceneContent("scene-1", newContent, userId, reason);

        // 验证
        StepVerifier.create(result)
            .assertNext(updatedScene -> {
                assertEquals(2, updatedScene.getVersion());
                assertEquals(newContent, updatedScene.getContent());
                assertEquals(1, updatedScene.getHistory().size());
                
                HistoryEntry historyEntry = updatedScene.getHistory().get(0);
                assertEquals("这是原始内容。\n第二行内容。\n第三行内容。", historyEntry.getContent());
                assertEquals(userId, historyEntry.getUpdatedBy());
                assertEquals(reason, historyEntry.getReason());
                assertNotNull(historyEntry.getUpdatedAt());
            })
            .verifyComplete();
    }

    @Test
    void updateSceneContent_WithNoChange_ShouldNotCreateHistoryEntry() {
        // 准备
        String sameContent = "这是原始内容。\n第二行内容。\n第三行内容。";
        String userId = "user-1";
        String reason = "尝试修改场景内容";

        when(sceneRepository.findById("scene-1")).thenReturn(Mono.just(scene));

        // 执行
        Mono<Scene> result = sceneService.updateSceneContent("scene-1", sameContent, userId, reason);

        // 验证
        StepVerifier.create(result)
            .assertNext(updatedScene -> {
                assertEquals(1, updatedScene.getVersion());
                assertEquals(sameContent, updatedScene.getContent());
                assertEquals(0, updatedScene.getHistory().size());
            })
            .verifyComplete();
    }

    @Test
    void restoreSceneVersion_ShouldRestoreToHistoryContent() {
        // 准备
        // 添加历史版本
        HistoryEntry historyEntry = new HistoryEntry();
        historyEntry.setContent("这是历史版本内容。\n历史版本第二行。\n历史版本第三行。");
        historyEntry.setUpdatedBy("user-1");
        historyEntry.setReason("初始修改");
        
        scene.getHistory().add(historyEntry);
        scene.setContent("这是当前内容。\n当前第二行。\n当前第三行。");
        scene.setVersion(2);

        String userId = "user-2";
        String reason = "恢复到历史版本";

        when(sceneRepository.findById("scene-1")).thenReturn(Mono.just(scene));
        when(sceneRepository.save(any(Scene.class))).thenAnswer(invocation -> Mono.just(invocation.getArgument(0)));

        // 执行
        Mono<Scene> result = sceneService.restoreSceneVersion("scene-1", 0, userId, reason);

        // 验证
        StepVerifier.create(result)
            .assertNext(restoredScene -> {
                assertEquals(3, restoredScene.getVersion());
                assertEquals("这是历史版本内容。\n历史版本第二行。\n历史版本第三行。", restoredScene.getContent());
                assertEquals(3, restoredScene.getHistory().size());
                
                // 第一个历史条目是原始历史版本
                assertEquals("这是历史版本内容。\n历史版本第二行。\n历史版本第三行。", restoredScene.getHistory().get(0).getContent());
                
                // 第二个历史条目是恢复前的版本备份
                assertEquals("这是当前内容。\n当前第二行。\n当前第三行。", restoredScene.getHistory().get(1).getContent());
                assertEquals(userId, restoredScene.getHistory().get(1).getUpdatedBy());
                assertTrue(restoredScene.getHistory().get(1).getReason().contains("恢复版本前的备份"));
                
                // 第三个历史条目是恢复操作记录
                assertEquals(null, restoredScene.getHistory().get(2).getContent());
                assertEquals(userId, restoredScene.getHistory().get(2).getUpdatedBy());
                assertTrue(restoredScene.getHistory().get(2).getReason().contains("恢复到历史版本"));
            })
            .verifyComplete();
    }

    @Test
    void compareSceneVersions_ShouldReturnDiff() {
        // 准备
        // 添加历史版本
        HistoryEntry historyEntry = new HistoryEntry();
        historyEntry.setContent("这是历史版本内容。\n历史版本第二行。\n历史版本第三行。");
        historyEntry.setUpdatedBy("user-1");
        historyEntry.setReason("初始修改");
        
        scene.getHistory().add(historyEntry);
        scene.setContent("这是当前内容。\n当前第二行。\n当前第三行。");
        scene.setVersion(2);

        when(sceneRepository.findById("scene-1")).thenReturn(Mono.just(scene));

        // 执行
        Mono<SceneVersionDiff> result = sceneService.compareSceneVersions("scene-1", 0, -1);

        // 验证
        StepVerifier.create(result)
            .assertNext(diff -> {
                assertEquals("这是历史版本内容。\n历史版本第二行。\n历史版本第三行。", diff.getOriginalContent());
                assertEquals("这是当前内容。\n当前第二行。\n当前第三行。", diff.getNewContent());
                assertNotNull(diff.getDiff());
                assertTrue(diff.getDiff().contains("@@ "));  // 验证差异包含统一差异格式的标记
            })
            .verifyComplete();
    }

    @Test
    void getSceneHistory_ShouldReturnHistoryList() {
        // 准备
        // 添加多个历史版本
        HistoryEntry entry1 = new HistoryEntry();
        entry1.setContent("版本1内容");
        entry1.setUpdatedBy("user-1");
        entry1.setReason("第一次修改");
        
        HistoryEntry entry2 = new HistoryEntry();
        entry2.setContent("版本2内容");
        entry2.setUpdatedBy("user-2");
        entry2.setReason("第二次修改");
        
        List<HistoryEntry> history = new ArrayList<>();
        history.add(entry1);
        history.add(entry2);
        
        scene.setHistory(history);

        when(sceneRepository.findById("scene-1")).thenReturn(Mono.just(scene));

        // 执行
        Mono<List<HistoryEntry>> result = sceneService.getSceneHistory("scene-1");

        // 验证
        StepVerifier.create(result)
            .assertNext(historyList -> {
                assertEquals(2, historyList.size());
                assertEquals("版本1内容", historyList.get(0).getContent());
                assertEquals("user-1", historyList.get(0).getUpdatedBy());
                assertEquals("第一次修改", historyList.get(0).getReason());
                
                assertEquals("版本2内容", historyList.get(1).getContent());
                assertEquals("user-2", historyList.get(1).getUpdatedBy());
                assertEquals("第二次修改", historyList.get(1).getReason());
            })
            .verifyComplete();
    }
} 