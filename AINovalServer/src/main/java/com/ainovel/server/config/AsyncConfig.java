package com.ainovel.server.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

/**
 * 异步处理配置
 */
@Configuration
@EnableAsync
public class AsyncConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(AsyncConfig.class);
    
    /**
     * 配置用于事件监听器的异步执行器
     * 使用虚拟线程处理异步事件
     */
    @Bean(name = "taskAsyncExecutor")
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        
        // 如果支持虚拟线程（Java 21+），则使用虚拟线程
        try {
            ThreadFactory virtualThreadFactory = Thread.ofVirtual().name("event-", 0).factory();
            executor.setTaskDecorator(runnable -> () -> {
                Thread thread = Thread.currentThread();
                String oldName = thread.getName();
                try {
                    runnable.run();
                } finally {
                    thread.setName(oldName);
                }
            });
            executor.setThreadFactory(virtualThreadFactory);
            executor.setCorePoolSize(1);  // 使用虚拟线程时，核心线程数可以设置很低
            executor.setMaxPoolSize(Integer.MAX_VALUE);  // 虚拟线程几乎无限制
            logger.info("已启用虚拟线程处理异步事件");
        } catch (NoSuchMethodError | UnsupportedOperationException e) {
            // 如果不支持虚拟线程，则使用普通线程池
            executor.setCorePoolSize(4);
            executor.setMaxPoolSize(10);
            executor.setQueueCapacity(100);
            executor.setThreadNamePrefix("event-thread-");
            logger.info("已启用平台线程处理异步事件");
        }
        
        executor.initialize();
        return executor;
    }
    
    /**
     * 提供一个虚拟线程执行器，用于任务执行过程中的IO密集型操作
     */
    @Bean(name = "virtualThreadExecutor")
    public ExecutorService virtualThreadExecutor() {
        try {
            // 尝试创建虚拟线程执行器
            ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
            logger.info("已创建虚拟线程执行器用于IO密集型操作");
            return executor;
        } catch (NoSuchMethodError | UnsupportedOperationException e) {
            // 如果不支持虚拟线程，则使用固定大小的线程池
            ExecutorService executor = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors() * 2, 
                    Thread.ofPlatform().name("io-thread-", 0).factory());
            logger.info("不支持虚拟线程，已创建平台线程池用于IO密集型操作");
            return executor;
        }
    }
} 