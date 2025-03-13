package com.ainovel.server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;

/**
 * 测试环境专用安全配置
 * 仅在测试环境（test或performance-test配置文件激活时）生效
 * 禁用JWT验证和CSRF保护，方便测试
 */
@Configuration
@EnableWebFluxSecurity
@Profile({ "test", "performance-test" })
public class TestSecurityConfig {

    @Bean
    public SecurityWebFilterChain testSecurityFilterChain(ServerHttpSecurity http) {
        return http
                .csrf().disable() // 禁用CSRF保护
                .authorizeExchange()
                .pathMatchers("/**").permitAll() // 允许所有请求通过，不需要认证
                .and()
                .httpBasic().disable()
                .formLogin().disable()
                .build();
    }
}