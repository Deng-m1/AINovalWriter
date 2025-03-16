package com.ainovel.server.web.controller;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.repository.UserRepository;

import reactor.core.publisher.Mono;

/**
 * MongoDB测试控制器
 * 用于测试MongoDB查询日志和计数功能
 */
@RestController
@RequestMapping("/api/v1/mongo-test")
@Profile({ "test", "performance-test" })
public class MongoTestController {
    
    private static final Logger logger = LoggerFactory.getLogger(MongoTestController.class);
    
    private final UserRepository userRepository;
    
    @Autowired
    public MongoTestController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    /**
     * 测试根据用户名查找用户
     * @param username 用户名
     * @return 用户信息
     */
    @GetMapping("/users/username/{username}")
    public Mono<ResponseEntity<Map<String, Object>>> findUserByUsername(@PathVariable String username) {
        logger.info("测试根据用户名查找用户: {}", username);
        
        return userRepository.findByUsernameWithLogging(username)
                .map(user -> {
                    Map<String, Object> response = new HashMap<>();
                    response.put("found", true);
                    response.put("userId", user.getId());
                    response.put("username", user.getUsername());
                    response.put("displayName", user.getDisplayName());
                    return ResponseEntity.ok(response);
                })
                .defaultIfEmpty(ResponseEntity.ok(Map.of("found", false, "username", username)));
    }
    
    /**
     * 测试根据邮箱查找用户
     * @param email 邮箱
     * @return 用户信息
     */
    @GetMapping("/users/email/{email}")
    public Mono<ResponseEntity<Map<String, Object>>> findUserByEmail(@PathVariable String email) {
        logger.info("测试根据邮箱查找用户: {}", email);
        
        return userRepository.findByEmailWithLogging(email)
                .map(user -> {
                    Map<String, Object> response = new HashMap<>();
                    response.put("found", true);
                    response.put("userId", user.getId());
                    response.put("username", user.getUsername());
                    response.put("email", user.getEmail());
                    return ResponseEntity.ok(response);
                })
                .defaultIfEmpty(ResponseEntity.ok(Map.of("found", false, "email", email)));
    }
    
    /**
     * 测试检查用户名是否存在
     * @param username 用户名
     * @return 是否存在
     */
    @GetMapping("/users/exists/username/{username}")
    public Mono<ResponseEntity<Map<String, Object>>> existsByUsername(@PathVariable String username) {
        logger.info("测试检查用户名是否存在: {}", username);
        
        return userRepository.existsByUsernameWithLogging(username)
                .map(exists -> ResponseEntity.ok(Map.of("exists", exists, "username", username)));
    }
    
    /**
     * 测试检查邮箱是否存在
     * @param email 邮箱
     * @return 是否存在
     */
    @GetMapping("/users/exists/email/{email}")
    public Mono<ResponseEntity<Map<String, Object>>> existsByEmail(@PathVariable String email) {
        logger.info("测试检查邮箱是否存在: {}", email);
        
        return userRepository.existsByEmailWithLogging(email)
                .map(exists -> ResponseEntity.ok(Map.of("exists", exists, "email", email)));
    }
    
    /**
     * 创建测试用户
     * @param user 用户信息
     * @return 创建结果
     */
    @PostMapping("/users/create")
    public Mono<ResponseEntity<Map<String, Object>>> createUser(@RequestBody User user) {
        logger.info("创建测试用户: {}", user.getUsername());
        
        return userRepository.save(user)
                .map(savedUser -> {
                    Map<String, Object> response = new HashMap<>();
                    response.put("success", true);
                    response.put("userId", savedUser.getId());
                    response.put("username", savedUser.getUsername());
                    return ResponseEntity.ok(response);
                });
    }
} 