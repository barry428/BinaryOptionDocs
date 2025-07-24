# 本地开发环境 Nacos 配置与微服务集成要点

## 1. 相关配置文件路径

- option-common-service/src/main/resources/bootstrap.yml
- option-common-service/src/main/resources/application.yml
- option-market-service/src/main/resources/bootstrap.yml
- option-market-service/src/main/resources/application.yml
- option-order-service/src/main/resources/bootstrap.yml
- option-order-service/src/main/resources/application.yml
- env/nacos/docker-compose.yml
- env/nacos/init-nacos-mysql.sql（如有初始化 SQL）

## 2. Nacos 重要参数

- Nacos 地址：`127.0.0.1:8848`
- Nacos namespace：`daba47a0-5f1d-4f53-aaaf-6f5490131ca1`
- Nacos group：`DEFAULT_GROUP`
- Data ID 示例：
  - option-common-service-dev.yml
  - option-market-service-dev.yml
  - option-order-service-dev.yml

## 3. 各服务配置迁移说明

- 所有微服务的 application.yml 只保留极简内容（如端口、日志级别等），业务配置全部迁移到 Nacos。
- 每个服务在 Nacos 新建对应 Data ID，内容为原 application.yml 配置。
- 各服务 bootstrap.yml 统一配置 Nacos 地址、namespace、group、file-extension、shared-configs。
- 参考 bootstrap.yml 典型内容：

```yaml
spring:
  application:
    name: option-common-service
  profiles:
    active: dev
  cloud:
    nacos:
      config:
        server-addr: 127.0.0.1:8848
        namespace: daba47a0-5f1d-4f53-aaaf-6f5490131ca1
        group: DEFAULT_GROUP
        file-extension: yml
        shared-configs:
          - data-id: option-common-service-dev.yml
            group: DEFAULT_GROUP
            refresh: true
      discovery:
        server-addr: 127.0.0.1:8848
        namespace: daba47a0-5f1d-4f53-aaaf-6f5490131ca1
```

## 4. 依赖版本

- Spring Boot：2.7.18
- Spring Cloud：2021.x
- Spring Cloud Alibaba：2021.x（与 Spring Boot 2.7.x 兼容）
- 需引入依赖：
  - spring-cloud-starter-alibaba-nacos-config
  - spring-cloud-starter-alibaba-nacos-discovery
  - spring-boot-starter-data-jpa

## 5. 常见排查要点

- 日志中应有 Nacos Config 相关输出，确认配置已拉取。
- bootstrap.yml 必须存在且被打包进 jar。
- Nacos Data ID、group、namespace 必须与服务配置完全一致。
- Nacos 控制台配置内容需完整，尤其是数据库相关配置。
- entityManagerFactory 报错多为数据库配置未加载或 JPA starter 缺失。
- 端口、namespace、依赖版本需与实际环境一致。

## 6. 批量脚本与最佳实践

- 推荐使用 import-nacos-configs.sh 脚本批量导入配置，支持多 Data ID、namespace、group。
- Nacos 配置变更后，服务端需加 @RefreshScope 支持自动刷新。
- 生产环境建议 jar 包+CI/CD 自动化部署。

---

如有新变更（如 namespace、Data ID、依赖版本等），请及时同步本文档，确保团队信息一致。 

---

## 这说明什么？

- 你的 Nacos 服务端和 namespace 配置都没问题。
- 但**option-common-service 并没有成功注册到 Nacos**，即服务注册流程没有走通。

---

## 进一步精准排查

请重点检查以下几点：

### 1. 启动日志有无 Nacos Discovery 相关内容？
- 日志里应有类似  
  ```
  Nacos Discovery Service ...
  Register instance ...
  DiscoveryClient ...
  ```
- 如果完全没有，说明 discovery starter 没生效或配置未加载。

### 2. pom.xml 依赖
- **必须有**  
  ```xml
  <dependency>
      <groupId>com.alibaba.cloud</groupId>
      <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
  </dependency>
  ```
- 版本要和 Spring Boot 2.7.18、Spring Cloud 2021.x 匹配。

### 3. 配置文件
- `bootstrap.yml` 必须有 discovery 配置，且 namespace、server-addr、group 都要和 Nacos 控制台一致。
- `spring.application.name` 必须和 Data ID、服务名一致。

### 4. 启动类
- 可以加上 `@EnableDiscoveryClient`（虽然 2.x 理论上自动生效，但加上更保险）。

### 5. 端口与网络
- 服务端口未被占用，且本地能访问 127.0.0.1:8848。

---

## 建议你现在做什么

1. **重启 option-common-service 服务**，并把**启动日志中所有包含 Nacos、Discovery、Register、DiscoveryClient 的内容**贴出来。
2. **贴出 option-common-service 的 pom.xml 依赖部分**（只要 dependencies 标签内内容即可）。
3. **贴出 option-common-service 的 bootstrap.yml 全部内容**。

---

这样我可以帮你精准定位到底是依赖、配置、还是别的什么问题，快速解决服务无法注册到 Nacos 的问题！

如需批量排查，也可以用如下命令看所有服务注册情况：
```bash
curl "http://127.0.0.1:8848/nacos/v1/ns/service/list?namespaceId=daba47a0-5f1d-4f53-aaaf-6f5490131ca1"
```

等你日志或配置信息！ 