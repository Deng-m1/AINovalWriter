package com.ainovel.server.security;

import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.server.authentication.ServerAuthenticationConverter;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;

import reactor.core.publisher.Mono;

/**
 * JWT认证转换器
 * 从HTTP请求中提取JWT令牌并创建认证对象
 */
@Component
public class JwtServerAuthenticationConverter implements ServerAuthenticationConverter {
    
    private static final String BEARER_PREFIX = "Bearer ";
    
    @Override
    public Mono<Authentication> convert(ServerWebExchange exchange) {
        return Mono.justOrEmpty(exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION))
                .filter(authHeader -> authHeader.startsWith(BEARER_PREFIX))
                .map(authHeader -> authHeader.substring(BEARER_PREFIX.length()))
                .map(token -> new UsernamePasswordAuthenticationToken(token, token));
    }
} 