package com.ainovel.server.service.impl;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.domain.model.User.AIModelConfig;
import com.ainovel.server.repository.UserRepository;
import com.ainovel.server.service.UserService;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 用户服务实现
 */
@Service
public class UserServiceImpl implements UserService {
    
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    
    @Autowired
    public UserServiceImpl(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }
    
    @Override
    public Mono<User> createUser(User user) {
        // 设置创建时间和更新时间
        LocalDateTime now = LocalDateTime.now();
        user.setCreatedAt(now);
        user.setUpdatedAt(now);
        
        // 加密密码
        return Mono.just(user)
                .map(u -> {
                    u.setPassword(passwordEncoder.encode(u.getPassword()));
                    return u;
                })
                .flatMap(userRepository::save);
    }
    
    @Override
    public Mono<User> findUserById(String id) {
        return userRepository.findById(id);
    }
    
    @Override
    public Mono<User> findUserByUsername(String username) {
        return userRepository.findByUsername(username);
    }
    
    @Override
    public Mono<User> updateUser(String id, User user) {
        return userRepository.findById(id)
                .map(existingUser -> {
                    // 更新基本信息，但不更新密码、创建时间等敏感字段
                    existingUser.setDisplayName(user.getDisplayName());
                    existingUser.setAvatar(user.getAvatar());
                    existingUser.setPreferences(user.getPreferences());
                    existingUser.setUpdatedAt(LocalDateTime.now());
                    return existingUser;
                })
                .flatMap(userRepository::save);
    }
    
    @Override
    public Mono<Void> deleteUser(String id) {
        return userRepository.deleteById(id);
    }
    
    @Override
    public Mono<User> addAIModelConfig(String userId, AIModelConfig config) {
        return userRepository.findById(userId)
                .map(user -> {
                    // 如果是第一个配置或设置为默认，则将其他配置设为非默认
                    if (user.getAiModelConfigs().isEmpty() || Boolean.TRUE.equals(config.getIsDefault())) {
                        user.getAiModelConfigs().forEach(c -> c.setIsDefault(false));
                    }
                    
                    // 添加新配置
                    user.getAiModelConfigs().add(config);
                    user.setUpdatedAt(LocalDateTime.now());
                    return user;
                })
                .flatMap(userRepository::save);
    }
    
    @Override
    public Mono<User> updateAIModelConfig(String userId, int configIndex, AIModelConfig config) {
        return userRepository.findById(userId)
                .map(user -> {
                    List<AIModelConfig> configs = user.getAiModelConfigs();
                    
                    // 检查索引是否有效
                    if (configIndex >= 0 && configIndex < configs.size()) {
                        // 如果设置为默认，则将其他配置设为非默认
                        if (Boolean.TRUE.equals(config.getIsDefault())) {
                            configs.forEach(c -> c.setIsDefault(false));
                        }
                        
                        // 更新配置
                        configs.set(configIndex, config);
                        user.setUpdatedAt(LocalDateTime.now());
                    }
                    
                    return user;
                })
                .flatMap(userRepository::save);
    }
    
    @Override
    public Mono<User> deleteAIModelConfig(String userId, int configIndex) {
        return userRepository.findById(userId)
                .map(user -> {
                    List<AIModelConfig> configs = user.getAiModelConfigs();
                    
                    // 检查索引是否有效
                    if (configIndex >= 0 && configIndex < configs.size()) {
                        // 检查是否删除的是默认配置
                        boolean wasDefault = Boolean.TRUE.equals(configs.get(configIndex).getIsDefault());
                        
                        // 删除配置
                        configs.remove(configIndex);
                        
                        // 如果删除的是默认配置且还有其他配置，则将第一个配置设为默认
                        if (wasDefault && !configs.isEmpty()) {
                            configs.get(0).setIsDefault(true);
                        }
                        
                        user.setUpdatedAt(LocalDateTime.now());
                    }
                    
                    return user;
                })
                .flatMap(userRepository::save);
    }
    
    @Override
    public Mono<User> setDefaultAIModelConfig(String userId, int configIndex) {
        return userRepository.findById(userId)
                .map(user -> {
                    List<AIModelConfig> configs = user.getAiModelConfigs();
                    
                    // 检查索引是否有效
                    if (configIndex >= 0 && configIndex < configs.size()) {
                        // 将所有配置设为非默认
                        configs.forEach(c -> c.setIsDefault(false));
                        
                        // 将指定配置设为默认
                        configs.get(configIndex).setIsDefault(true);
                        user.setUpdatedAt(LocalDateTime.now());
                    }
                    
                    return user;
                })
                .flatMap(userRepository::save);
    }
    
    @Override
    public Flux<AIModelConfig> getUserAIModelConfigs(String userId) {
        return userRepository.findById(userId)
                .flatMapMany(user -> Flux.fromIterable(user.getAiModelConfigs()));
    }
    
    @Override
    public Mono<AIModelConfig> getUserDefaultAIModelConfig(String userId) {
        return userRepository.findById(userId)
                .map(User::getDefaultAIModelConfig);
    }
} 