package com.ainovel.server.web.controller;

import com.ainovel.server.task.service.DeadLetterService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 死信处理API控制器
 */
@RestController
@RequestMapping("/api/tasks/deadletter")
public class DeadLetterController {
    
    private static final Logger logger = LoggerFactory.getLogger(DeadLetterController.class);
    
    private final DeadLetterService deadLetterService;
    
    @Autowired
    public DeadLetterController(DeadLetterService deadLetterService) {
        this.deadLetterService = deadLetterService;
    }
    
    /**
     * 获取死信队列信息
     */
    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> getQueueInfo() {
        Map<String, Object> info = deadLetterService.getDeadLetterQueueInfo();
        return ResponseEntity.ok(info);
    }
    
    /**
     * 列出死信队列中的消息
     */
    @GetMapping("/list")
    public ResponseEntity<List<Map<String, Object>>> listDeadLetters(
            @RequestParam(defaultValue = "20") int limit) {
        List<Map<String, Object>> messages = deadLetterService.listDeadLetters(limit);
        return ResponseEntity.ok(messages);
    }
    
    /**
     * 重试特定的死信消息
     */
    @PostMapping("/retry/{taskId}")
    public ResponseEntity<Map<String, Object>> retryDeadLetter(@PathVariable String taskId) {
        boolean success = deadLetterService.retryDeadLetter(taskId);
        
        Map<String, Object> response = new HashMap<>();
        response.put("success", success);
        response.put("taskId", taskId);
        
        if (success) {
            logger.info("成功重试死信任务: {}", taskId);
            return ResponseEntity.ok(response);
        } else {
            logger.warn("重试死信任务失败: {}", taskId);
            response.put("message", "重试失败，任务可能不存在或不在死信队列中");
            return ResponseEntity.badRequest().body(response);
        }
    }
    
    /**
     * 清空死信队列
     */
    @DeleteMapping("/purge")
    public ResponseEntity<Map<String, Object>> purgeDeadLetterQueue() {
        boolean success = deadLetterService.purgeDeadLetterQueue();
        
        Map<String, Object> response = new HashMap<>();
        response.put("success", success);
        
        if (success) {
            logger.info("成功清空死信队列");
            return ResponseEntity.ok(response);
        } else {
            logger.warn("清空死信队列失败");
            response.put("message", "清空死信队列失败");
            return ResponseEntity.internalServerError().body(response);
        }
    }
}
