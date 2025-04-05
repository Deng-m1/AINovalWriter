package com.ainovel.server.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.config.EnableWebFlux;
import org.springframework.web.reactive.config.WebFluxConfigurer;
import org.springframework.web.reactive.result.method.annotation.ArgumentResolverConfigurer;

import com.ainovel.server.common.security.CurrentUserMethodArgumentResolver;

/**
 * WebFlux配置 用于配置参数解析器、跨域等
 */
@Configuration
@EnableWebFlux
public class WebConfig implements WebFluxConfigurer {

    private final CurrentUserMethodArgumentResolver currentUserResolver;

    @Autowired
    public WebConfig(CurrentUserMethodArgumentResolver currentUserResolver) {
        this.currentUserResolver = currentUserResolver;
    }

    @Override
    public void configureArgumentResolvers(ArgumentResolverConfigurer configurer) {
        configurer.addCustomResolver(currentUserResolver);
    }
}
