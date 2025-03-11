package com.ainovel.server.web.base;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.common.exception.ValidationException;
import com.ainovel.server.common.model.ErrorResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

/**
 * 响应式控制器基类
 * 提供统一的响应处理和错误处理
 */
@Slf4j
public abstract class ReactiveBaseController {

    /**
     * 包装响应结果
     * @param result 响应数据
     * @return 包装后的响应
     */
    protected <T> Mono<ServerResponse> responseOf(Mono<T> result) {
        return result
            .flatMap(data -> ServerResponse.ok().bodyValue(data))
            .onErrorResume(this::handleError);
    }
    
    /**
     * 统一错误处理
     * @param error 错误信息
     * @return 错误响应
     */
    protected Mono<ServerResponse> handleError(Throwable error) {
        log.error("处理请求时发生错误", error);
        
        if (error instanceof ValidationException) {
            return ServerResponse.badRequest()
                .bodyValue(new ErrorResponse(error.getMessage()));
        } else if (error instanceof ResourceNotFoundException) {
            return ServerResponse.notFound().build();
        } else {
            return ServerResponse.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .bodyValue(new ErrorResponse("服务器内部错误"));
        }
    }
} 