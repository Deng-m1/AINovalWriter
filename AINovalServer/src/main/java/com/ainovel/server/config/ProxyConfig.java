package com.ainovel.server.config;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.event.ContextRefreshedEvent;
import org.springframework.context.event.EventListener;

import com.ainovel.server.service.ai.AIModelProvider;

import lombok.extern.slf4j.Slf4j;

/**
 * HTTP代理配置
 */
@Slf4j
@Configuration
public class ProxyConfig {

    @Value("${proxy.enabled:false}")
    private boolean proxyEnabled;

    @Value("${proxy.host:localhost}")
    private String proxyHost;

    @Value("${proxy.port:6888}")
    private int proxyPort;

    private final List<AIModelProvider> modelProviders;

    /**
     * 构造函数
     * @param modelProviders AI模型提供商列表
     */
    public ProxyConfig(List<AIModelProvider> modelProviders) {
        this.modelProviders = modelProviders;
    }

    /**
     * 应用启动时配置代理
     * @param event 上下文刷新事件
     */
    @EventListener
    public void onApplicationEvent(ContextRefreshedEvent event) {
        if (proxyEnabled) {
            log.info("正在为AI模型提供商配置HTTP代理: {}:{}", proxyHost, proxyPort);
            
            for (AIModelProvider provider : modelProviders) {
                try {
                    provider.setProxy(proxyHost, proxyPort);
                    log.info("已为 {} 模型提供商配置代理", provider.getProviderName());
                } catch (Exception e) {
                    log.error("为 {} 模型提供商配置代理时出错: {}", provider.getProviderName(), e.getMessage(), e);
                }
            }
        } else {
            log.info("HTTP代理未启用");
        }
    }
} 