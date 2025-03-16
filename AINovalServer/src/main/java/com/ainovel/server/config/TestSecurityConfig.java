package com.ainovel.server.config;

import java.util.Arrays;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.reactive.CorsConfigurationSource;
import org.springframework.web.cors.reactive.UrlBasedCorsConfigurationSource;

/**
 * 测试环境专用安全配置
 * 仅在测试环境（test或performance-test配置文件激活时）生效
 * 禁用JWT验证和CSRF保护，方便测试
 */
@Configuration
@EnableWebFluxSecurity
@Profile({ "test", "performance-test" })
public class TestSecurityConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(TestSecurityConfig.class);

    @Bean
    public SecurityWebFilterChain testSecurityFilterChain(ServerHttpSecurity http) {
        logger.info("使用测试环境安全配置，所有请求将被允许通过，无需认证");
        
        return http
                .csrf(ServerHttpSecurity.CsrfSpec::disable) // 禁用CSRF保护
                .cors(corsSpec -> corsSpec.configurationSource(corsConfigurationSource()))
                .authorizeExchange(exchanges -> {
                    logger.debug("配置测试环境安全规则：允许所有请求");
                    exchanges
                        .pathMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .pathMatchers("/api/v1/**").permitAll() // 允许所有API请求
                        .pathMatchers("/**").permitAll() // 允许所有请求通过，不需要认证
                        .anyExchange().permitAll(); // 确保所有请求都允许通过
                })
                .httpBasic(ServerHttpSecurity.HttpBasicSpec::disable)
                .formLogin(ServerHttpSecurity.FormLoginSpec::disable)
                .build();
    }
    
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(Arrays.asList("*"));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("Authorization", "Content-Type"));
        configuration.setExposedHeaders(Arrays.asList("Authorization"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}