package com.ainovel.server.service;

import com.ainovel.server.domain.model.User;

/**
 * JWT服务接口
 */
public interface JwtService {
    
    /**
     * 生成JWT令牌
     * @param user 用户
     * @return JWT令牌
     */
    String generateToken(User user);
    
    /**
     * 生成刷新令牌
     * @param user 用户
     * @return 刷新令牌
     */
    String generateRefreshToken(User user);
    
    /**
     * 从令牌中提取用户名
     * @param token JWT令牌
     * @return 用户名
     */
    String extractUsername(String token);
    
    /**
     * 验证令牌是否有效
     * @param token JWT令牌
     * @param user 用户
     * @return 是否有效
     */
    boolean validateToken(String token, User user);
} 