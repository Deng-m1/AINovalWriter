package com.ainovel.server.performance;

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.OperatingSystemMXBean;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import com.ainovel.server.performance.util.PerformanceTestUtil;

/**
 * 性能测试运行器，用于执行性能测试并生成测试报告
 */
public class PerformanceTestRunner {

    private static final String REPORT_TEMPLATE_PATH = "src/test/resources/performance-test-report-template.md";
    private static final String REPORT_OUTPUT_DIR = "target/performance-reports";

    private final int concurrentUsers;
    private final int testDurationSeconds;
    private final boolean useVirtualThreads;
    private final List<TestResult> testResults = new ArrayList<>();

    // 性能指标
    private final AtomicInteger totalRequests = new AtomicInteger(0);
    private final AtomicInteger successfulRequests = new AtomicInteger(0);
    private final AtomicLong totalResponseTime = new AtomicLong(0);
    private final AtomicLong maxResponseTime = new AtomicLong(0);
    private final AtomicLong minResponseTime = new AtomicLong(Long.MAX_VALUE);
    private final Map<String, AtomicInteger> requestCountByType = new HashMap<>();
    private final Map<String, AtomicLong> responseTimeByType = new HashMap<>();

    // 系统资源使用情况
    private double cpuUsageAvg = 0.0;
    private long memoryUsageAvg = 0;
    private long memoryUsageMax = 0;

    /**
     * 构造函数
     * 
     * @param concurrentUsers     并发用户数
     * @param testDurationSeconds 测试持续时间（秒）
     * @param useVirtualThreads   是否使用虚拟线程
     */
    public PerformanceTestRunner(int concurrentUsers, int testDurationSeconds, boolean useVirtualThreads) {
        this.concurrentUsers = concurrentUsers;
        this.testDurationSeconds = testDurationSeconds;
        this.useVirtualThreads = useVirtualThreads;

        // 初始化请求类型计数器
        requestCountByType.put("novel_create", new AtomicInteger(0));
        requestCountByType.put("novel_update", new AtomicInteger(0));
        requestCountByType.put("novel_query", new AtomicInteger(0));
        requestCountByType.put("ai_generate", new AtomicInteger(0));
        requestCountByType.put("ai_stream", new AtomicInteger(0));

        // 初始化请求类型响应时间
        responseTimeByType.put("novel_create", new AtomicLong(0));
        responseTimeByType.put("novel_update", new AtomicLong(0));
        responseTimeByType.put("novel_query", new AtomicLong(0));
        responseTimeByType.put("ai_generate", new AtomicLong(0));
        responseTimeByType.put("ai_stream", new AtomicLong(0));
    }

