package com.ainovel.server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class SecurityBeanConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * 安全过滤器链
     * @param http HTTP安全配置
     * @return 安全过滤器链
     * 
     * 注释掉此方法，避免与其他安全配置冲突
     */
    /*
    @Bean
    public SecurityWebFilterChain securityWebFilterChain(ServerHttpSecurity http) {
        return http
                .csrf(ServerHttpSecurity.CsrfSpec::disable)
                .authorizeExchange(exchanges -> exchanges
                        .pathMatchers("/api/users/register").permitAll()
                        .pathMatchers("/**").permitAll() // 临时允许所有API访问，后续添加认证
                        .anyExchange().permitAll() // 临时允许所有访问，用于调试
                )
                .httpBasic(ServerHttpSecurity.HttpBasicSpec::disable) // 禁用HTTP Basic认证
                .formLogin(ServerHttpSecurity.FormLoginSpec::disable) // 禁用表单登录
                .build();
    }
    */
}