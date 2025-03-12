package com.ainovel.server.performance;

import com.ainovel.server.performance.util.PerformanceTestUtil;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 虚拟线程性能测试类 (VirtualThreadPerformanceTest)
专门用于比较虚拟线程和传统线程的性能差异
执行大量并发任务，测量执行时间和内存使用
包含内存压力测试，创建大量线程以比较两种线程模型的内存效率
 */
public class VirtualThreadPerformanceTest {

    // 测试参数
    private static final int THREAD_COUNT = 1000;
    private static final int TASK_COUNT = 10000;
    private static final int TASK_DURATION_MIN_MS = 10;
    private static final int TASK_DURATION_MAX_MS = 100;
    
    /**
     * 主方法
     */
    public static void main(String[] args) {
        System.out.println("开始虚拟线程与传统线程性能对比测试...");
        
        // 测试传统线程
        System.out.println("\n=== 使用传统线程池 ===");
        testWithPlatformThreads();
        
        // 等待一段时间，让系统资源恢复
        PerformanceTestUtil.pause(2000);
        
        // 测试虚拟线程
        System.out.println("\n=== 使用虚拟线程 ===");
        testWithVirtualThreads();
        
        System.out.println("\n测试完成。");
    }
    
    /**
     * 使用传统线程池进行测试
     */
    private static void testWithPlatformThreads() {
        long startTime = System.currentTimeMillis();
        long memoryBefore = getUsedMemory();
        
        try (ExecutorService executor = Executors.newFixedThreadPool(THREAD_COUNT)) {
            runTasks(executor);
        }
        
        long memoryAfter = getUsedMemory();
        long endTime = System.currentTimeMillis();
        
        printResults("传统线程", startTime, endTime, memoryBefore, memoryAfter);
    }
    
    /**
     * 使用虚拟线程进行测试
     */
    private static void testWithVirtualThreads() {
        long startTime = System.currentTimeMillis();
        long memoryBefore = getUsedMemory();
        
        try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
            runTasks(executor);
        }
        
        long memoryAfter = getUsedMemory();
        long endTime = System.currentTimeMillis();
        
        printResults("虚拟线程", startTime, endTime, memoryBefore, memoryAfter);
    }
    
    /**
     * 运行测试任务
     */
    private static void runTasks(ExecutorService executor) {
        AtomicLong totalTaskDuration = new AtomicLong(0);
        List<Future<?>> futures = new ArrayList<>();
        
        // 提交任务
        for (int i = 0; i < TASK_COUNT; i++) {
            Future<?> future = executor.submit(() -> {
                long taskStart = System.currentTimeMillis();
                
                // 模拟任务执行
                simulateTask();
                
                long taskDuration = System.currentTimeMillis() - taskStart;
                totalTaskDuration.addAndGet(taskDuration);
            });
            futures.add(future);
        }
        
        // 等待所有任务完成
        for (Future<?> future : futures) {
            try {
                future.get();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        // 关闭线程池
        executor.shutdown();
        try {
            if (!executor.awaitTermination(30, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
        
        System.out.println("任务平均执行时间: " + (totalTaskDuration.get() / TASK_COUNT) + "ms");
    }
    
    /**
     * 模拟任务执行
     */
    private static void simulateTask() {
        // 模拟I/O阻塞操作
        int duration = ThreadLocalRandom.current().nextInt(TASK_DURATION_MIN_MS, TASK_DURATION_MAX_MS + 1);
        PerformanceTestUtil.pause(duration);
        
        // 模拟一些CPU计算
        int iterations = ThreadLocalRandom.current().nextInt(1000, 10000);
        double result = 0;
        for (int i = 0; i < iterations; i++) {
            result += Math.sin(i) * Math.cos(i);
        }
    }
    
    /**
     * 获取当前已使用内存
     */
    private static long getUsedMemory() {
        Runtime runtime = Runtime.getRuntime();
        return runtime.totalMemory() - runtime.freeMemory();
    }
    
    /**
     * 打印测试结果
     */
    private static void printResults(String threadType, long startTime, long endTime, long memoryBefore, long memoryAfter) {
        long duration = endTime - startTime;
        long memoryUsed = memoryAfter - memoryBefore;
        
        System.out.println("线程类型: " + threadType);
        System.out.println("任务数量: " + TASK_COUNT);
        System.out.println("线程数量: " + THREAD_COUNT);
        System.out.println("总执行时间: " + duration + "ms");
        System.out.println("内存使用: " + (memoryUsed / (1024 * 1024)) + "MB");
        System.out.println("每秒处理任务数: " + String.format("%.2f", (double) TASK_COUNT / (duration / 1000.0)));
    }
    
    /**
     * 内存压力测试
     */
    public static void memoryStressTest() {
        System.out.println("\n=== 内存压力测试 ===");
        
        // 测试参数
        final int THREAD_COUNT_STRESS = 10000;
        
        System.out.println("创建 " + THREAD_COUNT_STRESS + " 个传统线程...");
        long platformStart = System.currentTimeMillis();
        long platformMemoryBefore = getUsedMemory();
        
        try {
            List<Thread> platformThreads = new ArrayList<>();
            for (int i = 0; i < THREAD_COUNT_STRESS; i++) {
                Thread thread = new Thread(() -> {
                    PerformanceTestUtil.pause(1000);
                });
                platformThreads.add(thread);
            }
            
            // 启动线程
            for (Thread thread : platformThreads) {
                thread.start();
            }
            
            // 等待线程完成
            for (Thread thread : platformThreads) {
                thread.join();
            }
        } catch (OutOfMemoryError e) {
            System.out.println("传统线程内存溢出: " + e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        long platformMemoryAfter = getUsedMemory();
        long platformDuration = System.currentTimeMillis() - platformStart;
        
        System.out.println("传统线程执行时间: " + platformDuration + "ms");
        System.out.println("传统线程内存使用: " + ((platformMemoryAfter - platformMemoryBefore) / (1024 * 1024)) + "MB");
        
        // 等待一段时间，让系统资源恢复
        PerformanceTestUtil.pause(5000);
        System.gc();
        PerformanceTestUtil.pause(1000);
        
        System.out.println("\n创建 " + THREAD_COUNT_STRESS + " 个虚拟线程...");
        long virtualStart = System.currentTimeMillis();
        long virtualMemoryBefore = getUsedMemory();
        
        try {
            List<Thread> virtualThreads = new ArrayList<>();
            for (int i = 0; i < THREAD_COUNT_STRESS; i++) {
                Thread thread = Thread.startVirtualThread(() -> {
                    PerformanceTestUtil.pause(1000);
                });
                virtualThreads.add(thread);
            }
            
            // 等待线程完成
            for (Thread thread : virtualThreads) {
                thread.join();
            }
        } catch (OutOfMemoryError e) {
            System.out.println("虚拟线程内存溢出: " + e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        long virtualMemoryAfter = getUsedMemory();
        long virtualDuration = System.currentTimeMillis() - virtualStart;
        
        System.out.println("虚拟线程执行时间: " + virtualDuration + "ms");
        System.out.println("虚拟线程内存使用: " + ((virtualMemoryAfter - virtualMemoryBefore) / (1024 * 1024)) + "MB");
    }
}