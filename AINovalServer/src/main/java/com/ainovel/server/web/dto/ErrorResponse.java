package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 错误响应数据传输对象 用于向客户端传递API错误信息
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ErrorResponse {

    /**
     * 错误代码
     */
    private String code;

    /**
     * 错误消息
     */
    private String message;

    /**
     * 以错误消息构造错误响应
     *
     * @param message 错误消息
     */
    public ErrorResponse(String message) {
        this.code = "ERROR";
        this.message = message;
    }
}
