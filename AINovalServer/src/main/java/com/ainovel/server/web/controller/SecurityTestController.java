package com.ainovel.server.web.controller;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import reactor.core.publisher.Mono;

/**
 * 安全测试控制器
 * 仅在测试环境下可用，用于验证安全配置和请求是否能够到达控制器层
 */
@RestController
@RequestMapping("/api/v1/security-test")
@Profile({ "test", "performance-test" })
public class SecurityTestController {
    
    private static final Logger logger = LoggerFactory.getLogger(SecurityTestController.class);
    
    /**
     * 公开测试端点，无需认证
     * @return 服务器状态信息
     */
    @GetMapping("/public")
    public Mono<ResponseEntity<Map<String, Object>>> publicEndpoint() {
        logger.info("收到公开测试请求: /api/v1/security-test/public");
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "公开API端点测试成功");
        response.put("timestamp", LocalDateTime.now().toString());
        response.put("endpoint", "public");
        
        return Mono.just(ResponseEntity.ok(response));
    }
    
    /**
     * 受保护测试端点，正常情况下需要认证
     * 但在测试环境中，所有请求都被允许通过
     * @return 认证状态信息
     */
    @GetMapping("/protected")
    public Mono<ResponseEntity<Map<String, Object>>> protectedEndpoint() {
        logger.info("收到受保护测试请求: /api/v1/security-test/protected");
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "受保护API端点测试成功，请求已到达控制器");
        response.put("timestamp", LocalDateTime.now().toString());
        response.put("endpoint", "protected");
        
        return Mono.just(ResponseEntity.ok(response));
    }
} 