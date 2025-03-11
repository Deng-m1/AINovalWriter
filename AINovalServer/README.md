# AI小说助手系统后端服务

AI小说助手系统是一个基于云端的小说创作管理平台，通过AI技术辅助作者完成小说的全生命周期管理，包括创意构思、人物塑造、情节设计、内容创作和修改完善等环节。

## 技术栈

- **后端框架**：Spring Boot 3.2.0 + WebFlux
- **编程语言**：Java 23（支持虚拟线程）
- **数据存储**：MongoDB
- **AI集成**：多模型适配器架构
- **向量检索**：MongoDB Atlas Vector Search
- **响应式编程**：Project Reactor
- **并发处理**：JDK 23虚拟线程

## 项目结构

```
AINovalServer/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── ainovel/
│   │   │           └── server/
│   │   │               ├── AiNovelServerApplication.java  # 应用程序入口
│   │   │               ├── common/                        # 通用组件
│   │   │               │   ├── exception/                 # 异常类
│   │   │               │   └── model/                     # 通用模型
│   │   │               ├── config/                        # 配置类
│   │   │               ├── domain/                        # 领域模型
│   │   │               │   └── model/                     # 领域实体
│   │   │               ├── repository/                    # 数据访问层
│   │   │               ├── service/                       # 服务层
│   │   │               │   └── impl/                      # 服务实现
│   │   │               └── web/                           # Web层
│   │   │                   ├── base/                      # 基础控制器
│   │   │                   └── controller/                # 控制器
│   │   └── resources/
│   │       └── application.yml                            # 应用配置
│   └── test/                                              # 测试代码
└── pom.xml                                                # Maven配置
```

## Sprint 1 开发计划（响应式架构与虚拟线程验证）

### 目标

验证Spring Boot 3.2.0 + WebFlux + JDK 23虚拟线程的组合效果，建立基础微服务架构。

### 任务清单

1. [x] 创建基础Spring Boot 3.2.0 + WebFlux项目结构
2. [x] 实现JDK 23虚拟线程配置
3. [x] 创建基础领域模型（Novel, Scene）
4. [x] 实现响应式MongoDB数据访问层
5. [x] 开发基础服务层
6. [x] 实现响应式控制器
7. [ ] 开发模拟AI请求的性能测试用例
8. [ ] 配置监控和指标收集
9. [ ] 开发负载测试脚本
10. [ ] 进行性能测试和评估

### 技术验证测试计划

- 高并发下的响应时间测试（模拟100/500/1000并发用户）
- 长时间运行的I/O操作性能对比（传统线程池 vs 虚拟线程）
- 内存占用和资源利用率分析
- 模拟AI请求的吞吐量测试
- 响应式MongoDB操作性能测试

## 运行项目

### 前置条件

- JDK 23
- Maven 3.8+
- MongoDB 6.0+

### 构建和运行

```bash
# 构建项目
mvn clean package

# 运行项目
java --enable-preview -jar target/ai-novel-server-0.0.1-SNAPSHOT.jar
```

## API文档

启动应用后，可以通过以下地址访问API文档：

- Swagger UI: http://localhost:8080/swagger-ui.html

## 监控

应用集成了Spring Boot Actuator和Prometheus，可以通过以下端点访问监控信息：

- 健康检查: http://localhost:8080/actuator/health
- 指标: http://localhost:8080/actuator/metrics
- Prometheus: http://localhost:8080/actuator/prometheus 