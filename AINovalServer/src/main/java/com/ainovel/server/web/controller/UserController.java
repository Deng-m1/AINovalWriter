package com.ainovel.server.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.domain.model.User.AIModelConfig;
import com.ainovel.server.service.UserService;
import com.ainovel.server.web.dto.AIModelConfigDto;
import com.ainovel.server.web.dto.IdDto;
import com.ainovel.server.web.dto.UserIdConfigIndexDto;
import com.ainovel.server.web.dto.UserIdDto;
import com.ainovel.server.web.dto.UserRegistrationRequest;
import com.ainovel.server.web.dto.UserUpdateDto;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户控制器
 */
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    @Autowired
    public UserController(UserService userService) {
        this.userService = userService;
    }

    /**
     * 注册用户
     * 
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
     * 
     * @param idDto 包含用户ID的DTO
     * @return 用户信息
     */
    @PostMapping("/get")
    public Mono<User> getUserById(@RequestBody IdDto idDto) {
        return userService.findUserById(idDto.getId());
    }

    /**
     * 更新用户信息
     * 
     * @param userUpdateDto 包含用户ID和更新信息的DTO
     * @return 更新后的用户
     */
    @PostMapping("/update")
    public Mono<User> updateUser(@RequestBody UserUpdateDto userUpdateDto) {
        return userService.updateUser(userUpdateDto.getId(), userUpdateDto.getUser());
    }

    /**
     * 删除用户
     * 
     * @param idDto 包含用户ID的DTO
     * @return 操作结果
     */
    @PostMapping("/delete")
    public Mono<Void> deleteUser(@RequestBody IdDto idDto) {
        return userService.deleteUser(idDto.getId());
    }

    /**
     * 获取用户的AI模型配置列表
     * 
     * @param userIdDto 包含用户ID的DTO
     * @return AI模型配置列表
     */
    @PostMapping("/get-ai-models")
    public Flux<AIModelConfig> getUserAIModels(@RequestBody UserIdDto userIdDto) {
        return userService.getUserAIModelConfigs(userIdDto.getUserId());
    }

    /**
     * 获取用户的默认AI模型配置
     * 
     * @param userIdDto 包含用户ID的DTO
     * @return 默认AI模型配置
     */
    @PostMapping("/get-default-ai-model")
    public Mono<AIModelConfig> getUserDefaultAIModel(@RequestBody UserIdDto userIdDto) {
        return userService.getUserDefaultAIModelConfig(userIdDto.getUserId());
    }

    /**
     * 添加AI模型配置
     * 
     * @param aiModelConfigDto 包含用户ID和AI模型配置的DTO
     * @return 更新后的用户
     */
    @PostMapping("/add-ai-model")
    public Mono<User> addAIModelConfig(@RequestBody AIModelConfigDto aiModelConfigDto) {
        return userService.addAIModelConfig(aiModelConfigDto.getUserId(), aiModelConfigDto.getConfig());
    }

    /**
     * 更新AI模型配置
     * 
     * @param userIdConfigIndexDto 包含用户ID、配置索引和更新的AI模型配置的DTO
     * @return 更新后的用户
     */
    @PostMapping("/update-ai-model")
    public Mono<User> updateAIModelConfig(@RequestBody UserIdConfigIndexDto userIdConfigIndexDto) {
        return userService.updateAIModelConfig(
                userIdConfigIndexDto.getUserId(),
                userIdConfigIndexDto.getConfigIndex(),
                userIdConfigIndexDto.getConfig());
    }

    /**
     * 删除AI模型配置
     * 
     * @param userIdConfigIndexDto 包含用户ID和配置索引的DTO
     * @return 更新后的用户
     */
    @PostMapping("/delete-ai-model")
    public Mono<User> deleteAIModelConfig(@RequestBody UserIdConfigIndexDto userIdConfigIndexDto) {
        return userService.deleteAIModelConfig(
                userIdConfigIndexDto.getUserId(),
                userIdConfigIndexDto.getConfigIndex());
    }

    /**
     * 设置默认AI模型配置
     * 
     * @param userIdConfigIndexDto 包含用户ID和配置索引的DTO
     * @return 更新后的用户
     */
    @PostMapping("/set-default-ai-model")
    public Mono<User> setDefaultAIModelConfig(@RequestBody UserIdConfigIndexDto userIdConfigIndexDto) {
        return userService.setDefaultAIModelConfig(
                userIdConfigIndexDto.getUserId(),
                userIdConfigIndexDto.getConfigIndex());
    }
}