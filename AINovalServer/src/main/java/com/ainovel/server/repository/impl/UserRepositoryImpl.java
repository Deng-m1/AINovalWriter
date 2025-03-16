package com.ainovel.server.repository.impl;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Component;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.repository.custom.CustomUserRepository;

import reactor.core.publisher.Mono;

/**
 * UserRepository接口的自定义实现
 * 添加查询日志和计数功能
 */
@Component
public class UserRepositoryImpl implements CustomUserRepository {
    
    private static final Logger logger = LoggerFactory.getLogger(UserRepositoryImpl.class);
    
    private final ReactiveMongoTemplate mongoTemplate;
    
    @Autowired
    public UserRepositoryImpl(ReactiveMongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }
    
    /**
     * 根据用户名查找用户，并记录查询日志
     * @param username 用户名
     * @return 用户信息
     */
    @Override
    public Mono<User> findByUsernameWithLogging(String username) {
        logger.debug("开始查询用户: username={}", username);
        
        Query query = new Query(Criteria.where("username").is(username));
        
        return mongoTemplate.findOne(query, User.class)
                .doOnSuccess(user -> {
                    if (user != null) {
                        logger.debug("查询用户成功: username={}, userId={}", username, user.getId());
                    } else {
                        logger.debug("未找到用户: username={}", username);
                    }
                })
                .doOnError(error -> 
                    logger.error("查询用户出错: username={}, error={}", username, error.getMessage())
                );
    }
    
    /**
     * 根据邮箱查找用户，并记录查询日志
     * @param email 邮箱
     * @return 用户信息
     */
    @Override
    public Mono<User> findByEmailWithLogging(String email) {
        logger.debug("开始查询用户: email={}", email);
        
        Query query = new Query(Criteria.where("email").is(email));
        
        return mongoTemplate.findOne(query, User.class)
                .doOnSuccess(user -> {
                    if (user != null) {
                        logger.debug("查询用户成功: email={}, userId={}", email, user.getId());
                    } else {
                        logger.debug("未找到用户: email={}", email);
                    }
                })
                .doOnError(error -> 
                    logger.error("查询用户出错: email={}, error={}", email, error.getMessage())
                );
    }
    
    /**
     * 检查用户名是否存在，并记录查询日志
     * @param username 用户名
     * @return 是否存在
     */
    @Override
    public Mono<Boolean> existsByUsernameWithLogging(String username) {
        logger.debug("检查用户名是否存在: username={}", username);
        
        Query query = new Query(Criteria.where("username").is(username));
        
        return mongoTemplate.exists(query, User.class)
                .doOnSuccess(exists -> 
                    logger.debug("用户名存在检查结果: username={}, exists={}", username, exists)
                )
                .doOnError(error -> 
                    logger.error("检查用户名是否存在出错: username={}, error={}", username, error.getMessage())
                );
    }
    
    /**
     * 检查邮箱是否存在，并记录查询日志
     * @param email 邮箱
     * @return 是否存在
     */
    @Override
    public Mono<Boolean> existsByEmailWithLogging(String email) {
        logger.debug("检查邮箱是否存在: email={}", email);
        
        Query query = new Query(Criteria.where("email").is(email));
        
        return mongoTemplate.exists(query, User.class)
                .doOnSuccess(exists -> 
                    logger.debug("邮箱存在检查结果: email={}, exists={}", email, exists)
                )
                .doOnError(error -> 
                    logger.error("检查邮箱是否存在出错: email={}, error={}", email, error.getMessage())
                );
    }
} 