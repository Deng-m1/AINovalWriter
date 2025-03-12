package com.ainovel.server.performance.simulation;

import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

import java.time.Duration;
import java.util.Random;
import java.util.UUID;
import java.util.function.Supplier;

import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;

/**
 * 虚拟线程性能测试类 (VirtualThreadPerformanceTest)
专门用于比较虚拟线程和传统线程的性能差异
执行大量并发任务，测量执行时间和内存使用
包含内存压力测试，创建大量线程以比较两种线程模型的内存效率
 */
public class VirtualThreadVsTraditionalSimulation extends Simulation {
    
    // 测试配置
    private static final int[] CONCURRENT_USERS = {100, 500, 1000, 2000, 5000};
    private static final Duration RAMP_DURATION = Duration.ofSeconds(30);
    private static final Duration TEST_DURATION = Duration.ofMinutes(2);
    
    // HTTP配置 - 虚拟线程（默认）
    private final HttpProtocolBuilder httpVirtualThread = http
            .baseUrl("http://localhost:8080/api")
            .acceptHeader("application/json")
            .contentTypeHeader("application/json")
            .userAgentHeader("Gatling/VirtualThread-Test");
    
    // HTTP配置 - 传统线程（需要在应用中配置一个不使用虚拟线程的端点）
    private final HttpProtocolBuilder httpTraditionalThread = http
            .baseUrl("http://localhost:8081/api") // 假设传统线程模式在不同端口
            .acceptHeader("application/json")
            .contentTypeHeader("application/json")
            .userAgentHeader("Gatling/TraditionalThread-Test");
    
    // 随机生成器
    private final Random random = new Random();
    
    // 长时间运行的操作请求
    private final Supplier<String> longRunningOperationRequest = () -> {
        int durationMs = 500 + random.nextInt(2000); // 500ms到2.5s之间
        return String.format("""
                {
                  "operationType": "longRunning",
                  "durationMs": %d,
                  "requestId": "%s"
                }
                """, durationMs, UUID.randomUUID().toString());
    };
    
    // 虚拟线程长时间运行操作场景
    private final ScenarioBuilder virtualThreadLongRunningScenario = scenario("虚拟线程长时间运行操作")
            .exec(session -> session.set("request", longRunningOperationRequest.get()))
            .exec(http("虚拟线程长时间运行请求")
                    .post("/test/long-running")
                    .body(StringBody("#{request}"))
                    .check(status().is(200)));
    
    // 传统线程长时间运行操作场景
    private final ScenarioBuilder traditionalThreadLongRunningScenario = scenario("传统线程长时间运行操作")
            .exec(session -> session.set("request", longRunningOperationRequest.get()))
            .exec(http("传统线程长时间运行请求")
                    .post("/test/long-running")
                    .body(StringBody("#{request}"))
                    .check(status().is(200)));
    
    // 多并发级别测试
    {
        // 创建多个并发级别的测试
        ChainBuilder[] virtualThreadSetups = new ChainBuilder[CONCURRENT_USERS.length];
        ChainBuilder[] traditionalThreadSetups = new ChainBuilder[CONCURRENT_USERS.length];
        
        for (int i = 0; i < CONCURRENT_USERS.length; i++) {
            final int userCount = CONCURRENT_USERS[i];
            final int waitSeconds = i * 60; // 每个级别间隔60秒
            
            virtualThreadSetups[i] = exec(
                nothingFor(Duration.ofSeconds(waitSeconds)),
                rampUsers(userCount).during(RAMP_DURATION),
                constantUsersPerSec(userCount).during(TEST_DURATION)
            );
            
            traditionalThreadSetups[i] = exec(
                nothingFor(Duration.ofSeconds(waitSeconds)),
                rampUsers(userCount).during(RAMP_DURATION),
                constantUsersPerSec(userCount).during(TEST_DURATION)
            );
        }
        
        setUp(
            virtualThreadLongRunningScenario
                .injectChainBuilder(virtualThreadSetups)
                .protocols(httpVirtualThread),
                
            traditionalThreadLongRunningScenario
                .injectChainBuilder(traditionalThreadSetups)
                .protocols(httpTraditionalThread)
        ).assertions(
            global().responseTime().percentile3().lt(3000),
            global().successfulRequests().percent().gt(95)
        );
    }
} 