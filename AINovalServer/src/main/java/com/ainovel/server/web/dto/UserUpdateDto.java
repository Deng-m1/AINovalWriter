package com.ainovel.server.web.dto;

import com.ainovel.server.domain.model.User;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 用户更新数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserUpdateDto {
    private String id;
    private User user;
}