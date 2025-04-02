package com.ainovel.server.web.base;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.ainovel.server.common.exception.ResourceNotFoundException;
import com.ainovel.server.web.dto.ErrorResponse;

import lombok.extern.slf4j.Slf4j;

/**
 * 响应式Controller基类 提供通用的异常处理和错误响应
 */
@Slf4j
@RestControllerAdvice
public class ReactiveBaseController {

    /**
     * 处理资源未找到异常
     *
     * @param ex 异常
     * @return 错误响应
     */
    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleResourceNotFoundException(ResourceNotFoundException ex) {
        log.error("资源未找到: {}", ex.getMessage());
        return new ErrorResponse("NOT_FOUND", ex.getMessage());
    }

    /**
     * 处理通用异常
     *
     * @param ex 异常
     * @return 错误响应
     */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ErrorResponse handleException(Exception ex) {
        log.error("服务器内部错误: {}", ex.getMessage(), ex);
        return new ErrorResponse("INTERNAL_SERVER_ERROR", "服务器内部错误: " + ex.getMessage());
    }
}
