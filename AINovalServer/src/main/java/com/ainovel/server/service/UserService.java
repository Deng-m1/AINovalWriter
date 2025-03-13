package com.ainovel.server.service;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.domain.model.User.AIModelConfig;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户服务接口
 */
public interface UserService {
    
    /**
     * 创建用户
     * @param user 用户信息
     * @return 创建的用户
     */
    Mono<User> createUser(User user);
    
    /**
     * 根据ID查找用户
     * @param id 用户ID
     * @return 用户信息
     */
    Mono<User> findUserById(String id);
    
    /**
     * 根据用户名查找用户
     * @param username 用户名
     * @return 用户信息
     */
    Mono<User> findUserByUsername(String username);
    
    /**
     * 更新用户信息
     * @param id 用户ID
     * @param user 更新的用户信息
     * @return 更新后的用户
     */
    Mono<User> updateUser(String id, User user);
    
    /**
     * 删除用户
     * @param id 用户ID
     * @return 操作结果
     */
    Mono<Void> deleteUser(String id);
    
    /**
     * 添加AI模型配置
     * @param userId 用户ID
     * @param config AI模型配置
     * @return 更新后的用户
     */
    Mono<User> addAIModelConfig(String userId, AIModelConfig config);
    
    /**
     * 更新AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @param config 更新的AI模型配置
     * @return 更新后的用户
     */
    Mono<User> updateAIModelConfig(String userId, int configIndex, AIModelConfig config);
    
    /**
     * 删除AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @return 更新后的用户
     */
    Mono<User> deleteAIModelConfig(String userId, int configIndex);
    
    /**
     * 设置默认AI模型配置
     * @param userId 用户ID
     * @param configIndex 配置索引
     * @return 更新后的用户
     */
    Mono<User> setDefaultAIModelConfig(String userId, int configIndex);
    
    /**
     * 获取用户的所有AI模型配置
     * @param userId 用户ID
     * @return AI模型配置列表
     */
    Flux<AIModelConfig> getUserAIModelConfigs(String userId);
    
    /**
     * 获取用户的默认AI模型配置
     * @param userId 用户ID
     * @return 默认AI模型配置
     */
    Mono<AIModelConfig> getUserDefaultAIModelConfig(String userId);
} 