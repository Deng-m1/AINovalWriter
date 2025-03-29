package com.ainovel.server.web.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.AIChatMessage;
import com.ainovel.server.domain.model.AIChatSession;
import com.ainovel.server.service.AIChatService;
import com.ainovel.server.web.base.ReactiveBaseController;
import com.ainovel.server.web.dto.IdDto;
import com.ainovel.server.web.dto.SessionCreateDto;
import com.ainovel.server.web.dto.SessionMessageDto;
import com.ainovel.server.web.dto.SessionUpdateDto;

import lombok.RequiredArgsConstructor;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * AI聊天控制器
 */
@RestController
@RequestMapping("/api/v1/ai-chat")
@RequiredArgsConstructor
public class AIChatController extends ReactiveBaseController {

    private final AIChatService aiChatService;

    /**
     * 创建聊天会话
     *
     * @param sessionCreateDto 包含用户ID、小说ID、模型名称和元数据的DTO
     * @return 创建的会话
     */
    @PostMapping("/sessions/create")
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<AIChatSession> createSession(@RequestBody SessionCreateDto sessionCreateDto) {
        return aiChatService.createSession(
                sessionCreateDto.getUserId(),
                sessionCreateDto.getNovelId(),
                sessionCreateDto.getModelName(),
                sessionCreateDto.getMetadata()
        );
    }

    /**
     * 获取会话详情
     *
     * @param sessionDto 包含用户ID和会话ID的DTO
     * @return 会话信息
     */
    @PostMapping("/sessions/get")
    public Mono<AIChatSession> getSession(@RequestBody SessionMessageDto sessionDto) {
        return aiChatService.getSession(sessionDto.getUserId(), sessionDto.getSessionId());
    }

    /**
     * 获取用户的所有会话 (流式 SSE)
     *
     * @param idDto 包含用户ID的DTO
     * @return 会话列表流
     */
    @PostMapping(value = "/sessions/list", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<AIChatSession> listSessions(@RequestBody IdDto idDto) {
        return aiChatService.listUserSessions(idDto.getId(), 0, 100);
    }

    /**
     * 更新会话
     *
     * @param sessionUpdateDto 包含用户ID、会话ID和更新内容的DTO
     * @return 更新后的会话
     */
    @PostMapping("/sessions/update")
    public Mono<AIChatSession> updateSession(@RequestBody SessionUpdateDto sessionUpdateDto) {
        return aiChatService.updateSession(
                sessionUpdateDto.getUserId(),
                sessionUpdateDto.getSessionId(),
                sessionUpdateDto.getUpdates()
        );
    }

    /**
     * 删除会话
     *
     * @param sessionDto 包含用户ID和会话ID的DTO
     * @return 操作结果
     */
    @PostMapping("/sessions/delete")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteSession(@RequestBody SessionMessageDto sessionDto) {
        return aiChatService.deleteSession(sessionDto.getUserId(), sessionDto.getSessionId());
    }

    /**
     * 发送消息并获取响应
     *
     * @param sessionMessageDto 包含用户ID、会话ID、消息内容和元数据的DTO
     * @return AI响应消息
     */
    @PostMapping("/messages/send")
    public Mono<AIChatMessage> sendMessage(@RequestBody SessionMessageDto sessionMessageDto) {
        return aiChatService.sendMessage(
                sessionMessageDto.getUserId(),
                sessionMessageDto.getSessionId(),
                sessionMessageDto.getContent(),
                sessionMessageDto.getMetadata()
        );
    }

    /**
     * 流式发送消息并获取响应
     *
     * @param sessionMessageDto 包含用户ID、会话ID、消息内容和元数据的DTO
     * @return 流式AI响应消息 (SSE)
     */
    @PostMapping(value = "/messages/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<AIChatMessage> streamMessage(@RequestBody SessionMessageDto sessionMessageDto) {
        return aiChatService.streamMessage(
                sessionMessageDto.getUserId(),
                sessionMessageDto.getSessionId(),
                sessionMessageDto.getContent(),
                sessionMessageDto.getMetadata()
        );
    }

    /**
     * 获取会话消息历史 (流式 SSE)
     *
     * @param sessionDto 包含用户ID、会话ID的DTO (以及可选的 limit)
     * @return 消息历史列表流
     */
    @PostMapping(value = "/messages/history", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<AIChatMessage> getMessageHistory(@RequestBody SessionMessageDto sessionDto) {
        int limit = 100;
        return aiChatService.getSessionMessages(sessionDto.getUserId(), sessionDto.getSessionId(), limit);
    }

    /**
     * 获取特定消息
     *
     * @param messageDto 包含用户ID和消息ID的DTO
     * @return 消息详情
     */
    @PostMapping("/messages/get")
    public Mono<AIChatMessage> getMessage(@RequestBody SessionMessageDto messageDto) {
        return aiChatService.getMessage(messageDto.getUserId(), messageDto.getMessageId());
    }

    /**
     * 删除消息
     *
     * @param messageDto 包含用户ID和消息ID的DTO
     * @return 操作结果
     */
    @PostMapping("/messages/delete")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteMessage(@RequestBody SessionMessageDto messageDto) {
        return aiChatService.deleteMessage(messageDto.getUserId(), messageDto.getMessageId());
    }

    /**
     * 获取会话消息数量
     *
     * @param sessionDto 包含会话ID的DTO
     * @return 消息数量
     */
    @PostMapping("/messages/count")
    public Mono<Long> countSessionMessages(@RequestBody IdDto sessionDto) {
        return aiChatService.countSessionMessages(sessionDto.getId());
    }

    /**
     * 获取用户会话数量
     *
     * @param idDto 包含用户ID的DTO
     * @return 会话数量
     */
    @PostMapping("/sessions/count")
    public Mono<Long> countUserSessions(@RequestBody IdDto idDto) {
        return aiChatService.countUserSessions(idDto.getId());
    }
}
