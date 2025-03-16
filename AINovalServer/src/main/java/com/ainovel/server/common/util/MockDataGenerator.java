//package com.ainovel.server.common.util;
//
//import java.time.Instant;
//import java.time.LocalDateTime;
//import java.util.ArrayList;
//import java.util.List;
//import java.util.Random;
//import java.util.UUID;
//import java.util.stream.Collectors;
//import java.util.stream.IntStream;
//
//import com.ainovel.server.domain.model.AIInteraction;
//import com.ainovel.server.domain.model.Character;
//import com.ainovel.server.domain.model.Novel;
//import com.ainovel.server.domain.model.Scene;
//
///**
// * 测试数据生成器，用于创建模拟数据进行性能测试
// */
//public class MockDataGenerator {
//
//    private static final Random random = new Random();
//    private static final String[] NOVEL_TITLES = {
//            "龙族崛起", "星际迷航", "魔法学院", "末日求生", "江湖传说",
//            "未来战士", "古墓奇谭", "都市异能", "仙侠奇缘", "科技狂潮"
//    };
//
//    private static final String[] NOVEL_GENRES = {
//            "奇幻", "科幻", "武侠", "仙侠", "都市",
//            "历史", "军事", "悬疑", "恐怖", "言情"
//    };
//
//    private static final String[] CHARACTER_NAMES = {
//            "李明", "张伟", "王芳", "赵静", "陈强",
//            "林雪", "刘洋", "黄晓", "吴刚", "孙悟空",
//            "猪八戒", "沙僧", "唐僧", "白龙马", "如来佛",
//            "观音菩萨", "玉皇大帝", "太上老君", "二郎神", "哪吒"
//    };
//
//    private static final String[] CHARACTER_ROLES = {
//            "主角", "配角", "反派", "导师", "助手",
//            "情感角色", "对手", "神秘人", "小丑", "智者"
//    };
//
//    private static final String[] ACT_TITLES = {
//            "序章", "第一卷", "第二卷", "第三卷", "终章"
//    };
//
//    private static final String[] CHAPTER_TITLES = {
//            "初入江湖", "危机四伏", "命运转折", "巅峰对决", "意外发现",
//            "神秘来客", "暗夜追踪", "秘密会面", "生死抉择", "最终决战"
//    };
//
//    private static final String LOREM_IPSUM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
//
//    /**
//     * 生成指定数量的小说
//     */
//    public static List<Novel> generateNovels(int count) {
//        return IntStream.range(0, count)
//                .mapToObj(i -> generateNovel())
//                .collect(Collectors.toList());
//    }
//
//    /**
//     * 生成单个小说
//     */
//    public static Novel generateNovel() {
//        String authorId = UUID.randomUUID().toString();
//        String username = "作者" + random.nextInt(1000);
//
//        Novel.Author author = Novel.Author.builder()
//                .id(authorId)
//                .username(username)
//                .build();
//
//        LocalDateTime createdAt = LocalDateTime.now().minusDays(random.nextInt(30));
//        LocalDateTime updatedAt = LocalDateTime.now();
//
//        // 生成小说结构
//        Novel.Structure structure = generateStructure();
//
//        // 生成元数据
//        int wordCount = random.nextInt(100000) + 10000;
//        Novel.Metadata metadata = Novel.Metadata.builder()
//                .wordCount(wordCount)
//                .readTime(wordCount / 300) // 假设每分钟阅读300字
//                .lastEditedAt(updatedAt)
//                .version(1 + random.nextInt(5))
//                .build();
//
//        // 生成标签和分类
//        List<String> genres = new ArrayList<>();
//        genres.add(NOVEL_GENRES[random.nextInt(NOVEL_GENRES.length)]);
//
//        List<String> tags = new ArrayList<>();
//        tags.add("热门");
//        tags.add("推荐");
//        if (random.nextBoolean()) {
//            tags.add("精品");
//        }
//
//        return Novel.builder()
//                .id(UUID.randomUUID().toString())
//                .title(NOVEL_TITLES[random.nextInt(NOVEL_TITLES.length)])
//                .description("这是一部" + genres.get(0) + "小说，讲述了一个精彩的故事。")
//                .author(author)
//                .genre(genres)
//                .tags(tags)
//                .coverImage("https://example.com/covers/" + UUID.randomUUID().toString() + ".jpg")
//                .status("进行中")
//                .structure(structure)
//                .metadata(metadata)
//                .createdAt(createdAt)
//                .updatedAt(updatedAt)
//                .build();
//    }
//
//    /**
//     * 生成小说结构
//     */
//    private static Novel.Structure generateStructure() {
//        int actCount = 1 + random.nextInt(3); // 1-3卷
//
//        List<Novel.Act> acts = IntStream.range(0, actCount)
//                .mapToObj(actIndex -> {
//                    int chapterCount = 3 + random.nextInt(5); // 3-7章
//
//                    List<Novel.Chapter> chapters = IntStream.range(0, chapterCount)
//                            .mapToObj(chapterIndex -> {
//                                return Novel.Chapter.builder()
//                                        .id(UUID.randomUUID().toString())
//                                        .title(CHAPTER_TITLES[random.nextInt(CHAPTER_TITLES.length)] + " "
//                                                + (chapterIndex + 1))
//                                        .description("这是第" + (actIndex + 1) + "卷第" + (chapterIndex + 1) + "章")
//                                        .order(chapterIndex + 1)
//                                        .sceneId(UUID.randomUUID().toString())// 生成一个场景ID
//                                        .build();
//                            })
//                            .collect(Collectors.toList());
//
//                    return Novel.Act.builder()
//                            .id(UUID.randomUUID().toString())
//                            .title(ACT_TITLES[Math.min(actIndex, ACT_TITLES.length - 1)])
//                            .description("这是小说的第" + (actIndex + 1) + "卷")
//                            .order(actIndex + 1)
//                            .chapters(chapters)
//                            .build();
//                })
//                .collect(Collectors.toList());
//
//        return Novel.Structure.builder()
//                .acts(acts)
//                .build();
//    }
//
//    /**
//     * 生成指定数量的场景
//     */
//    public static List<Scene> generateScenes(int count, String novelId) {
//        return IntStream.range(0, count)
//                .mapToObj(i -> generateScene(novelId, UUID.randomUUID().toString(), i + 1))
//                .collect(Collectors.toList());
//    }
//
//    /**
//     * 生成单个场景
//     */
//    public static Scene generateScene(String novelId, String chapterId, int version) {
//        String content = generateRandomContent(500 + random.nextInt(1500));
//
//        // 创建历史记录
//        Scene.HistoryEntry historyEntry = Scene.HistoryEntry.builder()
//                .content(content)
//                .updatedAt(LocalDateTime.now().minusDays(random.nextInt(10)))
//                .updatedBy("system")
//                .reason("初始创建")
//                .build();
//
//        List<Scene.HistoryEntry> history = new ArrayList<>();
//        history.add(historyEntry);
//
//        // 创建向量嵌入
//        Scene.VectorEmbedding vectorEmbedding = Scene.VectorEmbedding.builder()
//                .vector(new float[384]) // 假设使用384维向量
//                .model("text-embedding-3-small")
//                .build();
//
//        // 随机填充向量
//        for (int i = 0; i < vectorEmbedding.getVector().length; i++) {
//            vectorEmbedding.getVector()[i] = random.nextFloat();
//        }
//
//        return Scene.builder()
//                .id(UUID.randomUUID().toString())
//                .novelId(novelId)
//                .chapterId(chapterId)
//                .title(CHAPTER_TITLES[random.nextInt(CHAPTER_TITLES.length)] + " " + version)
//                .content(content)
//                .summary("这是一个场景的摘要，描述了主要内容。")
//                .vectorEmbedding(vectorEmbedding)
//                .characterIds(new ArrayList<>())
//                .locations(List.of("山洞", "森林", "城堡").subList(0, 1 + random.nextInt(2)))
//                .timeframe("第" + (1 + random.nextInt(10)) + "天")
//                .version(version)
//                .history(history)
//                .createdAt(Instant.now().minusSeconds(random.nextInt(30 * 24 * 60 * 60)))
//                .updatedAt(Instant.now())
//                .build();
//    }
//
//    /**
//     * 生成指定数量的角色
//     */
//    public static List<Character> generateCharacters(int count, String novelId) {
//        return IntStream.range(0, count)
//                .mapToObj(i -> generateCharacter(novelId))
//                .collect(Collectors.toList());
//    }
//
//    /**
//     * 生成单个角色
//     */
//    public static Character generateCharacter(String novelId) {
//        String name = CHARACTER_NAMES[random.nextInt(CHARACTER_NAMES.length)];
//        String roleType = CHARACTER_ROLES[random.nextInt(CHARACTER_ROLES.length)];
//
//        // 创建角色详情
//        Character.Details details = Character.Details.builder()
//                .age(18 + random.nextInt(50))
//                .gender(random.nextBoolean() ? "男" : "女")
//                .occupation("职业" + random.nextInt(10))
//                .background("出身于一个普通家庭，年轻时经历了一些特殊事件...")
//                .personality("性格" + (random.nextBoolean() ? "开朗" : "内向") + "，" +
//                        (random.nextBoolean() ? "勇敢" : "谨慎"))
//                .appearance("外表" + (random.nextBoolean() ? "英俊" : "普通") + "，身材" +
//                        (random.nextBoolean() ? "高大" : "中等"))
//                .goals(List.of("目标1", "目标2"))
//                .conflicts(List.of("冲突1", "冲突2"))
//                .build();
//
//        // 创建关系网络
//        List<Character.Relationship> relationships = new ArrayList<>();
//        if (random.nextBoolean()) {
//            relationships.add(Character.Relationship.builder()
//                    .characterId(UUID.randomUUID().toString())
//                    .type(random.nextBoolean() ? "朋友" : "敌人")
//                    .description("他们之间有着复杂的关系...")
//                    .build());
//        }
//
//        // 创建向量嵌入
//        Character.VectorEmbedding vectorEmbedding = Character.VectorEmbedding.builder()
//                .vector(IntStream.range(0, 384)
//                        .mapToObj(i -> random.nextFloat())
//                        .collect(Collectors.toList()))
//                .model("text-embedding-3-small")
//                .build();
//
//        return Character.builder()
//                .id(UUID.randomUUID().toString())
//                .novelId(novelId)
//                .name(name)
//                .description("这是一个" + roleType + "，名叫" + name + "。")
//                .details(details)
//                .relationships(relationships)
//                .vectorEmbedding(vectorEmbedding)
//                .createdAt(Instant.now().minusSeconds(random.nextInt(30 * 24 * 60 * 60)))
//                .updatedAt(Instant.now())
//                .build();
//    }
//
//    /**
//     * 生成指定数量的AI交互记录
//     */
//    public static List<AIInteraction> generateAIInteractions(int count, String sceneId) {
//        List<AIInteraction> interactions = new ArrayList<>();
//        for (int i = 0; i < count; i++) {
//            String userId = UUID.randomUUID().toString();
//            String novelId = UUID.randomUUID().toString();
//
//            // 创建对话消息
//            List<AIInteraction.Message> conversation = new ArrayList<>();
//
//            // 用户消息
//            AIInteraction.Message userMessage = AIInteraction.Message.builder()
//                    .role("user")
//                    .content("请帮我继续写这个场景")
//                    .timestamp(LocalDateTime.now().minusMinutes(random.nextInt(60)))
//                    .context(AIInteraction.Message.Context.builder()
//                            .sceneIds(List.of(sceneId))
//                            .characterIds(new ArrayList<>())
//                            .retrievalScore(0.85 + random.nextDouble() * 0.15)
//                            .build())
//                    .build();
//
//            // AI消息
//            AIInteraction.Message aiMessage = AIInteraction.Message.builder()
//                    .role("assistant")
//                    .content(generateRandomContent(200 + random.nextInt(500)))
//                    .timestamp(LocalDateTime.now().minusMinutes(random.nextInt(30)))
//                    .build();
//
//            conversation.add(userMessage);
//            conversation.add(aiMessage);
//
//            // 创建生成内容
//            AIInteraction.Generation.TokenUsage tokenUsage = AIInteraction.Generation.TokenUsage.builder()
//                    .prompt(100 + random.nextInt(400))
//                    .completion(200 + random.nextInt(800))
//                    .total(300 + random.nextInt(1200))
//                    .build();
//
//            AIInteraction.Generation generation = AIInteraction.Generation.builder()
//                    .prompt("请基于以下场景继续写作：...")
//                    .result(aiMessage.getContent())
//                    .model("gpt-4")
//                    .tokenUsage(tokenUsage)
//                    .cost(0.01 + random.nextDouble() * 0.05)
//                    .createdAt(LocalDateTime.now().minusMinutes(random.nextInt(30)))
//                    .build();
//
//            List<AIInteraction.Generation> generations = new ArrayList<>();
//            generations.add(generation);
//
//            // 创建AI交互
//            AIInteraction interaction = AIInteraction.builder()
//                    .id(UUID.randomUUID().toString())
//                    .userId(userId)
//                    .novelId(novelId)
//                    .conversation(conversation)
//                    .generations(generations)
//                    .createdAt(LocalDateTime.now().minusHours(random.nextInt(24)))
//                    .updatedAt(LocalDateTime.now())
//                    .build();
//
//            interactions.add(interaction);
//        }
//        return interactions;
//    }
//
//    /**
//     * 生成随机内容
//     */
//    private static String generateRandomContent(int length) {
//        StringBuilder content = new StringBuilder();
//        while (content.length() < length) {
//            content.append(LOREM_IPSUM);
//            content.append(" ");
//        }
//        return content.substring(0, length);
//    }
//}