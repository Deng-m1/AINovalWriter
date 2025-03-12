package com.ainovel.server.performance;

import com.ainovel.server.performance.util.PerformanceTestUtil;

import java.io.BufferedWriter;
import java.io.File;
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
     * @param concurrentUsers 并发用户数
     * @param testDurationSeconds 测试持续时间（秒）
     * @param useVirtualThreads 是否使用虚拟线程
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
                    success
            );
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
                            Runtime.getRuntime().availableProcessors()
                    );
                    
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
        System.out.println("成功率: " + String.format("%.2f%%", (double) successfulRequests.get() / totalRequests.get() * 100));
        
        if (totalRequests.get() > 0) {
            System.out.println("平均响应时间: " + (totalResponseTime.get() / totalRequests.get()) + "ms");
            System.out.println("最大响应时间: " + maxResponseTime.get() + "ms");
            System.out.println("最小响应时间: " + (minResponseTime.get() == Long.MAX_VALUE ? 0 : minResponseTime.get()) + "ms");
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
            
            // 读取报告模板
            String template = new String(Files.readAllBytes(Paths.get(REPORT_TEMPLATE_PATH)));
            
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
                .replace("{TESTING_TOOL}", "自定义性能测试框架")
                .replace("{TEST_DURATION}", testDurationSeconds + "秒")
                .replace("{CONCURRENT_USERS}", String.valueOf(concurrentUsers))
                .replace("{THREAD_TYPE}", useVirtualThreads ? "虚拟线程" : "平台线程")
                .replace("{TOTAL_REQUESTS}", String.valueOf(totalRequests.get()))
                .replace("{SUCCESS_RATE}", String.format("%.2f%%", (double) successfulRequests.get() / totalRequests.get() * 100))
                .replace("{AVG_RESPONSE_TIME}", avgResponseTime + "ms")
                .replace("{MAX_RESPONSE_TIME}", maxResponseTime.get() + "ms")
                .replace("{MIN_RESPONSE_TIME}", (minResponseTime.get() == Long.MAX_VALUE ? 0 : minResponseTime.get()) + "ms")
                .replace("{THROUGHPUT}", String.format("%.2f", throughput) + "请求/秒")
                .replace("{CPU_USAGE_AVG}", String.format("%.2f%%", cpuUsageAvg * 100))
                .replace("{MEMORY_USAGE_AVG}", (memoryUsageAvg / (1024 * 1024)) + "MB")
                .replace("{MEMORY_USAGE_MAX}", (memoryUsageMax / (1024 * 1024)) + "MB")
                .replace("{NOVEL_CREATE_AVG_TIME}", avgResponseTimeByType.get("novel_create") + "ms")
                .replace("{NOVEL_UPDATE_AVG_TIME}", avgResponseTimeByType.get("novel_update") + "ms")
                .replace("{NOVEL_QUERY_AVG_TIME}", avgResponseTimeByType.get("novel_query") + "ms")
                .replace("{AI_GENERATE_AVG_TIME}", avgResponseTimeByType.get("ai_generate") + "ms")
                .replace("{AI_STREAM_AVG_TIME}", avgResponseTimeByType.get("ai_stream") + "ms")
                .replace("{NOVEL_CREATE_COUNT}", String.valueOf(requestCountByType.get("novel_create").get()))
                .replace("{NOVEL_UPDATE_COUNT}", String.valueOf(requestCountByType.get("novel_update").get()))
                .replace("{NOVEL_QUERY_COUNT}", String.valueOf(requestCountByType.get("novel_query").get()))
                .replace("{AI_GENERATE_COUNT}", String.valueOf(requestCountByType.get("ai_generate").get()))
                .replace("{AI_STREAM_COUNT}", String.valueOf(requestCountByType.get("ai_stream").get()));
        
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