package com.ainovel.server.repository;

import com.ainovel.server.domain.model.NextOutline;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;

/**
 * 剧情大纲仓库
 */
@Repository
public interface NextOutlineRepository extends ReactiveCrudRepository<NextOutline, String> {

    /**
     * 根据小说ID查找大纲
     *
     * @param novelId 小说ID
     * @return 大纲列表
     */
    Flux<NextOutline> findByNovelId(String novelId);

    /**
     * 根据小说ID和选中状态查找大纲
     *
     * @param novelId 小说ID
     * @param selected 是否选中
     * @return 大纲列表
     */
    Flux<NextOutline> findByNovelIdAndSelected(String novelId, boolean selected);
}
