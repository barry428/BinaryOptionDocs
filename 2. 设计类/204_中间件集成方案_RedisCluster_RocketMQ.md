# BinaryOption 微服务项目 Redis Cluster & RocketMQ 集成最新方案

## 一、依赖与模块管理

### 1. 父模块统一依赖管理
- 新建 `option-parent` 作为父 pom，所有 option-* 子模块 parent 指向 `option-parent`。
- 依赖版本通过 `<dependencyManagement>` 统一管理，子模块无需单独指定版本。

```xml
<!-- option-parent/pom.xml 片段 -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
            <version>3.2.6</version>
        </dependency>
        <dependency>
            <groupId>org.apache.rocketmq</groupId>
            <artifactId>rocketmq-spring-boot-starter</artifactId>
            <version>2.2.3</version>
        </dependency>
        <!-- 其他依赖 -->
    </dependencies>
</dependencyManagement>
```

### 2. 通用工具模块
- 新建 `option-common-utils`，封装 RedisUtil、RocketMQUtil 等所有通用工具类。
- 仅工具类、DTO、安全相关类放在 utils，**不包含业务逻辑**。
- 各服务只依赖 `option-common-utils`，不直接依赖其他服务。

```xml
<!-- 各服务 pom.xml -->
<dependency>
    <groupId>com.binaryoption</groupId>
    <artifactId>option-common-utils</artifactId>
</dependency>
```

### 3. spring-boot-maven-plugin 配置
- 只在可执行服务模块（如 market/order）配置 spring-boot-maven-plugin。
- 公共模块（如 common-service、common-utils）**不配置**该插件。

---

## 二、配置文件（application.yml）

每个服务的 `src/main/resources/application.yml` 示例：

```yaml
spring:
  redis:
    cluster:
      nodes: 127.0.0.1:7000,127.0.0.1:7001,127.0.0.1:7002
    password: ${REDIS_PASSWORD:yourpassword}
    timeout: 3000
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0
        max-wait: -1ms

rocketmq:
  name-server: ${ROCKETMQ_NAME_SERVER:127.0.0.1:9876}
  producer:
    group: ${spring.application.name}-producer
  consumer:
    group: ${spring.application.name}-consumer
```
> 敏感信息建议用环境变量或配置中心（如 Nacos、Apollo）管理。

---

## 三、通用工具类封装（option-common-utils）

### Redis 工具类
```java
package com.binaryoption.commonutils.redis;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

@Component
public class RedisUtil {
    @Autowired
    private StringRedisTemplate redisTemplate;

    public void set(String key, String value) {
        redisTemplate.opsForValue().set(key, value);
    }
    public String get(String key) {
        return redisTemplate.opsForValue().get(key);
    }
    // 可扩展更多方法
}
```

### RocketMQ 工具类
```java
package com.binaryoption.commonutils.mq;
import org.apache.rocketmq.spring.core.RocketMQTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class RocketMQUtil {
    @Autowired
    private RocketMQTemplate rocketMQTemplate;

    public void send(String topic, String msg) {
        rocketMQTemplate.convertAndSend(topic, msg);
    }
    // 可扩展更多方法
}
```

---

## 四、服务中依赖与调用

- 各服务只需依赖 `option-common-utils`，即可直接注入并使用工具类。

```java
@Autowired
private RedisUtil redisUtil;
@Autowired
private RocketMQUtil rocketMQUtil;

public void demo() {
    redisUtil.set("order:1", "test");
    String value = redisUtil.get("order:1");
    rocketMQUtil.send("order-topic", "新订单消息");
}
```

---

## 五、最佳实践与运维建议

1. **配置中心**：推荐 Nacos、Apollo、Spring Cloud Config 管理配置，支持多环境切换。
2. **健康检查**：引入 Spring Boot Actuator，监控 Redis、RocketMQ 连接状态。
3. **异常处理**：工具类方法建议加 try-catch，统一日志输出。
4. **链路追踪**：可集成 Skywalking、Zipkin 等，便于分布式追踪。
5. **安全**：敏感信息用环境变量或加密方式管理。
6. **依赖隔离**：所有 option-* 服务只依赖 option-common-utils，不直接依赖其他服务。

---

## 六、目录结构建议

```
BinaryOption/
├─ option-parent/
├─ option-common-utils/
│    └─ src/main/java/com/binaryoption/commonutils/
│         ├─ redis/RedisUtil.java
│         └─ mq/RocketMQUtil.java
├─ option-common-service/
├─ option-market-service/
├─ option-order-service/
└─ ...
```

---

## 七、总结

- 依赖、配置、工具类全部标准化、模块化，便于维护和复用。
- 各服务只需引入工具类即可直接使用 Redis 和 RocketMQ，无需重复造轮子。
- 支持多环境、配置中心、健康检查、链路追踪等企业级最佳实践。
- spring-boot-maven-plugin 只加在可执行服务模块，公共模块不加。
- 依赖关系清晰，极简、易维护。 