package com.ainovel.server.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskDecorator;
import org.springframework.web.filter.CommonsRequestLoggingFilter;
import org.springframework.web.server.WebFilter;
import reactor.core.publisher.Hooks;

import jakarta.annotation.PostConstruct;
import java.util.Map;
import java.util.UUID;

/**
 * 日志配置，包括MDC跟踪信息和日志格式设置
 */
@Configuration
public class LoggingConfiguration {

    private static final Logger logger = LoggerFactory.getLogger(LoggingConfiguration.class);
    
    /**
     * 设置Reactor上下文传播MDC
     */
    @PostConstruct
    public void init() {
        logger.info("配置Reactor上下文传播MDC");
        
        // 设置Reactor Context传递MDC
        // 注意：这个功能需要更新Reactor版本并完善实现逻辑
        // 在Reactor高版本中应该使用ContextPropagation.withThreadLocalContextRegistry
        logger.info("MDC传播将在后续实现");
    }
    
    /**
     * WebFlux请求过滤器，用于设置MDC上下文
     */
    @Bean
    public WebFilter mdcFilter() {
        return (exchange, chain) -> {
            // 设置traceId
            String traceId = exchange.getRequest().getHeaders().getFirst("X-Trace-ID");
            if (traceId == null) {
                traceId = UUID.randomUUID().toString().replace("-", "");
            }
            MDC.put("traceId", traceId);
            
            // 如果请求头中有userId，也放入MDC
            String userId = exchange.getRequest().getHeaders().getFirst("X-User-ID");
            if (userId != null) {
                MDC.put("userId", userId);
            }
            
            // 设置请求路径
            String path = exchange.getRequest().getPath().value();
            MDC.put("path", path);
            
            // 处理完请求后需要清理MDC
            return chain.filter(exchange).doFinally(signalType -> MDC.clear());
        };
    }
    
    /**
     * 任务装饰器，用于异步任务间传递MDC
     */
    @Bean
    public TaskDecorator mdcTaskDecorator() {
        return task -> {
            Map<String, String> contextMap = MDC.getCopyOfContextMap();
            return () -> {
                try {
                    if (contextMap != null) {
                        MDC.setContextMap(contextMap);
                    }
                    task.run();
                } finally {
                    MDC.clear();
                }
            };
        };
    }
    
    /**
     * 请求日志过滤器
     */
    @Bean
    @ConditionalOnProperty(name = "logging.request", havingValue = "true")
    public CommonsRequestLoggingFilter requestLoggingFilter() {
        CommonsRequestLoggingFilter filter = new CommonsRequestLoggingFilter();
        filter.setIncludeQueryString(true);
        filter.setIncludePayload(true);
        filter.setMaxPayloadLength(10000);
        filter.setIncludeHeaders(false);
        filter.setAfterMessagePrefix("Request data: ");
        return filter;
    }
} 