package com.ainovel.server.performance.simulation;

import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

import java.time.Duration;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.function.Supplier;

import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;

/**
 * AI服务性能测试模拟类
 */
public class AIServiceSimulation extends Simulation {
    
    // 测试配置
    private static final int USERS_LOW = 10;
    private static final int USERS_MEDIUM = 50;
    private static final int USERS_HIGH = 100;
    private static final Duration RAMP_DURATION = Duration.ofSeconds(10);
    private static final Duration TEST_DURATION = Duration.ofMinutes(2);
    
    // HTTP配置
    private final HttpProtocolBuilder httpProtocol = http
            .baseUrl("http://localhost:8080/api")
            .acceptHeader("application/json")
            .contentTypeHeader("application/json")
            .userAgentHeader("Gatling/Performance-Test");
    
    // 随机生成器
    private final Random random = new Random();
    
    // 模型列表
    private final String[] models = {
            "gpt-3.5-turbo", 
            "gpt-4", 
            "claude-3-opus", 
            "claude-3-sonnet", 
            "llama-3-70b"
    };
    
    // 随机提示列表
    private final String[] prompts = {
            "写一个关于太空探索的故事",
            "描述一个未来的城市",
            "创建一个奇幻世界的设定",
            "写一个侦探小说的开头",
            "描述一个科幻故事中的外星生物",
            "写一个历史小说的场景",
            "创建一个超级英雄的背景故事",
            "描述一个后启示录世界的生存状况",
            "写一个浪漫故事的关键场景",
            "创建一个恐怖故事的氛围描写"
    };
    
    // 随机生成AI请求
    private final Supplier<String> randomAIRequest = () -> {
        String model = models[random.nextInt(models.length)];
        String prompt = prompts[random.nextInt(prompts.length)];
        int maxTokens = 500 + random.nextInt(1500);
        double temperature = 0.5 + random.nextDouble();
        
        return String.format("""
                {
                  "model": "%s",
                  "prompt": "%s",
                  "maxTokens": %d,
                  "temperature": %.2f,
                  "enableContext": %b,
                  "novelId": "%s"
                }
                """, 
                model, prompt, maxTokens, temperature, 
                random.nextBoolean(), UUID.randomUUID().toString());
    };
    
    // 获取模型列表场景
    private final ScenarioBuilder getModelsScenario = scenario("获取AI模型列表")
            .exec(http("获取可用模型")
                    .get("/ai/models")
                    .check(status().is(200))
                    .check(jsonPath("$").exists()));
    
    // 生成内容场景
    private final ScenarioBuilder generateContentScenario = scenario("生成AI内容")
            .exec(session -> session.set("request", randomAIRequest.get()))
            .exec(http("生成内容请求")
                    .post("/ai/generate")
                    .body(StringBody("#{request}"))
                    .check(status().is(200))
                    .check(jsonPath("$.content").exists())
                    .check(jsonPath("$.tokenUsage").exists()));
    
    // 流式生成内容场景
    private final ScenarioBuilder streamContentScenario = scenario("流式生成AI内容")
            .exec(session -> session.set("request", randomAIRequest.get()))
            .exec(http("流式生成内容请求")
                    .post("/ai/generate/stream")
                    .body(StringBody("#{request}"))
                    .check(status().is(200)));
    
    // 混合场景
    private final ScenarioBuilder mixedScenario = scenario("混合AI请求")
            .randomSwitch()
                .on(
                    Choice.withWeight(10, exec(getModelsScenario)),
                    Choice.withWeight(60, exec(generateContentScenario)),
                    Choice.withWeight(30, exec(streamContentScenario))
                );
    
    // 低负载测试
    private final ScenarioBuilder lowLoadTest = scenario("低负载测试")
            .exec(mixedScenario);
    
    // 中负载测试
    private final ScenarioBuilder mediumLoadTest = scenario("中负载测试")
            .exec(mixedScenario);
    
    // 高负载测试
    private final ScenarioBuilder highLoadTest = scenario("高负载测试")
            .exec(mixedScenario);
    
    {
        setUp(
            lowLoadTest.injectOpen(
                rampUsers(USERS_LOW).during(RAMP_DURATION),
                constantUsersPerSec(USERS_LOW).during(TEST_DURATION)
            ).protocols(httpProtocol),
            
            mediumLoadTest.injectOpen(
                nothingFor(Duration.ofSeconds(30)),
                rampUsers(USERS_MEDIUM).during(RAMP_DURATION),
                constantUsersPerSec(USERS_MEDIUM).during(TEST_DURATION)
            ).protocols(httpProtocol),
            
            highLoadTest.injectOpen(
                nothingFor(Duration.ofSeconds(90)),
                rampUsers(USERS_HIGH).during(RAMP_DURATION),
                constantUsersPerSec(USERS_HIGH).during(TEST_DURATION)
            ).protocols(httpProtocol)
        ).assertions(
            global().responseTime().percentile3().lt(1000),
            global().successfulRequests().percent().gt(95)
        );
    }
} 