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
 * 小说服务性能测试模拟类
 */
public class NovelServiceSimulation extends Simulation {
    
    // 测试配置
    private static final int USERS_LOW = 20;
    private static final int USERS_MEDIUM = 100;
    private static final int USERS_HIGH = 200;
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
    
    // 随机生成小说请求
    private final Supplier<String> randomNovelRequest = () -> {
        String title = "测试小说 " + UUID.randomUUID().toString().substring(0, 8);
        String description = "这是一个用于性能测试的小说，包含随机生成的内容。";
        
        return String.format("""
                {
                  "title": "%s",
                  "description": "%s",
                  "author": {
                    "id": "user123",
                    "username": "testuser"
                  },
                  "genre": ["科幻", "奇幻"],
                  "tags": ["测试", "性能测试"],
                  "status": "draft"
                }
                """, title, description);
    };
    
    // 创建小说场景
    private final ScenarioBuilder createNovelScenario = scenario("创建小说")
            .exec(session -> session.set("novelRequest", randomNovelRequest.get()))
            .exec(http("创建小说请求")
                    .post("/novels")
                    .body(StringBody("#{novelRequest}"))
                    .check(status().is(201))
                    .check(jsonPath("$.id").saveAs("novelId")));
    
    // 获取小说详情场景
    private final ScenarioBuilder getNovelScenario = scenario("获取小说详情")
            .exec(createNovelScenario)
            .exec(http("获取小说详情请求")
                    .get("/novels/#{novelId}")
                    .check(status().is(200))
                    .check(jsonPath("$.title").exists()));
    
    // 更新小说场景
    private final ScenarioBuilder updateNovelScenario = scenario("更新小说")
            .exec(createNovelScenario)
            .exec(session -> {
                String updatedTitle = "更新的小说 " + UUID.randomUUID().toString().substring(0, 8);
                String updatedRequest = String.format("""
                        {
                          "title": "%s",
                          "description": "这是一个更新后的小说描述",
                          "author": {
                            "id": "user123",
                            "username": "testuser"
                          },
                          "genre": ["科幻", "奇幻", "冒险"],
                          "tags": ["测试", "性能测试", "已更新"],
                          "status": "in_progress"
                        }
                        """, updatedTitle);
                return session.set("updatedNovelRequest", updatedRequest);
            })
            .exec(http("更新小说请求")
                    .put("/novels/#{novelId}")
                    .body(StringBody("#{updatedNovelRequest}"))
                    .check(status().is(200))
                    .check(jsonPath("$.title").exists()));
    
    // 搜索小说场景
    private final ScenarioBuilder searchNovelScenario = scenario("搜索小说")
            .exec(http("搜索小说请求")
                    .get("/novels/search?title=小说")
                    .check(status().is(200)));
    
    // 获取作者小说场景
    private final ScenarioBuilder getAuthorNovelsScenario = scenario("获取作者小说")
            .exec(http("获取作者小说请求")
                    .get("/novels/author/user123")
                    .check(status().is(200)));
    
    // 删除小说场景
    private final ScenarioBuilder deleteNovelScenario = scenario("删除小说")
            .exec(createNovelScenario)
            .exec(http("删除小说请求")
                    .delete("/novels/#{novelId}")
                    .check(status().is(204)));
    
    // 混合场景
    private final ScenarioBuilder mixedScenario = scenario("混合小说请求")
            .randomSwitch()
                .on(
                    Choice.withWeight(30, exec(createNovelScenario)),
                    Choice.withWeight(25, exec(getNovelScenario)),
                    Choice.withWeight(20, exec(updateNovelScenario)),
                    Choice.withWeight(10, exec(searchNovelScenario)),
                    Choice.withWeight(10, exec(getAuthorNovelsScenario)),
                    Choice.withWeight(5, exec(deleteNovelScenario))
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
            global().responseTime().percentile3().lt(500),
            global().successfulRequests().percent().gt(95)
        );
    }
} 