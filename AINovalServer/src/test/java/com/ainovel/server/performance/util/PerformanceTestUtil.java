package com.ainovel.server.performance.util;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

/**
 * 性能测试工具类 (PerformanceTestUtil)
 * 提供了生成随机测试数据的方法，如小说标题、作者名、AI模型等
 * 包含模拟请求和响应的辅助方法
 * 提供了暂停执行的工具方法
 */
public class PerformanceTestUtil {
    
    private static final String[] NOVEL_TITLES = {
        "龙族崛起", "星际迷航", "魔法学院", "末日求生", "江湖风云", 
        "科技狂潮", "异界征途", "都市传说", "仙侠奇缘", "未来战争",
        "古墓探秘", "虚拟游戏", "神话重生", "机甲时代", "灵异档案"
    };
    
    private static final String[] NOVEL_GENRES = {
        "玄幻", "科幻", "武侠", "都市", "历史", "军事", "游戏", "体育", "灵异", "言情"
    };
    
    private static final String[] AUTHOR_NAMES = {
        "墨客", "风云", "星辰", "雨落", "剑客", "幻想", "流年", "清风", "明月", "山水"
    };
    
    private static final String[] AI_MODELS = {
        "gpt-3.5-turbo", "gpt-4", "claude-3-opus", "claude-3-sonnet", "llama-3-70b"
    };
    
    /**
     * 生成随机小说标题
     */
    public static String randomNovelTitle() {
        return NOVEL_TITLES[ThreadLocalRandom.current().nextInt(NOVEL_TITLES.length)] + "-" + UUID.randomUUID().toString().substring(0, 8);
    }
    
    /**
     * 生成随机小说类型
     */
    public static String randomNovelGenre() {
        return NOVEL_GENRES[ThreadLocalRandom.current().nextInt(NOVEL_GENRES.length)];
    }
    
    /**
     * 生成随机作者名
     */
    public static String randomAuthorName() {
        return AUTHOR_NAMES[ThreadLocalRandom.current().nextInt(AUTHOR_NAMES.length)] + UUID.randomUUID().toString().substring(0, 4);
    }
    
    /**
     * 生成随机AI模型名称
     */
    public static String randomAIModel() {
        return AI_MODELS[ThreadLocalRandom.current().nextInt(AI_MODELS.length)];
    }
    
    /**
     * 生成随机小说简介
     */
    public static String randomNovelSummary() {
        return "这是一部" + randomNovelGenre() + "小说，讲述了主角在" + 
               ThreadLocalRandom.current().nextInt(1900, 2100) + "年的奇幻冒险故事。";
    }
    
    /**
     * 生成随机小说章节内容
     */
    public static String randomChapterContent(int minWords, int maxWords) {
        int wordCount = ThreadLocalRandom.current().nextInt(minWords, maxWords + 1);
        StringBuilder content = new StringBuilder();
        content.append("    ");  // 段落缩进
        
        for (int i = 0; i < wordCount; i++) {
            if (i > 0 && i % 50 == 0) {
                content.append("。\n    ");  // 每50个字左右换行
            } else if (i > 0 && i % 15 == 0) {
                content.append("，");
            } else {
                content.append("文");
            }
        }
        content.append("。");
        return content.toString();
    }
    
    /**
     * 生成随机AI请求内容
     */
    public static String randomAIPrompt() {
        String[] prompts = {
            "请为我的" + randomNovelGenre() + "小说创建一个精彩的开头",
            "帮我设计一个" + randomNovelGenre() + "小说的主角，性格鲜明",
            "为我的小说创建一个引人入胜的冲突情节",
            "设计一个" + randomNovelGenre() + "世界的魔法/科技体系",
            "为我的小说写一段精彩的战斗场景",
            "帮我构思一个出人意料的故事转折",
            "为我的小说设计一个令人难忘的结局"
        };
        return prompts[ThreadLocalRandom.current().nextInt(prompts.length)];
    }
    
    /**
     * 生成随机请求ID
     */
    public static String randomRequestId() {
        return "req-" + UUID.randomUUID().toString();
    }
    
    /**
     * 生成随机时间戳
     */
    public static String randomTimestamp() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime randomTime = now.minusDays(ThreadLocalRandom.current().nextInt(30))
                                     .minusHours(ThreadLocalRandom.current().nextInt(24))
                                     .minusMinutes(ThreadLocalRandom.current().nextInt(60));
        return randomTime.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
    }
    
    /**
     * 生成随机持续时间（毫秒）
     */
    public static long randomDuration(int minMs, int maxMs) {
        return ThreadLocalRandom.current().nextLong(minMs, maxMs + 1);
    }
    
    /**
     * 生成随机小说创建请求体
     */
    public static Map<String, Object> randomNovelCreateRequest() {
        Map<String, Object> request = new HashMap<>();
        request.put("title", randomNovelTitle());
        request.put("authorName", randomAuthorName());
        request.put("genre", randomNovelGenre());
        request.put("summary", randomNovelSummary());
        request.put("coverImageUrl", "https://example.com/covers/" + UUID.randomUUID().toString() + ".jpg");
        return request;
    }
    
    /**
     * 生成随机AI内容生成请求体
     */
    public static Map<String, Object> randomAIContentRequest() {
        Map<String, Object> request = new HashMap<>();
        request.put("model", randomAIModel());
        request.put("prompt", randomAIPrompt());
        request.put("maxTokens", ThreadLocalRandom.current().nextInt(100, 2000));
        request.put("temperature", ThreadLocalRandom.current().nextDouble(0.1, 1.0));
        request.put("stream", ThreadLocalRandom.current().nextBoolean());
        return request;
    }
    
    /**
     * 生成随机长时间运行请求体
     */
    public static Map<String, Object> randomLongRunningRequest(int minMs, int maxMs) {
        Map<String, Object> request = new HashMap<>();
        request.put("requestId", randomRequestId());
        request.put("durationMs", randomDuration(minMs, maxMs));
        return request;
    }
    
    /**
     * 生成随机内存使用测试请求体
     */
    public static Map<String, Object> randomMemoryUsageRequest(int minThreads, int maxThreads) {
        Map<String, Object> request = new HashMap<>();
        request.put("requestId", randomRequestId());
        request.put("threadCount", ThreadLocalRandom.current().nextInt(minThreads, maxThreads + 1));
        return request;
    }
    
    /**
     * 暂停指定的毫秒数
     */
    public static void pause(long milliseconds) {
        try {
            Thread.sleep(milliseconds);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
