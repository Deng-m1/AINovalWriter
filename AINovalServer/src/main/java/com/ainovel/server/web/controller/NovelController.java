package com.ainovel.server.web.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ainovel.server.domain.model.Novel;
import com.ainovel.server.service.NovelService;
import com.ainovel.server.web.base.ReactiveBaseController;

import lombok.RequiredArgsConstructor;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 小说控制器
 */
@RestController
@RequestMapping("/novels")
@RequiredArgsConstructor
public class NovelController extends ReactiveBaseController {
    
    private final NovelService novelService;
    
    /**
     * 创建小说
     * @param novel 小说信息
     * @return 创建的小说
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Mono<Novel> createNovel(@RequestBody Novel novel) {
        return novelService.createNovel(novel);
    }
    
    /**
     * 获取小说详情
     * @param id 小说ID
     * @return 小说信息
     */
    @GetMapping("/{id}")
    public Mono<Novel> getNovel(@PathVariable String id) {
        return novelService.findNovelById(id);
    }
    
    /**
     * 更新小说
     * @param id 小说ID
     * @param novel 更新的小说信息
     * @return 更新后的小说
     */
    @PutMapping("/{id}")
    public Mono<Novel> updateNovel(@PathVariable String id, @RequestBody Novel novel) {
        return novelService.updateNovel(id, novel);
    }
    
    /**
     * 删除小说
     * @param id 小说ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteNovel(@PathVariable String id) {
        return novelService.deleteNovel(id);
    }
    
    /**
     * 获取作者的所有小说
     * @param authorId 作者ID
     * @return 小说列表
     */
    @GetMapping("/author/{authorId}")
    public Flux<Novel> getNovelsByAuthor(@PathVariable String authorId) {
        return novelService.findNovelsByAuthorId(authorId);
    }
    
    /**
     * 搜索小说
     * @param title 标题关键词
     * @return 小说列表
     */
    @GetMapping("/search")
    public Flux<Novel> searchNovels(@RequestParam String title) {
        return novelService.searchNovelsByTitle(title);
    }
} 