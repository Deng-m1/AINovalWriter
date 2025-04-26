package com.ainovel.server.task.metrics;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 任务系统的指标收集器，记录各种任务执行指标
 */
@Component
public class TaskMetrics {

    private MeterRegistry meterRegistry;
    
    // 任务计数指标
    private final Map<String, Counter> taskSubmittedCounters = new ConcurrentHashMap<>();
    private final Map<String, Counter> taskCompletedCounters = new ConcurrentHashMap<>();
    private final Map<String, Counter> taskFailedCounters = new ConcurrentHashMap<>();
    private final Map<String, Counter> taskRetryCounters = new ConcurrentHashMap<>();
    
    // 任务耗时指标
    private final Map<String, Timer> taskExecutionTimers = new ConcurrentHashMap<>();
    
    // 活跃任务数量
    private final Map<String, AtomicInteger> activeTasksGauges = new ConcurrentHashMap<>();
    
    // 总体统计
    private Counter totalSubmitted;
    private Counter totalCompleted;
    private Counter totalFailed;
    private AtomicInteger totalActive = new AtomicInteger(0);
    
    @Autowired
    public TaskMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }
    
    @PostConstruct
    public void init() {
        // 初始化总体指标
        totalSubmitted = Counter.builder("tasks.submitted.total")
                .description("提交的总任务数")
                .register(meterRegistry);
                
        totalCompleted = Counter.builder("tasks.completed.total")
                .description("完成的总任务数")
                .register(meterRegistry);
                
        totalFailed = Counter.builder("tasks.failed.total")
                .description("失败的总任务数")
                .register(meterRegistry);
                
        Gauge.builder("tasks.active.total", totalActive, AtomicInteger::get)
                .description("当前活跃的任务数")
                .register(meterRegistry);
    }
    
    /**
     * 记录任务提交
     */
    public void recordTaskSubmitted(String taskType) {
        // 总计数器
        totalSubmitted.increment();
        totalActive.incrementAndGet();
        
        // 按类型计数器
        taskSubmittedCounters.computeIfAbsent(taskType, type -> 
            Counter.builder("tasks.submitted")
                  .tag("type", type)
                  .description("提交的任务数")
                  .register(meterRegistry)
        ).increment();
        
        // 按类型活跃任务数
        activeTasksGauges.computeIfAbsent(taskType, type -> {
            AtomicInteger activeCount = new AtomicInteger(0);
            Gauge.builder("tasks.active", activeCount, AtomicInteger::get)
                 .tag("type", type)
                 .description("当前活跃的任务数")
                 .register(meterRegistry);
            return activeCount;
        }).incrementAndGet();
    }
    
    /**
     * 记录任务完成
     */
    public void recordTaskCompleted(String taskType, long durationMillis) {
        // 总计数器
        totalCompleted.increment();
        totalActive.decrementAndGet();
        
        // 按类型计数器
        taskCompletedCounters.computeIfAbsent(taskType, type -> 
            Counter.builder("tasks.completed")
                  .tag("type", type)
                  .description("完成的任务数")
                  .register(meterRegistry)
        ).increment();
        
        // 按类型活跃任务数
        AtomicInteger activeCount = activeTasksGauges.get(taskType);
        if (activeCount != null) {
            activeCount.decrementAndGet();
        }
        
        // 记录执行时间
        taskExecutionTimers.computeIfAbsent(taskType, type -> 
            Timer.builder("tasks.execution.time")
                 .tag("type", type)
                 .description("任务执行时间")
                 .register(meterRegistry)
        ).record(durationMillis, java.util.concurrent.TimeUnit.MILLISECONDS);
    }
    
    /**
     * 记录任务失败
     */
    public void recordTaskFailed(String taskType, long durationMillis) {
        // 总计数器
        totalFailed.increment();
        totalActive.decrementAndGet();
        
        // 按类型计数器
        taskFailedCounters.computeIfAbsent(taskType, type -> 
            Counter.builder("tasks.failed")
                  .tag("type", type)
                  .description("失败的任务数")
                  .register(meterRegistry)
        ).increment();
        
        // 按类型活跃任务数
        AtomicInteger activeCount = activeTasksGauges.get(taskType);
        if (activeCount != null) {
            activeCount.decrementAndGet();
        }
        
        // 记录执行时间（即使失败也记录，便于分析）
        taskExecutionTimers.computeIfAbsent(taskType, type -> 
            Timer.builder("tasks.execution.time")
                 .tag("type", type)
                 .tag("status", "failed")
                 .description("任务执行时间")
                 .register(meterRegistry)
        ).record(durationMillis, java.util.concurrent.TimeUnit.MILLISECONDS);
    }
    
    /**
     * 记录任务重试
     */
    public void recordTaskRetry(String taskType) {
        taskRetryCounters.computeIfAbsent(taskType, type -> 
            Counter.builder("tasks.retried")
                  .tag("type", type)
                  .description("重试的任务数")
                  .register(meterRegistry)
        ).increment();
    }
} 