package com.ainovel.server.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 分页获取场景的请求数据传输对象
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PaginatedScenesRequestDto {

    /**
     * 小说ID
     */
    private String novelId;

    /**
     * 上次编辑的章节ID，作为页面中心点
     */
    private String lastEditedChapterId;

    /**
     * 要加载的章节数量限制（前后各加载多少章节） 例如：值为5时，则加载中心章节及其前后各5章，共11章
     */
    private int chaptersLimit = 5;
}
