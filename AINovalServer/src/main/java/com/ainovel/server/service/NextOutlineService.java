package com.ainovel.server.service;

import com.ainovel.server.web.dto.NextOutlineDTO;
import com.ainovel.server.web.dto.OutlineGenerationChunk;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 剧情推演服务接口
 */
public interface NextOutlineService {

    /**
     * 生成剧情大纲
     *
     * @param novelId 小说ID
     * @param request 生成请求
     * @return 生成的剧情大纲列表
     */
    Mono<NextOutlineDTO.GenerateResponse> generateNextOutlines(String novelId, NextOutlineDTO.GenerateRequest request);

    /**
     * 流式生成剧情大纲
     *
     * @param novelId 小说ID
     * @param request 生成请求
     * @return 流式生成的剧情大纲块
     */
    Flux<OutlineGenerationChunk> generateNextOutlinesStream(String novelId, NextOutlineDTO.GenerateRequest request);
    
    /**
     * 重新生成单个剧情大纲选项
     *
     * @param novelId 小说ID
     * @param request 重新生成请求
     * @return 流式生成的剧情大纲块
     */
    Flux<OutlineGenerationChunk> regenerateOutlineOption(String novelId, NextOutlineDTO.RegenerateOptionRequest request);

    /**
     * 保存选中的剧情大纲
     *
     * @param novelId 小说ID
     * @param request 保存请求
     * @return 保存结果
     */
    Mono<NextOutlineDTO.SaveResponse> saveNextOutline(String novelId, NextOutlineDTO.SaveRequest request);
}
