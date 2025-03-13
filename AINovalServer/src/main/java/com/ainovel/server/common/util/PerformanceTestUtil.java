package com.ainovel.server.common.util;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;
import java.util.function.Supplier;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 性能测试工具类，用于测量操作执行时间和吞吐量
 */
public class PerformanceTestUtil {

    private static final Logger log = LoggerFactory.getLogger(PerformanceTestUtil.class);

    /**
     * 测量同步操作执行时间
     * 
     * @param operation     要测量的操作
     * @param operationName 操作名称（用于日志）
     * @return 操作结果
     */
    public static <T> T measureExecutionTime(Supplier<T> operation, String operationName) {
        Instant start = Instant.now();
        T result = operation.get();
        Duration duration = Duration.between(start, Instant.now());

        log.info("操作 [{}] 执行时间: {} ms", operationName, duration.toMillis());
        return result;
    }

    /**
     * 测量响应式操作执行时间
     * 
     * @param operation     要测量的响应式操作
     * @param operationName 操作名称（用于日志）
     * @return 包含操作结果的Mono
     */
    public static <T> Mono<T> measureReactiveDuration(Mono<T> operation, String operationName) {
        Instant start = Instant.now();
        return operation
                .doOnSuccess(result -> {
                    Duration duration = Duration.between(start, Instant.now());
                    log.info("响应式操作 [{}] 执行时间: {} ms", operationName, duration.toMillis());
                })
                .doOnError(error -> {
                    Duration duration = Duration.between(start, Instant.now());
                    log.error("响应式操作 [{}] 失败，执行时间: {} ms, 错误: {}",
                            operationName, duration.toMillis(), error.getMessage());
                });
    }

    /**
     * 测量批量操作的吞吐量
     * 
     * @param operations    要执行的操作流
     * @param processor     处理每个操作项的函数
     * @param operationName 操作名称（用于日志）
     * @param concurrency   并发数
     * @return 处理结果流
     */
    public static <T, R> Flux<R> measureThroughput(Flux<T> operations,
            Function<T, Mono<R>> processor,
            String operationName,
            int concurrency) {
        Instant start = Instant.now();
        AtomicInteger counter = new AtomicInteger(0);

        return operations
                .flatMap(item -> processor.apply(item)
                        .doOnSuccess(result -> {
                            int count = counter.incrementAndGet();
                            if (count % 100 == 0) {
                                Duration elapsed = Duration.between(start, Instant.now());
                                double itemsPerSecond = count / (elapsed.toMillis() / 1000.0);
                                log.info("操作 [{}] 已处理: {}, 吞吐量: {}/秒",
                                        operationName, count, String.format("%.2f", itemsPerSecond));
                            }
                        }), concurrency)
                .doOnComplete(() -> {
                    int totalCount = counter.get();
                    Duration totalDuration = Duration.between(start, Instant.now());
                    double overallItemsPerSecond = totalCount / (totalDuration.toMillis() / 1000.0);
                    log.info("操作 [{}] 完成. 总处理: {}, 总时间: {} ms, 平均吞吐量: {}/秒",
                            operationName, totalCount, totalDuration.toMillis(),
                            String.format("%.2f", overallItemsPerSecond));
                });
    }

    /**
     * 执行并发负载测试
     * 
     * @param operation       要测试的操作
     * @param operationName   操作名称
     * @param concurrentUsers 并发用户数
     * @param requestsPerUser 每个用户的请求数
     * @return 测试结果流
     */
    public static <T> Flux<T> performLoadTest(Function<Integer, Mono<T>> operation,
            String operationName,
            int concurrentUsers,
            int requestsPerUser) {
        Instant start = Instant.now();
        AtomicInteger successCounter = new AtomicInteger(0);
        AtomicInteger errorCounter = new AtomicInteger(0);

        log.info("开始负载测试 [{}]: {} 并发用户, 每用户 {} 请求",
                operationName, concurrentUsers, requestsPerUser);

        return Flux.range(0, concurrentUsers)
                .flatMap(userId -> Flux.range(0, requestsPerUser)
                        .flatMap(requestId -> {
                            int requestNum = userId * requestsPerUser + requestId;
                            return operation.apply(requestNum)
                                    .doOnSuccess(result -> successCounter.incrementAndGet())
                                    .doOnError(error -> errorCounter.incrementAndGet())
                                    .onErrorResume(e -> {
                                        log.error("请求 {} 失败: {}", requestNum, e.getMessage());
                                        return Mono.empty();
                                    });
                        }))
                .doOnComplete(() -> {
                    Duration totalDuration = Duration.between(start, Instant.now());
                    int totalRequests = concurrentUsers * requestsPerUser;
                    int successCount = successCounter.get();
                    int errorCount = errorCounter.get();
                    double requestsPerSecond = successCount / (totalDuration.toMillis() / 1000.0);

                    log.info("负载测试 [{}] 完成. 总请求: {}, 成功: {}, 失败: {}, 总时间: {} ms, 吞吐量: {}/秒",
                            operationName, totalRequests, successCount, errorCount,
                            totalDuration.toMillis(), String.format("%.2f", requestsPerSecond));
                });
    }
}