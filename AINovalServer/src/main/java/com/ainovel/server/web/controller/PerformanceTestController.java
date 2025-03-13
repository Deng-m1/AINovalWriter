package com.ainovel.server.web.controller;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.common.util.MockDataGenerator;
import com.ainovel.server.common.util.PerformanceTestUtil;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.repository.NovelRepository;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.web.base.ReactiveBaseController;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 性能测试控制器，提供数据生成和性能测试的API端点
 */
@RestController
@RequestMapping("/performance-test")
public class PerformanceTestController extends ReactiveBaseController {

    private final NovelRepository novelRepository;
    private final SceneRepository sceneRepository;
    private final NovelService novelService;

    @Autowired
    public PerformanceTestController(NovelRepository novelRepository,
            SceneRepository sceneRepository,
            NovelService novelService) {
        this.novelRepository = novelRepository;
        this.sceneRepository = sceneRepository;
        this.novelService = novelService;
    }

    /**
     * 生成测试数据并存入MongoDB
     * 
     * @param count 要生成的小说数量
     * @return 生成结果
     */
    @PostMapping("/generate-data")
    public Mono<Map<String, Object>> generateTestData(@RequestParam(defaultValue = "10") int count) {
        return Mono.fromCallable(() -> MockDataGenerator.generateNovels(count))
                .flatMap(novels -> {
                    Flux<Novel> savedNovels = PerformanceTestUtil.measureThroughput(
                            Flux.fromIterable(novels),
                            novelRepository::save,
                            "保存小说",
                            10);

                    return savedNovels.collectList();
                })
                .map(savedNovels -> {
                    Map<String, Object> result = new HashMap<>();
                    result.put("success", true);
                    result.put("message", "成功生成并保存 " + savedNovels.size() + " 部小说");
                    result.put("novelCount", savedNovels.size());

                    // 计算场景和角色总数
                    int sceneCount = count * 5; // 假设每部小说平均5个场景
                    int characterCount = count * 3; // 假设每部小说平均3个角色

                    result.put("sceneCount", sceneCount);
                    result.put("characterCount", characterCount);

                    return result;
                });
    }

    /**
     * 清除所有测试数据
     * 
     * @return 清除结果
     */
    @DeleteMapping("/clear-data")
    public Mono<Map<String, Object>> clearTestData() {
        return novelRepository.deleteAll()
                .then(sceneRepository.deleteAll())
                .then(Mono.just(Map.of(
                        "success", true,
                        "message", "所有测试数据已清除")));
    }

    /**
     * 执行小说查询性能测试
     * 
     * @param concurrentUsers 并发用户数
     * @param requestsPerUser 每个用户的请求数
     * @return 测试结果
     */
    @GetMapping("/novel-query-test")
    public Mono<Map<String, Object>> testNovelQuery(
            @RequestParam(defaultValue = "50") int concurrentUsers,
            @RequestParam(defaultValue = "10") int requestsPerUser) {

        Instant start = Instant.now();

        return novelRepository.findAll().collectList()
                .flatMap(novels -> {
                    if (novels.isEmpty()) {
                        return Mono.just(Map.of(
                                "success", false,
                                "message", "没有可用的测试数据，请先生成测试数据"));
                    }

                    List<String> novelIds = novels.stream()
                            .map(Novel::getId)
                            .collect(Collectors.toList());

                    return PerformanceTestUtil.performLoadTest(
                            requestNum -> {
                                // 随机选择一个小说ID
                                String novelId = novelIds.get(requestNum % novelIds.size());
                                return novelService.findNovelById(novelId);
                            },
                            "小说查询测试",
                            concurrentUsers,
                            requestsPerUser)
                            .collectList()
                            .map(results -> {
                                Duration totalDuration = Duration.between(start, Instant.now());
                                double requestsPerSecond = results.size() / (totalDuration.toMillis() / 1000.0);

                                Map<String, Object> result = new HashMap<>();
                                result.put("success", true);
                                result.put("message", "小说查询性能测试完成");
                                result.put("totalRequests", concurrentUsers * requestsPerUser);
                                result.put("successfulRequests", results.size());
                                result.put("totalTimeMs", totalDuration.toMillis());
                                result.put("requestsPerSecond", String.format("%.2f", requestsPerSecond));

                                return result;
                            });
                });
    }

