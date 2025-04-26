package com.ainovel.server.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.listener.RabbitListenerEndpointRegistry;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationListener;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.event.ContextClosedEvent;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * 优雅停机配置，确保应用程序关闭时不丢失消息和任务
 */
@Configuration
public class GracefulShutdownConfiguration implements ApplicationListener<ContextClosedEvent> {

    private static final Logger logger = LoggerFactory.getLogger(GracefulShutdownConfiguration.class);
    
    @Autowired
    private RabbitListenerEndpointRegistry rabbitListenerEndpointRegistry;
    
    @Value("${task.shutdown.awaitTerminationTimeout:PT30S}")
    private String shutdownTimeoutString;
    
    @Override
    public void onApplicationEvent(ContextClosedEvent event) {
        logger.info("收到应用程序关闭事件，开始优雅停机...");
        
        // 解析超时时间（从ISO-8601 Duration字符串）
        long timeoutSeconds = 30; // 默认30秒
        try {
            timeoutSeconds = java.time.Duration.parse(shutdownTimeoutString).getSeconds();
        } catch (Exception e) {
            logger.warn("解析关闭超时时间失败，使用默认值30秒", e);
        }
        
        // 停止所有RabbitMQ监听器
        try {
            logger.info("停止RabbitMQ监听器...");
            rabbitListenerEndpointRegistry.stop();
            
            // 等待所有监听器停止
            CountDownLatch shutdownLatch = new CountDownLatch(1);
            new Thread(() -> {
                try {
                    while (!isAllListenersStopped()) {
                        Thread.sleep(500);
                    }
                    shutdownLatch.countDown();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }, "rabbit-shutdown-monitor").start();
            
            boolean allStopped = shutdownLatch.await(timeoutSeconds, TimeUnit.SECONDS);
            if (allStopped) {
                logger.info("所有RabbitMQ监听器已成功停止");
            } else {
                logger.warn("等待RabbitMQ监听器停止超时（{}秒），可能还有消息正在处理", timeoutSeconds);
            }
        } catch (Exception e) {
            logger.error("停止RabbitMQ监听器时发生异常", e);
        }
        
        logger.info("优雅停机完成，应用程序即将关闭");
    }
    
    /**
     * 检查所有监听器是否已停止
     */
    private boolean isAllListenersStopped() {
        return rabbitListenerEndpointRegistry.getListenerContainers().stream()
                .allMatch(container -> !container.isRunning());
    }
} 