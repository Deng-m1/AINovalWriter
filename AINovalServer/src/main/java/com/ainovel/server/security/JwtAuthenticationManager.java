package com.ainovel.server.security;

import java.util.Collections;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.ReactiveAuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.service.JwtService;
import com.ainovel.server.service.UserService;

import reactor.core.publisher.Mono;

/**
 * JWT认证管理器
 * 负责验证JWT令牌并创建认证对象
 */
@Component
public class JwtAuthenticationManager implements ReactiveAuthenticationManager {
    
    private final JwtService jwtService;
    private final UserService userService;
    
    @Autowired
    public JwtAuthenticationManager(JwtService jwtService, UserService userService) {
        this.jwtService = jwtService;
        this.userService = userService;
    }
    
    @Override
    public Mono<Authentication> authenticate(Authentication authentication) {
        String token = authentication.getCredentials().toString();
        
        try {
            String username = jwtService.extractUsername(token);
            
            return userService.findUserByUsername(username)
                    .filter(user -> jwtService.validateToken(token, user))
                    .map(user -> createAuthentication(user, token))
                    .switchIfEmpty(Mono.empty());
        } catch (Exception e) {
            return Mono.empty();
        }
    }
    
    private Authentication createAuthentication(User user, String token) {
        // 创建认证对象，包含用户信息和权限
        return new UsernamePasswordAuthenticationToken(
                user,
                token,
                Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER"))
        );
    }
} 