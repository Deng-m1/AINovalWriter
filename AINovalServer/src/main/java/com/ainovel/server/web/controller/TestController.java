package com.ainovel.server.web.controller;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.web.base.ReactiveBaseController;

import io.micrometer.core.annotation.Timed;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

/**
 * 测试控制器
 * 用于性能测试和比较虚拟线程与传统线程的性能差异
 */
@Slf4j
@RestController
@RequestMapping("/test")
@Profile({ "test", "performance-test" })
public class TestController extends ReactiveBaseController {

    private static final Logger logger = LoggerFactory.getLogger(TestController.class);

    private final Executor virtualThreadExecutor;
    private final Executor traditionalThreadExecutor;

    public TestController(
            @Qualifier("taskExecutor") Executor virtualThreadExecutor) {
        this.virtualThreadExecutor = virtualThreadExecutor;
        // 创建一个传统的固定大小线程池，用于对比
        this.traditionalThreadExecutor = Executors.newFixedThreadPool(200);
    }

    /**
     * 长时间运行的操作（使用虚拟线程）
     * 
     * @param request 请求参数
     * @return 操作结果
     */
    @PostMapping("/long-running")
    @Timed(value = "test.long.running.virtual", description = "Time taken for long running operation with virtual threads")
    public Mono<Map<String, Object>> longRunningOperation(@RequestBody Map<String, Object> request) {
        String requestId = request.getOrDefault("requestId", UUID.randomUUID().toString()).toString();
        int durationMs = Integer.parseInt(request.getOrDefault("durationMs", "1000").toString());

        log.debug("开始长时间运行操作: {}, 持续时间: {}ms", requestId, durationMs);
        Thread.currentThread().isVirtual();

        return Mono.fromCallable(() -> {
            // 模拟长时间运行的操作
            Thread.sleep(durationMs);
            return Map.<String, Object>of(
                    "requestId", requestId,
                    "durationMs", durationMs,
                    "threadName", Thread.currentThread().getName(),
                    "isVirtual", Thread.currentThread().isVirtual(),
                    "completed", true);
        })
                .subscribeOn(Schedulers.fromExecutor(virtualThreadExecutor))
                .doOnSuccess(result -> log.debug("完成长时间运行操作: {}", requestId));
    }

    /**
     * 长时间运行的操作（使用传统线程）
     * 
     * @param request 请求参数
     * @return 操作结果
     */
    @PostMapping("/long-running-traditional")
    @Timed(value = "test.long.running.traditional", description = "Time taken for long running operation with traditional threads")
    public Mono<Map<String, Object>> longRunningOperationTraditional(@RequestBody Map<String, Object> request) {
        String requestId = request.getOrDefault("requestId", UUID.randomUUID().toString()).toString();
        int durationMs = Integer.parseInt(request.getOrDefault("durationMs", "1000").toString());

        log.debug("开始长时间运行操作(传统线程): {}, 持续时间: {}ms", requestId, durationMs);

        return Mono.fromCallable(() -> {
            // 模拟长时间运行的操作
            Thread.sleep(durationMs);
            return Map.<String, Object>of(
                    "requestId", requestId,
                    "durationMs", durationMs,
                    "threadName", Thread.currentThread().getName(),
                    "isVirtual", Thread.currentThread().isVirtual(),
                    "completed", true);
        })
                .subscribeOn(Schedulers.fromExecutor(traditionalThreadExecutor))
                .doOnSuccess(result -> log.debug("完成长时间运行操作(传统线程): {}", requestId));
    }

    /**
     * 内存占用测试
     * 
     * @param request 请求参数
     * @return 内存使用情况
     */
    @PostMapping("/memory-usage")
    @Timed(value = "test.memory.usage", description = "Memory usage test")
    public Mono<Map<String, Object>> memoryUsageTest(@RequestBody Map<String, Object> request) {
        int threadCount = Integer.parseInt(request.getOrDefault("threadCount", "1000").toString());

        log.debug("开始内存占用测试，线程数: {}", threadCount);

        // 获取当前内存使用情况
        Runtime runtime = Runtime.getRuntime();
        long beforeMemory = runtime.totalMemory() - runtime.freeMemory();

        // 创建大量线程并等待它们完成
        return Mono.fromCallable(() -> {
            Thread[] threads = new Thread[threadCount];
            for (int i = 0; i < threadCount; i++) {
                final int index = i;
                threads[i] = Thread.ofVirtual().name("virtual-" + i).start(() -> {
                    try {
                        // 每个线程睡眠一段随机时间
                        Thread.sleep(100 + (index % 10) * 100);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                });
            }

            // 等待所有线程完成
            for (Thread thread : threads) {
                thread.join();
            }

            // 获取测试后内存使用情况
            long afterMemory = runtime.totalMemory() - runtime.freeMemory();

            return Map.<String, Object>of(
                    "threadCount", threadCount,
                    "beforeMemoryMB", beforeMemory / (1024 * 1024),
                    "afterMemoryMB", afterMemory / (1024 * 1024),
                    "diffMemoryMB", (afterMemory - beforeMemory) / (1024 * 1024),
                    "memoryPerThreadKB", threadCount > 0 ? (afterMemory - beforeMemory) / threadCount / 1024 : 0);
        })
                .subscribeOn(Schedulers.boundedElastic())
                .doOnSuccess(result -> log.debug("完成内存占用测试，线程数: {}", threadCount));
    }

    /**
     * 测试端点，返回当前时间和服务器状态
     * @return 服务器状态信息
     */
    @GetMapping("/ping")
    public Mono<ResponseEntity<Map<String, Object>>> ping() {
        logger.info("收到测试请求: /api/v1/test/ping");
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "API服务器正常运行");
        response.put("timestamp", LocalDateTime.now().toString());
        response.put("environment", "test");
        
        return Mono.just(ResponseEntity.ok(response));
    }
    
    /**
     * 测试认证端点，用于验证安全配置
     * @return 认证状态信息
     */
    @GetMapping("/auth-test")
    public Mono<ResponseEntity<Map<String, Object>>> authTest() {
        logger.info("收到认证测试请求: /api/v1/test/auth-test");
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "success");
        response.put("message", "认证测试成功，请求已到达受保护的控制器");
        response.put("timestamp", LocalDateTime.now().toString());
        response.put("authenticated", true);
        
        return Mono.just(ResponseEntity.ok(response));
    }
}
