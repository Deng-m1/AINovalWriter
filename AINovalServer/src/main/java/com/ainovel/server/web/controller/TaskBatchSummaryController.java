package com.ainovel.server.web.controller;

import com.ainovel.server.security.CurrentUser;
import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryParameters;
import com.ainovel.server.task.service.TaskSubmissionService;
import com.ainovel.server.web.dto.TaskSubmissionResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

/**
 * 批量生成摘要任务控制器
 */
@Slf4j
@RestController
@RequestMapping("/api/tasks")
@RequiredArgsConstructor
public class TaskBatchSummaryController {

    private final TaskSubmissionService taskSubmissionService;

    /**
     * 提交批量生成摘要任务
     * 
     * @param currentUser 当前用户
     * @param request 请求参数
     * @return 任务提交响应
     */
    @PostMapping("/batch-generate-summary")
    public ResponseEntity<TaskSubmissionResponse> submitBatchGenerateSummaryTask(
            @AuthenticationPrincipal CurrentUser currentUser,
            @Valid @RequestBody BatchGenerateSummaryParameters request) {
        
        log.info("用户 {} 提交批量生成摘要任务, 小说: {}, 章节范围: {} 到 {}, AI配置: {}, 覆盖已有: {}",
                currentUser.getId(), request.getNovelId(), request.getStartChapterId(),
                request.getEndChapterId(), request.getAiConfigId(), request.isOverwriteExisting());
        
        // 提交任务
        String taskId = taskSubmissionService.submitTask(
                currentUser.getId(),
                "BATCH_GENERATE_SUMMARY",
                request);
        
        // 返回响应
        TaskSubmissionResponse response = new TaskSubmissionResponse(taskId);
        return ResponseEntity.ok(response);
    }
} 