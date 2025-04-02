package com.ainovel.server.service;

import org.springframework.http.codec.multipart.FilePart;
import org.springframework.http.codec.ServerSentEvent;

import com.ainovel.server.web.dto.ImportStatus;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说导入服务接口 负责处理小说文件导入、解析和存储，以及通过SSE推送状态更新
 */
public interface ImportService {

    /**
     * 开始导入流程
     *
     * @param filePart 上传的文件部分
     * @param userId 用户ID
     * @return 导入任务ID
     */
    Mono<String> startImport(FilePart filePart, String userId);

    /**
     * 获取导入任务的状态流
     *
     * @param jobId 任务ID
     * @return 包含导入状态的SSE事件流
     */
    Flux<ServerSentEvent<ImportStatus>> getImportStatusStream(String jobId);
}
