package com.ainovel.server.service.impl;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import org.springframework.stereotype.Component;

import com.ainovel.server.domain.dto.ParsedNovelData;
import com.ainovel.server.domain.dto.ParsedSceneData;
import com.ainovel.server.service.NovelParser;

import lombok.extern.slf4j.Slf4j;

/**
 * TXT格式小说解析器实现
 */
@Slf4j
@Component
public class TxtNovelParser implements NovelParser {

    /**
     * 章节标题模式 匹配： 1. 第[数字/中文数字][章节部回] 标题 - 中文模式 2. Chapter [数字] 标题 - 英文模式 3.
     * 罗马数字章节
     */
    private static final Pattern CHAPTER_TITLE_PATTERN = Pattern.compile(
            "^\\s*(?:(?:第[一二三四五六七八九十百千万零〇\\d]+[章卷部回])|(?:Chapter\\s+\\d+)|(?:[IVXLCDM]+))[\\s.:：]*(.*?)$",
            Pattern.CASE_INSENSITIVE
    );

    @Override
    public ParsedNovelData parseStream(Stream<String> lines) {
        ParsedNovelData parsedNovelData = new ParsedNovelData();
        parsedNovelData.setNovelTitle("导入的小说"); // 默认标题，可以从文件名推断

        AtomicReference<String> currentChapterTitle = new AtomicReference<>("");
        StringBuilder currentContent = new StringBuilder();
        AtomicInteger chapterCount = new AtomicInteger(0);

        // 使用reduce操作处理流
        lines.forEach(line -> {
            // 检查是否是章节标题
            Matcher matcher = CHAPTER_TITLE_PATTERN.matcher(line.trim());
            if (matcher.matches()) {
                // 如果当前有内容，则保存上一章节
                if (currentContent.length() > 0) {
                    saveCurrentChapter(parsedNovelData, currentChapterTitle.get(),
                            currentContent.toString(), chapterCount.get());
                    currentContent.setLength(0); // 清空内容缓冲
                }

                // 提取章节标题
                String titleText = matcher.group(1);
                if (titleText == null || titleText.trim().isEmpty()) {
                    titleText = "第" + (chapterCount.incrementAndGet()) + "章";
                } else {
                    chapterCount.incrementAndGet();
                }

                currentChapterTitle.set(line.trim());
                log.debug("识别到章节标题: {}", currentChapterTitle.get());
            } else {
                // 内容行，添加到当前内容
                if (currentContent.length() > 0) {
                    currentContent.append("\n");
                }
                currentContent.append(line);
            }
        });

        // 处理最后一章
        if (currentContent.length() > 0) {
            saveCurrentChapter(parsedNovelData, currentChapterTitle.get(),
                    currentContent.toString(), chapterCount.get());
        }

        log.info("TXT解析完成，共解析出{}个章节", parsedNovelData.getScenes().size());
        return parsedNovelData;
    }

    private void saveCurrentChapter(ParsedNovelData parsedNovelData, String title, String content, int order) {
        // 如果是第一章并且没有标题，可能是前言或引言
        if (order == 0 && (title == null || title.isEmpty())) {
            title = "前言";
        }

        // 如果仍然没有标题，使用默认章节标题
        if (title == null || title.isEmpty()) {
            title = "第" + order + "章";
        }

        ParsedSceneData sceneData = ParsedSceneData.builder()
                .sceneTitle(title)
                .sceneContent(content)
                .order(order)
                .build();

        parsedNovelData.addScene(sceneData);
    }

    @Override
    public String getSupportedExtension() {
        return "txt";
    }
}
