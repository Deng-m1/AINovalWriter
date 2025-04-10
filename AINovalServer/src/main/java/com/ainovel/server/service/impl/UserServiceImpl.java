package com.ainovel.server.service.impl;

import java.time.LocalDateTime;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.repository.UserRepository;
import com.ainovel.server.service.UserService;

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
    


} 