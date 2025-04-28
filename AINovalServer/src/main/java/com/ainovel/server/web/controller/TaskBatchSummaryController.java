package com.ainovel.server.web.controller;

import com.ainovel.server.security.CurrentUser;
import com.ainovel.server.task.dto.batchsummary.BatchGenerateSummaryParameters;
import com.ainovel.server.task.service.TaskSubmissionService;
import com.ainovel.server.web.dto.TaskSubmissionResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import reactor.core.publisher.Mono;
import java.util.HashMap;
import java.util.Map;

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
     * @return 任务提交响应的Mono
     */
    @PostMapping("/batch-generate-summary")
    public Mono<ResponseEntity<TaskSubmissionResponse>> submitBatchGenerateSummaryTask(
            @AuthenticationPrincipal CurrentUser currentUser,
            @Valid @RequestBody BatchGenerateSummaryParameters request) {
        
        String userId = currentUser.getId();
        String novelId = request.getNovelId();
        String startChapterId = request.getStartChapterId();
        String endChapterId = request.getEndChapterId();
        String aiConfigId = request.getAiConfigId();
        boolean overwriteExisting = request.isOverwriteExisting();
        
        log.info("用户 {} 提交批量生成摘要任务, 小说: {}, 章节范围: {} 到 {}, AI配置: {}, 覆盖已有: {}",
                userId, novelId, startChapterId, endChapterId, aiConfigId, overwriteExisting);
        
        if (novelId == null || startChapterId == null || endChapterId == null || aiConfigId == null) {
            log.error("提交批量摘要任务失败: 必填参数缺失");
            Map<String, String> errors = new HashMap<>();
            if (novelId == null) errors.put("novelId", "小说ID不能为空");
            if (startChapterId == null) errors.put("startChapterId", "起始章节ID不能为空");
            if (endChapterId == null) errors.put("endChapterId", "结束章节ID不能为空");
            if (aiConfigId == null) errors.put("aiConfigId", "AI配置ID不能为空");
            
            TaskSubmissionResponse errorResponse = new TaskSubmissionResponse(null);
            errorResponse.setErrors(errors);
            return Mono.just(ResponseEntity.badRequest().body(errorResponse));
        }
        
        // 提交任务并转换响应
        return taskSubmissionService.submitTask(
                userId,
                "BATCH_GENERATE_SUMMARY",
                request, // 父任务ID为null
                null
            )
            .map(taskId -> {
                log.info("用户 {} 的批量生成摘要任务已提交, 任务ID: {}", userId, taskId);
                return ResponseEntity.accepted().body(new TaskSubmissionResponse(taskId));
            })
            .onErrorResume(e -> {
                log.error("提交批量生成摘要任务失败: {}", e.getMessage(), e);
                
                // 创建包含错误信息的响应
                TaskSubmissionResponse errorResponse = new TaskSubmissionResponse(null);
                Map<String, String> errors = new HashMap<>();
                errors.put("general", e.getMessage());
                errorResponse.setErrors(errors);
                
                HttpStatus status = HttpStatus.INTERNAL_SERVER_ERROR;
                if (e instanceof IllegalArgumentException) {
                    status = HttpStatus.BAD_REQUEST;
                }
                
                return Mono.just(ResponseEntity.status(status).body(errorResponse));
            });
    }
} 