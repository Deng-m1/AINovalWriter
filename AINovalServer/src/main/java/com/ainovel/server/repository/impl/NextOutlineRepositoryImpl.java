package com.ainovel.server.repository.impl;

import com.ainovel.server.domain.model.NextOutline;
import com.ainovel.server.repository.NextOutlineRepository;
import org.reactivestreams.Publisher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.mongodb.core.ReactiveMongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

/**
 * 剧情大纲仓库MongoDB实现
 */
@Repository
public class NextOutlineRepositoryImpl implements NextOutlineRepository {

    private final ReactiveMongoTemplate mongoTemplate;

    @Autowired
    public NextOutlineRepositoryImpl(ReactiveMongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }

    @Override
    public <S extends NextOutline> Mono<S> save(S outline) {
        return mongoTemplate.save(outline);
    }

    @Override
    public Mono<NextOutline> findById(String id) {
        return mongoTemplate.findById(id, NextOutline.class);
    }

    @Override
    public Flux<NextOutline> findByNovelId(String novelId) {
        Query query = Query.query(Criteria.where("novelId").is(novelId));
        return mongoTemplate.find(query, NextOutline.class);
    }

    @Override
    public Flux<NextOutline> findByNovelIdAndSelected(String novelId, boolean selected) {
        Query query = Query.query(
                Criteria.where("novelId").is(novelId)
                        .and("selected").is(selected)
        );
        return mongoTemplate.find(query, NextOutline.class);
    }

    @Override
    public Flux<NextOutline> findAll() {
        return mongoTemplate.findAll(NextOutline.class);
    }

    @Override
    public Mono<Void> deleteById(String id) {
        return mongoTemplate.remove(Query.query(Criteria.where("id").is(id)), NextOutline.class).then();
    }

    @Override
    public Mono<Void> deleteAll() {
        return mongoTemplate.remove(new Query(), NextOutline.class).then();
    }
    
    @Override
    public <S extends NextOutline> Flux<S> saveAll(Iterable<S> entities) {
        // 将Iterable转换为Flux并逐个保存
        return Flux.fromIterable(entities)
                .flatMap(this::save);
    }

    @Override
    public <S extends NextOutline> Flux<S> saveAll(Publisher<S> entityStream) {
        // 逐个保存Publisher中的实体
        return Flux.from(entityStream)
                .flatMap(this::save);
    }

    @Override
    public Mono<NextOutline> findById(Publisher<String> id) {
        // 从Publisher获取ID并查找
        return Mono.from(id)
                .flatMap(this::findById);
    }

    @Override
    public Mono<Boolean> existsById(String id) {
        // 检查指定ID的实体是否存在
        return findById(id)
                .map(outline -> true)
                .defaultIfEmpty(false);
    }

    @Override
    public Mono<Boolean> existsById(Publisher<String> id) {
        // 从Publisher获取ID并检查是否存在
        return Mono.from(id)
                .flatMap(this::existsById);
    }

    @Override
    public Flux<NextOutline> findAllById(Iterable<String> ids) {
        // 查询所有指定ID的实体
        return Flux.fromIterable(ids)
                .flatMap(this::findById);
    }

    @Override
    public Flux<NextOutline> findAllById(Publisher<String> idStream) {
        // 从Publisher中的ID流查找所有实体
        return Flux.from(idStream)
                .flatMap(this::findById);
    }

    @Override
    public Mono<Long> count() {
        // 计算总数
        return mongoTemplate.count(new Query(), NextOutline.class);
    }

    @Override
    public Mono<Void> deleteById(Publisher<String> id) {
        // 从Publisher获取ID并删除
        return Mono.from(id)
                .flatMap(this::deleteById);
    }

    @Override
    public Mono<Void> delete(NextOutline entity) {
        // 删除指定实体
        return deleteById(entity.getId());
    }

    @Override
    public Mono<Void> deleteAllById(Iterable<? extends String> ids) {
        // 删除所有指定ID的实体
        return Flux.fromIterable(ids)
                .flatMap(this::deleteById)
                .then();
    }

    @Override
    public Mono<Void> deleteAll(Iterable<? extends NextOutline> entities) {
        // 删除所有指定的实体
        return Flux.fromIterable(entities)
                .map(NextOutline::getId)
                .flatMap(this::deleteById)
                .then();
    }

    @Override
    public Mono<Void> deleteAll(Publisher<? extends NextOutline> entityStream) {
        // 删除Publisher中的所有实体
        return Flux.from(entityStream)
                .map(NextOutline::getId)
                .flatMap(this::deleteById)
                .then();
    }
}
