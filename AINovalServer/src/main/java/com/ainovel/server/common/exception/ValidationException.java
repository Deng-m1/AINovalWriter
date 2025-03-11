package com.ainovel.server.common.exception;

/**
 * 验证异常
 */
public class ValidationException extends RuntimeException {

    public ValidationException(String message) {
        super(message);
    }

    public ValidationException(String field, String message) {
        super(String.format("字段 '%s' 验证失败: %s", field, message));
    }
} 