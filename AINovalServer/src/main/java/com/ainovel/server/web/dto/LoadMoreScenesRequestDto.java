package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 加载更多场景的请求数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class LoadMoreScenesRequestDto {

    /**
     * 小说ID
     */
    private String novelId;
    
    /**
     * 卷ID，用于限制在指定卷内分页加载
     */
    private String actId;

    /**
     * 从哪个章节开始加载
     */
    private String fromChapterId;

    /**
     * 加载方向，"up"表示向上加载，"down"表示向下加载
     */
    private String direction;

    /**
     * 要加载的章节数量
     */
    private int chaptersLimit = 5;
}
