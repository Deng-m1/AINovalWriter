package com.ainovel.server.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.User;
import com.ainovel.server.service.JwtService;
import com.ainovel.server.service.UserService;
import com.ainovel.server.web.dto.AuthRequest;
import com.ainovel.server.web.dto.AuthResponse;
import com.ainovel.server.web.dto.ChangePasswordRequest;
import com.ainovel.server.web.dto.RefreshTokenRequest;
import com.ainovel.server.web.dto.UserRegistrationRequest;

import reactor.core.publisher.Mono;

/**
 * 认证控制器
 * 处理用户登录、注册和令牌刷新
 */
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    
    private final UserService userService;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    
    @Autowired
    public AuthController(UserService userService, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userService = userService;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }
    
    /**
     * 用户登录
     * @param request 登录请求
     * @return 认证响应
     */
    @PostMapping("/login")
    public Mono<ResponseEntity<AuthResponse>> login(@RequestBody AuthRequest request) {
        return userService.findUserByUsername(request.getUsername())
                .filter(user -> passwordEncoder.matches(request.getPassword(), user.getPassword()))
                .map(user -> {
                    String token = jwtService.generateToken(user);
                    String refreshToken = jwtService.generateRefreshToken(user);
                    
                    AuthResponse response = new AuthResponse(
                            token,
                            refreshToken,
                            user.getId(),
                            user.getUsername(),
                            user.getDisplayName()
                    );
                    
                    return ResponseEntity.ok(response);
                })
                .defaultIfEmpty(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }
    
    /**
     * 用户注册
     * @param request 注册请求
     * @return 认证响应
     */
    @PostMapping("/register")
    public Mono<ResponseEntity<AuthResponse>> register(@RequestBody UserRegistrationRequest request) {
        User user = User.builder()
                .username(request.getUsername())
                .password(request.getPassword())
                .email(request.getEmail())
                .displayName(request.getDisplayName())
                .build();
        
        return userService.findUserByUsername(request.getUsername())
                .flatMap(existingUser -> Mono.<ResponseEntity<AuthResponse>>just(ResponseEntity.status(HttpStatus.CONFLICT).build()))
                .switchIfEmpty(
                    userService.createUser(user)
                        .map(createdUser -> {
                            String token = jwtService.generateToken(createdUser);
                            String refreshToken = jwtService.generateRefreshToken(createdUser);
                            
                            AuthResponse response = new AuthResponse(
                                    token,
                                    refreshToken,
                                    createdUser.getId(),
                                    createdUser.getUsername(),
                                    createdUser.getDisplayName()
                            );
                            
                            return ResponseEntity.status(HttpStatus.CREATED).body(response);
                        })
                );
    }
    
    /**
     * 刷新令牌
     * @param request 刷新令牌请求
     * @return 认证响应
     */
    @PostMapping("/refresh")
    public Mono<ResponseEntity<AuthResponse>> refreshToken(@RequestBody RefreshTokenRequest request) {
        try {
            String username = jwtService.extractUsername(request.getRefreshToken());
            
            return userService.findUserByUsername(username)
                    .filter(user -> jwtService.validateToken(request.getRefreshToken(), user))
                    .map(user -> {
                        String newToken = jwtService.generateToken(user);
                        String newRefreshToken = jwtService.generateRefreshToken(user);
                        
                        AuthResponse response = new AuthResponse(
                                newToken,
                                newRefreshToken,
                                user.getId(),
                                user.getUsername(),
                                user.getDisplayName()
                        );
                        
                        return ResponseEntity.ok(response);
                    })
                    .defaultIfEmpty(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
        } catch (Exception e) {
            return Mono.just(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
        }
    }
    
    /**
     * 修改密码
     * @param request 修改密码请求
     * @return 操作结果
     */
    @PostMapping("/change-password")
    public Mono<ResponseEntity<Void>> changePassword(@RequestBody ChangePasswordRequest request) {
        return userService.findUserByUsername(request.getUsername())
                .filter(user -> passwordEncoder.matches(request.getCurrentPassword(), user.getPassword()))
                .flatMap(user -> {
                    user.setPassword(passwordEncoder.encode(request.getNewPassword()));
                    return userService.updateUser(user.getId(), user);
                })
                .map(updatedUser -> ResponseEntity.ok().<Void>build())
                .defaultIfEmpty(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }
} 