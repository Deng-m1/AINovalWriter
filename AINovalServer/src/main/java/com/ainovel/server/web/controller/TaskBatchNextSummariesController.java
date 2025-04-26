package com.ainovel.server.web.controller;

import com.ainovel.server.security.CurrentUser;
import com.ainovel.server.task.dto.nextsummaries.GenerateNextSummariesOnlyParameters;
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
 * 自动续写小说章节摘要任务控制器
 */
@Slf4j
@RestController
@RequestMapping("/api/tasks")
@RequiredArgsConstructor
public class TaskBatchNextSummariesController {

    private final TaskSubmissionService taskSubmissionService;

    /**
     * 提交自动续写小说章节摘要任务
     * 
     * @param currentUser 当前用户
     * @param request 请求参数
     * @return 任务提交响应
     */
    @PostMapping("/generate-next-summaries")
    public ResponseEntity<TaskSubmissionResponse> submitGenerateNextSummariesTask(
            @AuthenticationPrincipal CurrentUser currentUser,
            @Valid @RequestBody GenerateNextSummariesOnlyParameters request) {
        
        log.info("用户 {} 提交自动续写小说章节摘要任务, 小说: {}, 章节数量: {}, AI配置: {}, 上下文模式: {}",
                currentUser.getId(), request.getNovelId(), request.getNumberOfChapters(),
                request.getAiConfigIdSummary(), request.getStartContextMode());
        
        // 提交任务
        String taskId = taskSubmissionService.submitTask(
                currentUser.getId(),
                "GENERATE_NEXT_SUMMARIES_ONLY",
                request);
        
        // 返回响应
        TaskSubmissionResponse response = new TaskSubmissionResponse(taskId);
        return ResponseEntity.ok(response);
    }
} 