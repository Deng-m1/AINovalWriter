package com.ainovel.server.exception;

/**
 * 向量存储异常
 */
public class VectorStoreException extends RuntimeException {
    
    public VectorStoreException(String message) {
        super(message);
    }
    
    public VectorStoreException(String message, Throwable cause) {
        super(message, cause);
    }
} 