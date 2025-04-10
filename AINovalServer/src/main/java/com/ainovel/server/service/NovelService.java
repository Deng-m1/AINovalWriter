package com.ainovel.server.service;

import java.util.List;
import java.util.Map;

import com.ainovel.server.domain.model.Character;
import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.domain.model.Scene;
import com.ainovel.server.domain.model.Setting;
import com.ainovel.server.web.dto.NovelWithScenesDto;
import com.ainovel.server.web.dto.NovelWithSummariesDto;

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
     * 更新小说元数据（标题、作者、系列）
     *
     * @param id 小说ID
     * @param title 标题
     * @param author 作者
     * @param series 系列
     * @return 更新后的小说
     */
    Mono<Novel> updateNovelMetadata(String id, String title, String author, String series);

    /**
     * 获取封面上传凭证
     *
     * @param novelId 小说ID
     * @return 上传凭证（包含上传URL和其他必要参数）
     */
    Mono<Map<String, String>> getCoverUploadCredential(String novelId);

    /**
     * 更新小说封面URL
     *
     * @param novelId 小说ID
     * @param coverUrl 封面图片URL
     * @return 更新后的小说
     */
    Mono<Novel> updateNovelCover(String novelId, String coverUrl);

    /**
     * 归档小说
     *
     * @param novelId 小说ID
     * @return 已归档的小说
     */
    Mono<Novel> archiveNovel(String novelId);

    /**
     * 恢复已归档小说
     *
     * @param novelId 小说ID
     * @return 恢复后的小说
     */
    Mono<Novel> unarchiveNovel(String novelId);

    /**
     * 永久删除小说（物理删除）
     *
     * @param novelId 小说ID
     * @return 操作结果
     */
    Mono<Void> permanentlyDeleteNovel(String novelId);

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

    /**
     * 更新卷标题
     *
     * @param novelId 小说ID
     * @param actId 卷ID
     * @param title 新标题
     * @return 更新后的小说
     */
    Mono<Novel> updateActTitle(String novelId, String actId, String title);

    /**
     * 更新章节标题
     *
     * @param novelId 小说ID
     * @param chapterId 章节ID
     * @param title 新标题
     * @return 更新后的小说
     */
    Mono<Novel> updateChapterTitle(String novelId, String chapterId, String title);

    /**
     * 添加新卷
     *
     * @param novelId 小说ID
     * @param title 卷标题
     * @param position 插入位置（如果为null则添加到末尾）
     * @return 更新后的小说
     */
    Mono<Novel> addAct(String novelId, String title, Integer position);

    /**
     * 添加新章节
     *
     * @param novelId 小说ID
     * @param actId 卷ID
     * @param title 章节标题
     * @param position 插入位置（如果为null则添加到末尾）
     * @return 更新后的小说
     */
    Mono<Novel> addChapter(String novelId, String actId, String title, Integer position);

    /**
     * 移动场景位置
     *
     * @param novelId 小说ID
     * @param sceneId 场景ID
     * @param targetChapterId 目标章节ID
     * @param targetPosition 目标位置
     * @return 更新后的小说
     */
    Mono<Novel> moveScene(String novelId, String sceneId, String targetChapterId, int targetPosition);

    /**
     * 获取小说详情及其场景摘要（不包含场景完整内容） 适用于大纲视图，减少数据传输量
     *
     * @param novelId 小说ID
     * @return 小说及其场景摘要
     */
    Mono<NovelWithSummariesDto> getNovelWithSceneSummaries(String novelId);

    /**
     * 计算并更新小说的总字数
     *
     * @param novelId 小说ID
     * @return 更新后的小说
     */
    Mono<Novel> updateNovelWordCount(String novelId);
}
