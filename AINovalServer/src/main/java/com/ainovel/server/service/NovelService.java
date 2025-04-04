package com.ainovel.server.service;

import java.util.List;
import java.util.Map;

import com.ainovel.server.domain.model.Character;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Setting;
import com.ainovel.server.web.dto.NovelWithScenesDto;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说服务接口
 */
public interface NovelService {

    /**
     * 创建小说
     *
     * @param novel 小说信息
     * @return 创建的小说
     */
    Mono<Novel> createNovel(Novel novel);

    /**
     * 根据ID查找小说
     *
     * @param id 小说ID
     * @return 小说信息
     */
    Mono<Novel> findNovelById(String id);

    /**
     * 更新小说信息
     *
     * @param id 小说ID
     * @param novel 更新的小说信息
     * @return 更新后的小说
     */
    Mono<Novel> updateNovel(String id, Novel novel);

    /**
     * 更新小说信息及其场景内容
     *
     * @param id 小说ID
     * @param novel 更新的小说信息
     * @param scenesByChapter 按章节分组的场景列表
     * @return 更新后的小说
     */
    Mono<Novel> updateNovelWithScenes(String id, Novel novel, Map<String, List<Scene>> scenesByChapter);

    /**
     * 删除小说
     *
     * @param id 小说ID
     * @return 操作结果
     */
    Mono<Void> deleteNovel(String id);

    /**
     * 查找用户的所有小说
     *
     * @param authorId 作者ID
     * @return 小说列表
     */
    Flux<Novel> findNovelsByAuthorId(String authorId);

    /**
     * 根据标题搜索小说
     *
     * @param title 标题关键词
     * @return 小说列表
     */
    Flux<Novel> searchNovelsByTitle(String title);

    /**
     * 获取小说的所有场景
     *
     * @param novelId 小说ID
     * @return 场景列表
     */
    Flux<Scene> getNovelScenes(String novelId);

    /**
     * 获取小说的所有角色
     *
     * @param novelId 小说ID
     * @return 角色列表
     */
    Flux<Character> getNovelCharacters(String novelId);

    /**
     * 获取小说的所有设定
     *
     * @param novelId 小说ID
     * @return 设定列表
     */
    Flux<Setting> getNovelSettings(String novelId);

    /**
     * 更新小说最后编辑的章节
     *
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @return 更新后的小说
     */
    Mono<Novel> updateLastEditedChapter(String novelId, String chapterId);

    /**
     * 获取章节上下文场景（前后五章）
     *
     * @param novelId 小说ID
     * @param authorId 作者ID
     * @return 场景列表
     */
    Mono<List<Scene>> getChapterContextScenes(String novelId, String authorId);

    /**
     * 获取整本小说内容，包括小说基本信息及其所有场景
     *
     * @param novelId 小说ID
     * @return 含小说及其所有场景数据的DTO
     */
    Mono<NovelWithScenesDto> getNovelWithAllScenes(String novelId);

    /**
     * 获取小说详情及其部分场景内容（分页加载） 基于上次编辑章节为中心，获取前后指定数量的章节及其场景内容
     *
     * @param novelId 小说ID
     * @param lastEditedChapterId 上次编辑的章节ID，作为页面中心点
     * @param chaptersLimit 要加载的章节数量限制（前后各加载多少章节）
     * @return 小说及其分页加载的场景数据
     */
    Mono<NovelWithScenesDto> getNovelWithPaginatedScenes(String novelId, String lastEditedChapterId, int chaptersLimit);

    /**
     * 加载更多场景内容 根据方向（向上或向下）加载更多章节的场景内容
     *
     * @param novelId 小说ID
     * @param fromChapterId 从哪个章节开始加载
     * @param direction 加载方向，"up"表示向上加载，"down"表示向下加载
     * @param chaptersLimit 要加载的章节数量
     * @return 加载的更多场景数据，按章节组织
     */
    Mono<Map<String, List<Scene>>> loadMoreScenes(String novelId, String fromChapterId, String direction, int chaptersLimit);
}
