package com.ainovel.server.service;

import java.util.List;

import com.ainovel.server.domain.model.Character;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Setting;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说服务接口
 */
public interface NovelService {

    /**
     * 创建小说
     * @param novel 小说信息
     * @return 创建的小说
     */
    Mono<Novel> createNovel(Novel novel);

    /**
     * 根据ID查找小说
     * @param id 小说ID
     * @return 小说信息
     */
    Mono<Novel> findNovelById(String id);

    /**
     * 更新小说信息
     * @param id 小说ID
     * @param novel 更新的小说信息
     * @return 更新后的小说
     */
    Mono<Novel> updateNovel(String id, Novel novel);

    /**
     * 删除小说
     * @param id 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteNovel(String id);

    /**
     * 查找用户的所有小说
     * @param authorId 作者ID
     * @return 小说列表
     */
    Flux<Novel> findNovelsByAuthorId(String authorId);

    /**
     * 根据标题搜索小说
     * @param title 标题关键词
     * @return 小说列表
     */
    Flux<Novel> searchNovelsByTitle(String title);

    /**
     * 获取小说的所有场景
     * @param novelId 小说ID
     * @return 场景列表
     */
    Flux<Scene> getNovelScenes(String novelId);

    /**
     * 获取小说的所有角色
     * @param novelId 小说ID
     * @return 角色列表
     */
    Flux<Character> getNovelCharacters(String novelId);

    /**
     * 获取小说的所有设定
     * @param novelId 小说ID
     * @return 设定列表
     */
    Flux<Setting> getNovelSettings(String novelId);

    /**
     * 更新小说最后编辑的章节
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @return 更新后的小说
     */
    Mono<Novel> updateLastEditedChapter(String novelId, String chapterId);

    /**
     * 获取章节上下文场景（前后五章）
     * @param novelId 小说ID
     * @param authorId 作者ID
     * @return 场景列表
     */
    Mono<List<Scene>> getChapterContextScenes(String novelId, String authorId);
}