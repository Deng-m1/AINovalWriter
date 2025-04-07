package com.ainovel.server.service.impl;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.repository.NovelRepository;
import com.ainovel.server.repository.SceneRepository;
import com.ainovel.server.service.MetadataService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

/**
 * 元数据服务实现类
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MetadataServiceImpl implements MetadataService {

    private final NovelRepository novelRepository;
    private final SceneRepository sceneRepository;

    @Override
    public int calculateWordCount(String content) {
        if (content == null || content.isEmpty()) {
            return 0;
        }

        // 简单实现，去除HTML标记和特殊字符后统计
        String plainText = content.replaceAll("<[^>]*>", "") // 移除HTML标签
                .replaceAll("\\s+", " ") // 将多个空白字符合并为一个
                .trim();

        // 统计中文字符数量
        int chineseCount = 0;
        for (char c : plainText.toCharArray()) {
            if (isChinese(c)) {
                chineseCount++;
            }
        }

        // 英文部分按空格分词
        String englishOnly = plainText.replaceAll("[^\\x00-\\x7F]+", " ").trim();
        int englishWordCount = englishOnly.isEmpty() ? 0 : englishOnly.split("\\s+").length;

        return chineseCount + englishWordCount;
    }

    /**
     * 判断字符是否是中文
     */
    private boolean isChinese(char c) {
        return c >= 0x4E00 && c <= 0x9FA5; // Unicode CJK统一汉字范围
    }

    @Override
    public Scene updateSceneMetadata(Scene scene) {
        if (scene == null) {
            return null;
        }

        // 计算场景字数
        if (scene.getContent() != null) {
            int wordCount = calculateWordCount(scene.getContent());
            scene.setWordCount(wordCount);
        }

        // 设置更新时间
        scene.setUpdatedAt(LocalDateTime.now());

        // 这里可以添加其他元数据更新逻辑
        // 例如：场景类型判断、自动分类等
        return scene;
    }

    @Override
    public Mono<Novel> updateNovelMetadata(String novelId) {
        log.info("正在更新小说 {} 的元数据", novelId);
        return novelRepository.findById(novelId)
                .switchIfEmpty(Mono.error(new ResourceNotFoundException("小说", novelId)))
                .flatMap(novel -> {
                    // 获取小说的所有场景
                    return sceneRepository.findByNovelId(novelId)
                            .collectList()
                            .flatMap(scenes -> {
                                // 计算总字数
                                int totalWordCount = scenes.stream()
                                        .mapToInt(scene -> scene.getWordCount() != null ? scene.getWordCount() : 0)
                                        .sum();

                                // 计算估计阅读时间 (假设每分钟阅读300字)
                                int readTime = totalWordCount / 300;
                                if (readTime < 1 && totalWordCount > 0) {
                                    readTime = 1; // 最小阅读时间为1分钟
                                }

                                // 确保元数据对象存在
                                if (novel.getMetadata() == null) {
                                    novel.setMetadata(Novel.Metadata.builder().build());
                                }

                                // 更新元数据
                                novel.getMetadata().setWordCount(totalWordCount);
                                novel.getMetadata().setReadTime(readTime);
                                novel.getMetadata().setLastEditedAt(LocalDateTime.now());
                                novel.setUpdatedAt(LocalDateTime.now());

                                return novelRepository.save(novel);
                            });
                })
                .doOnSuccess(novel -> log.info("小说 {} 元数据更新成功，总字数: {}", novelId,
                novel.getMetadata() != null ? novel.getMetadata().getWordCount() : 0))
                .doOnError(e -> log.error("小说 {} 元数据更新失败", novelId, e));
    }

    @Override
    public Mono<Void> triggerNovelMetadataUpdate(Scene scene) {
        if (scene == null || scene.getNovelId() == null) {
            return Mono.empty();
        }

        // 异步更新小说元数据，不阻塞主流程
        updateNovelMetadata(scene.getNovelId())
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe(
                        novel -> log.debug("成功触发小说 {} 的元数据更新", scene.getNovelId()),
                        error -> log.error("触发小说 {} 的元数据更新失败", scene.getNovelId(), error)
                );

        // 立即返回，不等待元数据更新完成
        return Mono.empty();
    }
}
