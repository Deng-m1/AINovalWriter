package com.ainovel.server.service;

import com.ainovel.server.domain.dto.ParsedNovelData;

import reactor.core.publisher.Mono;

import java.util.stream.Stream;

/**
 * 小说解析器接口
 * 实现策略模式，不同类型的文件可以有不同的解析实现
 */
public interface NovelParser {

    /**
     * 从文本行流中解析小说数据
     *
     * @param lines 文本行流
     * @return 解析后的小说数据
     */
    ParsedNovelData parseStream(Stream<String> lines);
    
    /**
     * 获取支持的文件扩展名
     *
     * @return 扩展名（不含点，如 "txt"）
     */
    String getSupportedExtension();
} 