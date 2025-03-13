package com.ainovel.server.config;

import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.config.EnableWebFlux;

import reactor.netty.resources.LoopResources;

/**
 * 虚拟线程配置类
 * 配置Spring WebFlux使用JDK 23虚拟线程
 */
@Configuration
@EnableWebFlux
public class VirtualThreadConfig {
    
    /**
     * 配置虚拟线程执行器
     * 使用JDK 23的虚拟线程特性
     */
    @Bean
    public Executor taskExecutor() {
        return Executors.newVirtualThreadPerTaskExecutor();
    }
    
    /**
     * 配置Reactor Netty资源
     * 优化WebFlux的底层资源使用
     */
    @Bean
    public LoopResources loopResources() {
        return LoopResources.create("reactor-http", 1, 
                Runtime.getRuntime().availableProcessors() * 2, true);
    }
} 