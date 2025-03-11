package com.ainovel.server.common.exception;

/**
 * 资源未找到异常
 */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }

    public ResourceNotFoundException(String resourceType, String resourceId) {
        super(String.format("未找到%s资源，ID: %s", resourceType, resourceId));
    }
} 