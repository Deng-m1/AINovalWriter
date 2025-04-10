package com.ainovel.server.security;

import lombok.AllArgsConstructor;
import lombok.Data;

/**
 * 当前认证用户类 用于表示当前认证的用户信息
 */
@Data
@AllArgsConstructor
public class CurrentUser {

    /**
     * 用户ID
     */
    private String id;

    /**
     * 用户名
     */
    private String username;

    /**
     * 获取用户ID
     *
     * @return 用户ID
     */
    public String getId() {
        return id;
    }

    /**
     * 获取用户名
     *
     * @return 用户名
     */
    public String getUsername() {
        return username;
    }
}
