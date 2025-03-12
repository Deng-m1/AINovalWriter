package com.ainovel.server.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.EnableAspectJAutoProxy;

import io.micrometer.core.aop.TimedAspect;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.binder.jvm.ClassLoaderMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmGcMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmMemoryMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmThreadMetrics;
import io.micrometer.core.instrument.binder.system.ProcessorMetrics;

/**
 * 监控配置类
 * 配置Micrometer和Prometheus指标收集
 */
@Configuration
@EnableAspectJAutoProxy
public class MonitoringConfig {

    /**
     * 配置TimedAspect用于方法执行时间监控
     * @param registry 指标注册表
     * @return TimedAspect实例
     */
    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }

    /**
     * JVM类加载器指标
     * @param registry 指标注册表
     * @return ClassLoaderMetrics实例
     */
    @Bean
    public ClassLoaderMetrics classLoaderMetrics(MeterRegistry registry) {
        ClassLoaderMetrics metrics = new ClassLoaderMetrics();
        metrics.bindTo(registry);
        return metrics;
    }

    /**
     * JVM内存指标
     * @param registry 指标注册表
     * @return JvmMemoryMetrics实例
     */
    @Bean
    public JvmMemoryMetrics jvmMemoryMetrics(MeterRegistry registry) {
        JvmMemoryMetrics metrics = new JvmMemoryMetrics();
        metrics.bindTo(registry);
        return metrics;
    }

    /**
     * JVM垃圾回收指标
     * @param registry 指标注册表
     * @return JvmGcMetrics实例
     */
    @Bean
    public JvmGcMetrics jvmGcMetrics(MeterRegistry registry) {
        JvmGcMetrics metrics = new JvmGcMetrics();
        metrics.bindTo(registry);
        return metrics;
    }

    /**
     * JVM线程指标
     * @param registry 指标注册表
     * @return JvmThreadMetrics实例
     */
    @Bean
    public JvmThreadMetrics jvmThreadMetrics(MeterRegistry registry) {
        JvmThreadMetrics metrics = new JvmThreadMetrics();
        metrics.bindTo(registry);
        return metrics;
    }

    /**
     * 处理器指标
     * @param registry 指标注册表
     * @return ProcessorMetrics实例
     */
    @Bean
    public ProcessorMetrics processorMetrics(MeterRegistry registry) {
        ProcessorMetrics metrics = new ProcessorMetrics();
        metrics.bindTo(registry);
        return metrics;
    }
} 