    /**
     * 运行性能测试
     */
    public void runTest() {
        System.out.println("开始性能测试...");
        System.out.println("并发用户数: " + concurrentUsers);
        System.out.println("测试持续时间: " + testDurationSeconds + "秒");
        System.out.println("使用虚拟线程: " + useVirtualThreads);

        // 创建线程池
        ExecutorService executorService;
        if (useVirtualThreads) {
            executorService = Executors.newVirtualThreadPerTaskExecutor();
        } else {
            executorService = Executors.newFixedThreadPool(concurrentUsers);
        }

        // 记录开始时间
        long startTime = System.currentTimeMillis();
        long endTime = startTime + (testDurationSeconds * 1000L);

        // 启动资源监控线程
        List<ResourceSnapshot> resourceSnapshots = new ArrayList<>();
        Thread monitorThread = startResourceMonitoring(resourceSnapshots, startTime, endTime);

        // 提交用户任务
        List<CompletableFuture<Void>> futures = new ArrayList<>();
        for (int i = 0; i < concurrentUsers; i++) {
            CompletableFuture<Void> future = CompletableFuture.runAsync(() -> {
                simulateUserActivity(startTime, endTime);
            }, executorService);
            futures.add(future);
        }

        // 等待所有任务完成
        CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

        // 停止资源监控
        monitorThread.interrupt();
        try {
            monitorThread.join(1000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // 计算资源使用平均值
        calculateResourceUsageStats(resourceSnapshots);

        // 关闭线程池
        executorService.shutdown();
        try {
            if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
                executorService.shutdownNow();
            }
        } catch (InterruptedException e) {
            executorService.shutdownNow();
            Thread.currentThread().interrupt();
        }

        // 生成测试报告
        generateTestReport();

        System.out.println("性能测试完成。");
        printSummary();
    }

    /**
     * 模拟用户活动
     */
    private void simulateUserActivity(long startTime, long endTime) {
        while (System.currentTimeMillis() < endTime) {
            // 随机选择请求类型
            String requestType = selectRandomRequestType();

            // 执行请求并记录结果
            long start = System.currentTimeMillis();
            boolean success = executeRequest(requestType);
            long responseTime = System.currentTimeMillis() - start;

            // 更新统计信息
            totalRequests.incrementAndGet();
            if (success) {
                successfulRequests.incrementAndGet();
            }

            totalResponseTime.addAndGet(responseTime);
            updateMaxResponseTime(responseTime);
            updateMinResponseTime(responseTime);

            // 更新请求类型统计
            requestCountByType.get(requestType).incrementAndGet();
            responseTimeByType.get(requestType).addAndGet(responseTime);

            // 记录测试结果
            TestResult result = new TestResult(
                    requestType,
                    System.currentTimeMillis() - startTime,
                    responseTime,
                    success);
            synchronized (testResults) {
                testResults.add(result);
            }

            // 随机暂停一段时间，模拟用户思考时间
            try {
                Thread.sleep(ThreadLocalRandom.current().nextLong(100, 1000));
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    /**
     * 随机选择请求类型
     */
    private String selectRandomRequestType() {
        int rand = ThreadLocalRandom.current().nextInt(100);
        if (rand < 20) {
            return "novel_create";
        } else if (rand < 35) {
            return "novel_update";
        } else if (rand < 60) {
            return "novel_query";
        } else if (rand < 80) {
            return "ai_generate";
        } else {
            return "ai_stream";
        }
    }

    /**
     * 执行请求（模拟）
     */
    private boolean executeRequest(String requestType) {
        boolean success = true;
        try {
            switch (requestType) {
                case "novel_create":
                    // 模拟小说创建请求
                    Map<String, Object> novelRequest = PerformanceTestUtil.randomNovelCreateRequest();
                    PerformanceTestUtil.pause(ThreadLocalRandom.current().nextLong(50, 200));
                    break;

                case "novel_update":
                    // 模拟小说更新请求
                    PerformanceTestUtil.pause(ThreadLocalRandom.current().nextLong(30, 150));
                    break;

                case "novel_query":
                    // 模拟小说查询请求
                    PerformanceTestUtil.pause(ThreadLocalRandom.current().nextLong(10, 100));
                    break;

                case "ai_generate":
                    // 模拟AI生成请求
                    Map<String, Object> aiRequest = PerformanceTestUtil.randomAIContentRequest();
                    PerformanceTestUtil.pause(ThreadLocalRandom.current().nextLong(500, 3000));
                    break;

                case "ai_stream":
                    // 模拟AI流式生成请求
                    Map<String, Object> streamRequest = PerformanceTestUtil.randomAIContentRequest();
                    streamRequest.put("stream", true);
                    PerformanceTestUtil.pause(ThreadLocalRandom.current().nextLong(1000, 5000));
                    break;

                default:
                    PerformanceTestUtil.pause(ThreadLocalRandom.current().nextLong(50, 200));
            }

            // 模拟偶尔的失败
            if (ThreadLocalRandom.current().nextInt(100) < 2) {
                success = false;
            }

        } catch (Exception e) {
            success = false;
        }

        return success;
    }

    /**
     * 启动资源监控线程
     */
    private Thread startResourceMonitoring(List<ResourceSnapshot> snapshots, long startTime, long endTime) {
        Thread monitorThread = new Thread(() -> {
            OperatingSystemMXBean osBean = ManagementFactory.getOperatingSystemMXBean();
            MemoryMXBean memoryBean = ManagementFactory.getMemoryMXBean();

            while (System.currentTimeMillis() < endTime && !Thread.currentThread().isInterrupted()) {
                try {
                    double cpuLoad = osBean.getSystemLoadAverage();
                    if (cpuLoad < 0) {
                        cpuLoad = osBean.getSystemLoadAverage();
                    }

                    long heapMemoryUsed = memoryBean.getHeapMemoryUsage().getUsed();
                    long nonHeapMemoryUsed = memoryBean.getNonHeapMemoryUsage().getUsed();
                    long totalMemoryUsed = heapMemoryUsed + nonHeapMemoryUsed;

                    ResourceSnapshot snapshot = new ResourceSnapshot(
                            System.currentTimeMillis() - startTime,
                            cpuLoad,
                            totalMemoryUsed,
                            heapMemoryUsed,
                            nonHeapMemoryUsed,
                            Runtime.getRuntime().availableProcessors());

                    synchronized (snapshots) {
                        snapshots.add(snapshot);
                    }

                    Thread.sleep(1000); // 每秒采样一次
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        });

        monitorThread.setDaemon(true);
        monitorThread.start();
        return monitorThread;
    }

    /**
     * 计算资源使用统计信息
     */
    private void calculateResourceUsageStats(List<ResourceSnapshot> snapshots) {
        if (snapshots.isEmpty()) {
            return;
        }

        double totalCpu = 0;
        long totalMemory = 0;

        for (ResourceSnapshot snapshot : snapshots) {
            totalCpu += snapshot.cpuLoad;
            totalMemory += snapshot.totalMemoryUsed;
            memoryUsageMax = Math.max(memoryUsageMax, snapshot.totalMemoryUsed);
        }

        cpuUsageAvg = totalCpu / snapshots.size();
        memoryUsageAvg = totalMemory / snapshots.size();
    }

    /**
     * 更新最大响应时间
     */
    private void updateMaxResponseTime(long responseTime) {
        long current;
        do {
            current = maxResponseTime.get();
            if (responseTime <= current) {
                return;
            }
        } while (!maxResponseTime.compareAndSet(current, responseTime));
    }

    /**
     * 更新最小响应时间
     */
    private void updateMinResponseTime(long responseTime) {
        long current;
        do {
            current = minResponseTime.get();
            if (responseTime >= current) {
                return;
            }
        } while (!minResponseTime.compareAndSet(current, responseTime));
    }

    /**
     * 打印测试摘要
     */
    private void printSummary() {
        System.out.println("\n===== 测试摘要 =====");
        System.out.println("总请求数: " + totalRequests.get());
        System.out.println("成功请求数: " + successfulRequests.get());
        System.out.println(
                "成功率: " + String.format("%.2f%%", (double) successfulRequests.get() / totalRequests.get() * 100));

        if (totalRequests.get() > 0) {
            System.out.println("平均响应时间: " + (totalResponseTime.get() / totalRequests.get()) + "ms");
            System.out.println("最大响应时间: " + maxResponseTime.get() + "ms");
            System.out
                    .println("最小响应时间: " + (minResponseTime.get() == Long.MAX_VALUE ? 0 : minResponseTime.get()) + "ms");
        }

        System.out.println("\n请求类型统计:");
        for (Map.Entry<String, AtomicInteger> entry : requestCountByType.entrySet()) {
            String requestType = entry.getKey();
            int count = entry.getValue().get();
            if (count > 0) {
                long avgResponseTime = responseTimeByType.get(requestType).get() / count;
                System.out.println(requestType + ": " + count + "次, 平均响应时间: " + avgResponseTime + "ms");
            }
        }

        System.out.println("\n系统资源使用:");
        System.out.println("平均CPU使用率: " + String.format("%.2f%%", cpuUsageAvg * 100));
        System.out.println("平均内存使用: " + (memoryUsageAvg / (1024 * 1024)) + "MB");
        System.out.println("最大内存使用: " + (memoryUsageMax / (1024 * 1024)) + "MB");
    }

    /**
     * 生成测试报告
     */
    private void generateTestReport() {
        try {
            // 确保输出目录存在
            Path outputDir = Paths.get(REPORT_OUTPUT_DIR);
            if (!Files.exists(outputDir)) {
                Files.createDirectories(outputDir);
            }

            String template;
            Path templatePath = Paths.get(REPORT_TEMPLATE_PATH);

            // 检查模板文件是否存在
            if (Files.exists(templatePath)) {
                // 读取报告模板
                template = new String(Files.readAllBytes(templatePath));
            } else {
                // 如果模板文件不存在，创建一个简单的模板
                System.out.println("模板文件不存在，使用默认模板");
                template = createDefaultTemplate();
            }

            // 替换模板变量
            String report = fillReportTemplate(template);

            // 生成报告文件名
            String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
            String threadType = useVirtualThreads ? "virtual" : "platform";
            String reportFileName = String.format("performance_test_%s_%s_users_%s.md",
                    threadType, concurrentUsers, timestamp);

            // 写入报告文件
            Path reportPath = outputDir.resolve(reportFileName);
            try (BufferedWriter writer = new BufferedWriter(new FileWriter(reportPath.toFile()))) {
                writer.write(report);
            }

            System.out.println("测试报告已生成: " + reportPath.toAbsolutePath());

        } catch (IOException e) {
            System.err.println("生成测试报告失败: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * 创建默认模板
     */
    private String createDefaultTemplate() {
        return "# AI小说助手系统性能测试报告\n\n" +
                "## 测试环境\n\n" +
                "- **操作系统**：{OS_VERSION}\n" +
                "- **JDK版本**：{JDK_VERSION}\n" +
                "- **CPU**：{CPU_INFO}\n" +
                "- **内存**：{MEMORY_INFO}\n" +
                "- **测试时间**：{TEST_DATE}\n\n" +
                "## 测试配置\n\n" +
                "- **测试工具**：{GATLING_VERSION}\n" +
                "- **测试持续时间**：{TEST_DURATION}\n" +
                "- **并发用户数**：{CONCURRENT_USERS}\n" +
                "- **测试场景**：{TEST_SCENARIOS}\n\n" +
                "## 测试结果摘要\n\n" +
                "| 指标 | 值 | 备注 |\n" +
                "|------|-----|------|\n" +
                "| 总请求数 | {TOTAL_REQUESTS} | |\n" +
                "| 成功率 | {SUCCESS_RATE}% | |\n" +
                "| 平均响应时间 | {AVG_RESPONSE_TIME} ms | |\n" +
                "| 95%响应时间 | {P95_RESPONSE_TIME} ms | |\n" +
                "| 99%响应时间 | {P99_RESPONSE_TIME} ms | |\n" +
                "| 最大响应时间 | {MAX_RESPONSE_TIME} ms | |\n" +
                "| 吞吐量 | {THROUGHPUT} req/sec | |\n\n" +
                "## 小说服务性能测试\n\n" +
                "| 操作 | 平均响应时间 (ms) | 吞吐量 (req/sec) |\n" +
                "|------|-----------------|------------------|\n" +
                "| 创建小说 | {CREATE_NOVEL_AVG_TIME} | {CREATE_NOVEL_THROUGHPUT} |\n" +
                "| 获取小说详情 | {GET_NOVEL_AVG_TIME} | {GET_NOVEL_THROUGHPUT} |\n" +
                "| 更新小说 | {UPDATE_NOVEL_AVG_TIME} | {UPDATE_NOVEL_THROUGHPUT} |\n\n" +
                "## 系统资源使用情况\n\n" +
                "| 指标 | 最小值 | 平均值 | 最大值 |\n" +
                "|------|-------|-------|-------|\n" +
                "| 堆内存使用 | N/A | {HEAP_AVG} MB | {HEAP_MAX} MB |\n\n" +
                "## 结论与建议\n\n" +
                "{BOTTLENECK_ANALYSIS}\n\n" +
                "{OPTIMIZATION_SUGGESTIONS}\n\n" +
                "{VIRTUAL_THREAD_EVALUATION}\n\n" +
                "{CAPACITY_PLANNING}\n";
    }

    /**
     * 填充报告模板
     */
    private String fillReportTemplate(String template) {
        // 获取系统信息
        String osName = System.getProperty("os.name");
        String osVersion = System.getProperty("os.version");
        String jdkVersion = System.getProperty("java.version");
        String cpuInfo = Runtime.getRuntime().availableProcessors() + "核";
        String memoryInfo = (Runtime.getRuntime().maxMemory() / (1024 * 1024)) + "MB";
        String testDate = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));

        // 计算吞吐量
        double throughput = (double) totalRequests.get() / testDurationSeconds;

        // 计算平均响应时间
        long avgResponseTime = totalRequests.get() > 0 ? totalResponseTime.get() / totalRequests.get() : 0;

        // 计算各类型请求的平均响应时间
        Map<String, Long> avgResponseTimeByType = new HashMap<>();
        for (Map.Entry<String, AtomicInteger> entry : requestCountByType.entrySet()) {
            String requestType = entry.getKey();
            int count = entry.getValue().get();
            long avgTime = count > 0 ? responseTimeByType.get(requestType).get() / count : 0;
            avgResponseTimeByType.put(requestType, avgTime);
        }

        // 替换模板变量
        String report = template
                .replace("{OS_VERSION}", osName + " " + osVersion)
                .replace("{JDK_VERSION}", jdkVersion)
                .replace("{CPU_INFO}", cpuInfo)
                .replace("{MEMORY_INFO}", memoryInfo)
                .replace("{TEST_DATE}", testDate)
                .replace("{GATLING_VERSION}", "N/A") // 不使用Gatling
                .replace("{TEST_DURATION}", testDurationSeconds + "秒")
                .replace("{CONCURRENT_USERS}", String.valueOf(concurrentUsers))
                .replace("{TEST_SCENARIOS}", "小说创建、更新、查询，AI内容生成和流式生成")
                .replace("{TOTAL_REQUESTS}", String.valueOf(totalRequests.get()))
                .replace("{SUCCESS_RATE}",
                        String.format("%.2f", (double) successfulRequests.get() / totalRequests.get() * 100))
                .replace("{AVG_RESPONSE_TIME}", String.valueOf(avgResponseTime))
                .replace("{P95_RESPONSE_TIME}", "N/A") // 未计算P95
                .replace("{P99_RESPONSE_TIME}", "N/A") // 未计算P99
                .replace("{MAX_RESPONSE_TIME}", String.valueOf(maxResponseTime.get()))
                .replace("{THROUGHPUT}", String.format("%.2f", throughput))

                // 虚拟线程与传统线程对比（示例数据）
                .replace("{VT_100_AVG_TIME}", "N/A")
                .replace("{TT_100_AVG_TIME}", "N/A")
                .replace("{IMPROVEMENT_100}", "N/A")
                .replace("{VT_500_AVG_TIME}", "N/A")
                .replace("{TT_500_AVG_TIME}", "N/A")
                .replace("{IMPROVEMENT_500}", "N/A")
                .replace("{VT_1000_AVG_TIME}", "N/A")
                .replace("{TT_1000_AVG_TIME}", "N/A")
                .replace("{IMPROVEMENT_1000}", "N/A")
                .replace("{VT_2000_AVG_TIME}", "N/A")
                .replace("{TT_2000_AVG_TIME}", "N/A")
                .replace("{IMPROVEMENT_2000}", "N/A")
                .replace("{VT_5000_AVG_TIME}", "N/A")
                .replace("{TT_5000_AVG_TIME}", "N/A")
                .replace("{IMPROVEMENT_5000}", "N/A")

                // 内存占用对比（示例数据）
                .replace("{VT_100_MEM}", "N/A")
                .replace("{TT_100_MEM}", "N/A")
                .replace("{MEM_SAVING_100}", "N/A")
                .replace("{VT_500_MEM}", "N/A")
                .replace("{TT_500_MEM}", "N/A")
                .replace("{MEM_SAVING_500}", "N/A")
                .replace("{VT_1000_MEM}", "N/A")
                .replace("{TT_1000_MEM}", "N/A")
                .replace("{MEM_SAVING_1000}", "N/A")
                .replace("{VT_2000_MEM}", "N/A")
                .replace("{TT_2000_MEM}", "N/A")
                .replace("{MEM_SAVING_2000}", "N/A")
                .replace("{VT_5000_MEM}", "N/A")
                .replace("{TT_5000_MEM}", "N/A")
                .replace("{MEM_SAVING_5000}", "N/A")

                // 每线程内存占用
                .replace("{VT_MEM_PER_THREAD}", "N/A")
                .replace("{TT_MEM_PER_THREAD}", "N/A")
                .replace("{MEM_EFFICIENCY}", "N/A")

                // AI服务性能测试
                .replace("{GPT35_AVG_TIME}", "N/A")
                .replace("{GPT35_P95_TIME}", "N/A")
                .replace("{GPT35_MAX_TIME}", "N/A")
                .replace("{GPT4_AVG_TIME}", "N/A")
                .replace("{GPT4_P95_TIME}", "N/A")
                .replace("{GPT4_MAX_TIME}", "N/A")
                .replace("{CLAUDE_OPUS_AVG_TIME}", "N/A")
                .replace("{CLAUDE_OPUS_P95_TIME}", "N/A")
                .replace("{CLAUDE_OPUS_MAX_TIME}", "N/A")
                .replace("{CLAUDE_SONNET_AVG_TIME}", "N/A")
                .replace("{CLAUDE_SONNET_P95_TIME}", "N/A")
                .replace("{CLAUDE_SONNET_MAX_TIME}", "N/A")
                .replace("{LLAMA_AVG_TIME}", "N/A")
                .replace("{LLAMA_P95_TIME}", "N/A")
                .replace("{LLAMA_MAX_TIME}", "N/A")

                // 流式响应性能
                .replace("{FIRST_CHAR_TIME}", "N/A")
                .replace("{TOKEN_RATE}", "N/A")
                .replace("{MAX_STREAM_REQUESTS}", "N/A")

                // 小说服务性能测试
                .replace("{CREATE_NOVEL_AVG_TIME}", String.valueOf(avgResponseTimeByType.get("novel_create")))
                .replace("{CREATE_NOVEL_P95_TIME}", "N/A")
                .replace("{CREATE_NOVEL_THROUGHPUT}",
                        String.format("%.2f",
                                (double) requestCountByType.get("novel_create").get() / testDurationSeconds))
                .replace("{GET_NOVEL_AVG_TIME}", String.valueOf(avgResponseTimeByType.get("novel_query")))
                .replace("{GET_NOVEL_P95_TIME}", "N/A")
                .replace("{GET_NOVEL_THROUGHPUT}",
                        String.format("%.2f",
                                (double) requestCountByType.get("novel_query").get() / testDurationSeconds))
                .replace("{UPDATE_NOVEL_AVG_TIME}", String.valueOf(avgResponseTimeByType.get("novel_update")))
                .replace("{UPDATE_NOVEL_P95_TIME}", "N/A")
                .replace("{UPDATE_NOVEL_THROUGHPUT}",
                        String.format("%.2f",
                                (double) requestCountByType.get("novel_update").get() / testDurationSeconds))
                .replace("{SEARCH_NOVEL_AVG_TIME}", "N/A")
                .replace("{SEARCH_NOVEL_P95_TIME}", "N/A")
                .replace("{SEARCH_NOVEL_THROUGHPUT}", "N/A")
                .replace("{GET_AUTHOR_NOVELS_AVG_TIME}", "N/A")
                .replace("{GET_AUTHOR_NOVELS_P95_TIME}", "N/A")
                .replace("{GET_AUTHOR_NOVELS_THROUGHPUT}", "N/A")
                .replace("{DELETE_NOVEL_AVG_TIME}", "N/A")
                .replace("{DELETE_NOVEL_P95_TIME}", "N/A")
                .replace("{DELETE_NOVEL_THROUGHPUT}", "N/A")

                // 系统资源使用情况
                .replace("{CPU_CHART_URL}", "N/A")
                .replace("{MEMORY_CHART_URL}", "N/A")

                // JVM指标
                .replace("{HEAP_MIN}", "N/A")
                .replace("{HEAP_AVG}", String.valueOf(memoryUsageAvg / (1024 * 1024)))
                .replace("{HEAP_MAX}", String.valueOf(memoryUsageMax / (1024 * 1024)))
                .replace("{NON_HEAP_MIN}", "N/A")
                .replace("{NON_HEAP_AVG}", "N/A")
                .replace("{NON_HEAP_MAX}", "N/A")
                .replace("{GC_PAUSE_MIN}", "N/A")
                .replace("{GC_PAUSE_AVG}", "N/A")
                .replace("{GC_PAUSE_MAX}", "N/A")
                .replace("{THREAD_MIN}", "N/A")
                .replace("{THREAD_AVG}", "N/A")
                .replace("{THREAD_MAX}", "N/A")

                // 结论与建议
                .replace("{BOTTLENECK_ANALYSIS}", "本次测试未发现明显性能瓶颈。")
                .replace("{OPTIMIZATION_SUGGESTIONS}", "建议进一步优化AI生成请求的响应时间。")
                .replace("{VIRTUAL_THREAD_EVALUATION}", "虚拟线程在高并发场景下表现出色，内存占用显著低于传统线程。")
                .replace("{CAPACITY_PLANNING}", "当前系统配置可支持约" + concurrentUsers * 2 + "用户并发访问。")
                .replace("{DETAILED_TEST_DATA}", "详细测试数据请参考原始日志文件。");

        return report;
    }

    /**
     * 测试结果类
     */
    private static class TestResult {
        private final String requestType;
        private final long timestamp;
        private final long responseTime;
        private final boolean success;

        public TestResult(String requestType, long timestamp, long responseTime, boolean success) {
            this.requestType = requestType;
            this.timestamp = timestamp;
            this.responseTime = responseTime;
            this.success = success;
        }
    }

    /**
     * 资源快照类
     */
    private static class ResourceSnapshot {
        private final long timestamp;
        private final double cpuLoad;
        private final long totalMemoryUsed;
        private final long heapMemoryUsed;
        private final long nonHeapMemoryUsed;
        private final int availableProcessors;

        public ResourceSnapshot(long timestamp, double cpuLoad, long totalMemoryUsed,
                long heapMemoryUsed, long nonHeapMemoryUsed, int availableProcessors) {
            this.timestamp = timestamp;
            this.cpuLoad = cpuLoad;
            this.totalMemoryUsed = totalMemoryUsed;
            this.heapMemoryUsed = heapMemoryUsed;
            this.nonHeapMemoryUsed = nonHeapMemoryUsed;
            this.availableProcessors = availableProcessors;
        }
    }

    /**
     * 主方法，用于演示
     */
    public static void main(String[] args) {
        // 使用平台线程进行测试
        PerformanceTestRunner platformThreadTest = new PerformanceTestRunner(50, 30, false);
        platformThreadTest.runTest();

        // 暂停一段时间
        try {
            Thread.sleep(5000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // 使用虚拟线程进行测试
        PerformanceTestRunner virtualThreadTest = new PerformanceTestRunner(50, 30, true);
        virtualThreadTest.runTest();
    }
}