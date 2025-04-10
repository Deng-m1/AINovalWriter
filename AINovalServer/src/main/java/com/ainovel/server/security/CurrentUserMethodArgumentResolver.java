package com.ainovel.server.security;

import org.jetbrains.annotations.NotNull;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.BindingContext;
import org.springframework.web.reactive.result.method.HandlerMethodArgumentResolver;
import org.springframework.web.server.ServerWebExchange;

import com.ainovel.server.domain.model.User;

import reactor.core.publisher.Mono;

/**
 * 当前用户方法参数解析器
 * 用于解析标注了@AuthenticationPrincipal的方法参数，将其解析为CurrentUser对象
 */
@Component
public class CurrentUserMethodArgumentResolver implements HandlerMethodArgumentResolver {

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.getParameterAnnotation(org.springframework.security.core.annotation.AuthenticationPrincipal.class) != null
                && parameter.getParameterType().equals(CurrentUser.class);
    }

    @NotNull
    @Override
    public Mono<Object> resolveArgument(MethodParameter parameter, BindingContext bindingContext,
            ServerWebExchange exchange) {

        return ReactiveSecurityContextHolder.getContext()
                .map(SecurityContext::getAuthentication)
                .filter(Authentication::isAuthenticated)
                .map(Authentication::getPrincipal)
                .cast(User.class)
                .map(user -> new CurrentUser(user.getId(), user.getUsername()))
                .cast(Object.class)
                .switchIfEmpty(Mono.error(new IllegalStateException("当前用户未认证")));
    }
} 