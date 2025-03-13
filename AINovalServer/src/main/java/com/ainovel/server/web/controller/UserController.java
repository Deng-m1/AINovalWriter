package com.ainovel.server.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.domain.model.User.AIModelConfig;
import com.ainovel.server.service.UserService;
import com.ainovel.server.web.dto.UserRegistrationRequest;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户控制器
 */
@RestController
@RequestMapping("/users")
public class UserController {
    
    private final UserService userService;
    
    @Autowired
    public UserController(UserService userService) {
        this.userService = userService;
    }
    
    /**
     * 注册用户
     * @param request 注册请求
     * @return 创建的用户
     */
    @PostMapping("/register")
    public Mono<User> registerUser(@RequestBody UserRegistrationRequest request) {
        User user = User.builder()
                .username(request.getUsername())
                .password(request.getPassword())
                .email(request.getEmail())
                .displayName(request.getDisplayName())
                .build();
        
        return userService.createUser(user);
    }
    
    /**
     * 获取用户信息
     * @param id 用户ID
     * @return 用户信息
     */
    @GetMapping("/{id}")
    public Mono<User> getUserById(@PathVariable String id) {
        return userService.findUserById(id);
    }
    
    /**
     * 更新用户信息
     * @param id 用户ID
     * @param user 更新的用户信息
     * @return 更新后的用户
     */
    @PutMapping("/{id}")
    public Mono<User> updateUser(@PathVariable String id, @RequestBody User user) {
        return userService.updateUser(id, user);
    }
    
    /**
     * 删除用户
     * @param id 用户ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public Mono<Void> deleteUser(@PathVariable String id) {
        return userService.deleteUser(id);
    }
    
    /**
     * 获取用户的AI模型配置列表
     * @param userId 用户ID
     * @return AI模型配置列表
     */
    @GetMapping("/{userId}/ai-models")
    public Flux<AIModelConfig> getUserAIModels(@PathVariable String userId) {
        return userService.getUserAIModelConfigs(userId);
    }
    
    /**
     * 获取用户的默认AI模型配置
     * @param userId 用户ID
     * @return 默认AI模型配置
     */
    @GetMapping("/{userId}/ai-models/default")
    public Mono<AIModelConfig> getUserDefaultAIModel(@PathVariable String userId) {
        return userService.getUserDefaultAIModelConfig(userId);
    }
    
    /**
     * 添加AI模型配置
     * @param userId 用户ID
     * @param config AI模型配置
     * @return 更新后的用户
     */
    @PostMapping("/{userId}/ai-models")
    public Mono<User> addAIModelConfig(@PathVariable String userId, @RequestBody AIModelConfig config) {
        return userService.addAIModelConfig(userId, config);
    }
    
    /**
     * 更新AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @param config 更新的AI模型配置
     * @return 更新后的用户
     */
    @PutMapping("/{userId}/ai-models/{configIndex}")
    public Mono<User> updateAIModelConfig(
            @PathVariable String userId,
            @PathVariable int configIndex,
            @RequestBody AIModelConfig config) {
        return userService.updateAIModelConfig(userId, configIndex, config);
    }
    
    /**
     * 删除AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @return 更新后的用户
     */
    @DeleteMapping("/{userId}/ai-models/{configIndex}")
    public Mono<User> deleteAIModelConfig(@PathVariable String userId, @PathVariable int configIndex) {
        return userService.deleteAIModelConfig(userId, configIndex);
    }
    
    /**
     * 设置默认AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @return 更新后的用户
     */
    @PostMapping("/{userId}/ai-models/{configIndex}/set-default")
    public Mono<User> setDefaultAIModelConfig(@PathVariable String userId, @PathVariable int configIndex) {
        return userService.setDefaultAIModelConfig(userId, configIndex);
    }
}