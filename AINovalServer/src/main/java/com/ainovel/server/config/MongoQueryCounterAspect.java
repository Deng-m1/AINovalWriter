package com.ainovel.server.config;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.EnableAspectJAutoProxy;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * MongoDB查询计数器切面
 * 用于统计MongoDB查询数量和执行时间
 */
@Aspect
@Configuration
@EnableAspectJAutoProxy
public class MongoQueryCounterAspect {

    private static final Logger logger = LoggerFactory.getLogger(MongoQueryCounterAspect.class);

    private final MeterRegistry meterRegistry;
    private final ConcurrentMap<String, AtomicLong> queryCounters = new ConcurrentHashMap<>();
    private final ConcurrentMap<String, Timer> queryTimers = new ConcurrentHashMap<>();

    public MongoQueryCounterAspect(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    /**
     * 拦截ReactiveMongoTemplate的所有查询方法
     * @param joinPoint 切点
     * @return 查询结果
     * @throws Throwable 异常
     */
    @Around("execution(* org.springframework.data.mongodb.core.ReactiveMongoTemplate.find*(..)) || " +
            "execution(* org.springframework.data.mongodb.core.ReactiveMongoTemplate.count*(..)) || " +
            "execution(* org.springframework.data.mongodb.core.ReactiveMongoTemplate.exists*(..)) || " +
            "execution(* org.springframework.data.mongodb.core.ReactiveMongoTemplate.get*(..)) || " +
            "execution(* org.springframework.data.mongodb.core.ReactiveMongoTemplate.update*(..))")
    public Object countQueries(ProceedingJoinPoint joinPoint) throws Throwable {
        String methodName = joinPoint.getSignature().getName();
        String className = joinPoint.getTarget().getClass().getSimpleName();
        String queryKey = className + "." + methodName;

        // 增加查询计数
        AtomicLong counter = queryCounters.computeIfAbsent(queryKey, k -> {
            AtomicLong newCounter = new AtomicLong(0);
            Counter.builder("mongodb.queries")
                    .tag("method", methodName)
                    .tag("class", className)
                    .register(meterRegistry);
            return newCounter;
        });
        counter.incrementAndGet();

        // 获取或创建计时器
        Timer timer = queryTimers.computeIfAbsent(queryKey, k ->
                Timer.builder("mongodb.query.timer")
                        .tag("method", methodName)
                        .tag("class", className)
                        .register(meterRegistry));

        // 记录开始时间
        long startTime = System.currentTimeMillis();

        try {
            // 执行原始方法
            Object result = joinPoint.proceed();

            // 计算执行时间
            long executionTime = System.currentTimeMillis() - startTime;

            // 记录查询信息
            logger.debug("MongoDB查询: {}, 执行时间: {}ms, 总执行次数: {}",
                    queryKey, executionTime, counter.get());

            // 记录计时器
            timer.record(() -> {
                try {
                    Thread.sleep(executionTime);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            });

            // 如果结果是Flux，添加日志记录
            if (result instanceof Flux) {
                return ((Flux<?>) result).doOnComplete(() ->
                        logResultCount(queryKey, counter.get()));
            }
            // 如果结果是Mono，添加日志记录
            else if (result instanceof Mono) {
                return ((Mono<?>) result).doOnSuccess(value ->
                        logResultValue(queryKey, value));
            }

            return result;
        } catch (Throwable e) {
            logger.error("MongoDB查询出错: {}, 错误: {}", queryKey, e.getMessage());
            throw e;
        }
    }

    /**
     * 记录Flux结果数量
     * @param queryKey 查询键
     * @param count 结果数量
     */
    private void logResultCount(String queryKey, long count) {
        logger.debug("MongoDB查询完成: {}, 结果数量: {}", queryKey, count);
    }

    /**
     * 记录Mono结果值
     * @param queryKey 查询键
     * @param value 结果值
     */
    private void logResultValue(String queryKey, Object value) {
        boolean hasResult = value != null;
        logger.debug("MongoDB查询完成: {}, 是否有结果: {}", queryKey, hasResult);
    }
}