    /**
     * 执行场景查询性能测试
     * 
     * @param concurrentUsers 并发用户数
     * @param requestsPerUser 每个用户的请求数
     * @return 测试结果
     */
    @GetMapping("/scene-query-test")
    public Mono<Map<String, Object>> testSceneQuery(
            @RequestParam(defaultValue = "50") int concurrentUsers,
            @RequestParam(defaultValue = "10") int requestsPerUser) {

        Instant start = Instant.now();

        return sceneRepository.findAll().collectList()
                .flatMap(scenes -> {
                    if (scenes.isEmpty()) {
                        return Mono.just(Map.of(
                                "success", false,
                                "message", "没有可用的测试数据，请先生成测试数据"));
                    }

                    List<String> sceneIds = scenes.stream()
                            .map(Scene::getId)
                            .collect(Collectors.toList());

                    return PerformanceTestUtil.performLoadTest(
                            requestNum -> {
                                // 随机选择一个场景ID
                                String sceneId = sceneIds.get(requestNum % sceneIds.size());
                                return sceneRepository.findById(sceneId);
                            },
                            "场景查询测试",
                            concurrentUsers,
                            requestsPerUser)
                            .collectList()
                            .map(results -> {
                                Duration totalDuration = Duration.between(start, Instant.now());
                                double requestsPerSecond = results.size() / (totalDuration.toMillis() / 1000.0);

                                Map<String, Object> result = new HashMap<>();
                                result.put("success", true);
                                result.put("message", "场景查询性能测试完成");
                                result.put("totalRequests", concurrentUsers * requestsPerUser);
                                result.put("successfulRequests", results.size());
                                result.put("totalTimeMs", totalDuration.toMillis());
                                result.put("requestsPerSecond", String.format("%.2f", requestsPerSecond));

                                return result;
                            });
                });
    }

    /**
     * 执行小说创建性能测试
     * 
     * @param concurrentUsers 并发用户数
     * @param requestsPerUser 每个用户的请求数
     * @return 测试结果
     */
    @PostMapping("/novel-create-test")
    public Mono<Map<String, Object>> testNovelCreate(
            @RequestParam(defaultValue = "20") int concurrentUsers,
            @RequestParam(defaultValue = "5") int requestsPerUser) {

        Instant start = Instant.now();

        return PerformanceTestUtil.performLoadTest(
                requestNum -> {
                    Novel novel = MockDataGenerator.generateNovel();
                    novel.setTitle(novel.getTitle() + "-" + requestNum); // 确保标题唯一
                    return novelRepository.save(novel);
                },
                "小说创建测试",
                concurrentUsers,
                requestsPerUser)
                .collectList()
                .map(results -> {
                    Duration totalDuration = Duration.between(start, Instant.now());
                    double requestsPerSecond = results.size() / (totalDuration.toMillis() / 1000.0);

                    Map<String, Object> result = new HashMap<>();
                    result.put("success", true);
                    result.put("message", "小说创建性能测试完成");
                    result.put("totalRequests", concurrentUsers * requestsPerUser);
                    result.put("successfulRequests", results.size());
                    result.put("totalTimeMs", totalDuration.toMillis());
                    result.put("requestsPerSecond", String.format("%.2f", requestsPerSecond));

                    return result;
                });
    }

    /**
     * 获取数据库统计信息
     * 
     * @return 统计信息
     */
    @GetMapping("/stats")
    public Mono<Map<String, Object>> getDatabaseStats() {
        Mono<Long> novelCount = novelRepository.count();
        Mono<Long> sceneCount = sceneRepository.count();

        return Mono.zip(novelCount, sceneCount)
                .map(tuple -> {
                    Map<String, Object> stats = new HashMap<>();
                    stats.put("novelCount", tuple.getT1());
                    stats.put("sceneCount", tuple.getT2());
                    return stats;
                });
    }

    /**
     * 获取服务器状态信息
     * 
     * @return 服务器状态
     */
    @GetMapping("/server-status")
    public Mono<Map<String, Object>> getServerStatus() {
        Map<String, Object> status = new HashMap<>();

        // 系统信息
        Runtime runtime = Runtime.getRuntime();
        long maxMemory = runtime.maxMemory() / (1024 * 1024);
        long totalMemory = runtime.totalMemory() / (1024 * 1024);
        long freeMemory = runtime.freeMemory() / (1024 * 1024);
        long usedMemory = totalMemory - freeMemory;

        status.put("availableProcessors", runtime.availableProcessors());
        status.put("maxMemoryMB", maxMemory);
        status.put("totalMemoryMB", totalMemory);
        status.put("usedMemoryMB", usedMemory);
        status.put("freeMemoryMB", freeMemory);

        // JVM信息
        status.put("javaVersion", System.getProperty("java.version"));
        status.put("javaVendor", System.getProperty("java.vendor"));

        // 操作系统信息
        status.put("osName", System.getProperty("os.name"));
        status.put("osVersion", System.getProperty("os.version"));
        status.put("osArch", System.getProperty("os.arch"));

        return Mono.just(status);
    }

    /**
     * 获取服务器实时监控数据
     */
    @GetMapping(value = "/monitor", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<Map<String, Object>> monitorServerStatus() {
        return Flux.interval(Duration.ofSeconds(1))
                .map(tick -> {
                    Map<String, Object> status = new HashMap<>();

                    Runtime runtime = Runtime.getRuntime();
                    long totalMemory = runtime.totalMemory() / (1024 * 1024);
                    long freeMemory = runtime.freeMemory() / (1024 * 1024);
                    long usedMemory = totalMemory - freeMemory;

                    status.put("timestamp", System.currentTimeMillis());
                    status.put("usedMemoryMB", usedMemory);
                    status.put("freeMemoryMB", freeMemory);
                    status.put("availableProcessors", runtime.availableProcessors());

                    return status;
                });
    }
}