package com.ainovel.server.repository.custom;

import com.ainovel.server.domain.model.User;

import reactor.core.publisher.Mono;

/**
 * 自定义用户仓库接口
 * 定义带有日志和计数功能的方法
 */
public interface CustomUserRepository {
    
    /**
     * 根据用户名查找用户，并记录查询日志
     * @param username 用户名
     * @return 用户信息
     */
    Mono<User> findByUsernameWithLogging(String username);
    
    /**
     * 根据邮箱查找用户，并记录查询日志
     * @param email 邮箱
     * @return 用户信息
     */
    Mono<User> findByEmailWithLogging(String email);
    
    /**
     * 检查用户名是否存在，并记录查询日志
     * @param username 用户名
     * @return 是否存在
     */
    Mono<Boolean> existsByUsernameWithLogging(String username);
    
    /**
     * 检查邮箱是否存在，并记录查询日志
     * @param email 邮箱
     * @return 是否存在
     */
    Mono<Boolean> existsByEmailWithLogging(String email);
} 