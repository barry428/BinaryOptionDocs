# PostgreSQL兼容方案设计文档

## 1. 概述

本文档详细说明如何让option-common-service同时兼容MySQL和PostgreSQL数据库，以此作为整个项目多数据库兼容的参考实现。

**目标环境：**
- PostgreSQL 13.x
- 服务器：localhost:5433
- 数据库：binary_option  
- 账号：postgres/root

## 2. 当前问题分析

### 2.1 MySQL特定语法识别

通过分析option-common-service的MyBatis Mapper文件，发现以下MySQL特定语法：

| 问题类型 | MySQL语法 | PostgreSQL语法 | 影响文件 |
|---------|----------|---------------|----------|
| 时间函数 | `NOW()` | `CURRENT_TIMESTAMP` | AccountMapper.xml, UserMapper.xml等 |
| 分页语法 | `LIMIT #{offset}, #{limit}` | `LIMIT #{limit} OFFSET #{offset}` | UserMapper.xml |
| 表名引用 | `FROM user` | `FROM "user"` | UserMapper.xml (user是PG保留字) |

### 2.2 具体问题清单

**时间函数问题（17处）：**
```xml
<!-- MySQL -->
#{signature}, #{riskAgreement}, #{amlAgreement}, NOW(), NOW()
update_time = NOW()

<!-- PostgreSQL需要 -->
#{signature}, #{riskAgreement}, #{amlAgreement}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
update_time = CURRENT_TIMESTAMP
```

**分页语法问题（2处）：**
```xml
<!-- MySQL -->
LIMIT #{offset}, #{limit}

<!-- PostgreSQL需要 -->
LIMIT #{limit} OFFSET #{offset}
```

**表名问题（所有UserMapper查询）：**
```xml
<!-- MySQL -->
FROM user

<!-- PostgreSQL需要 -->
FROM "user"
```

## 3. 兼容方案设计

### 3.1 方案选择

采用**MyBatis原生databaseId机制**实现多数据库兼容，该方案具有以下优势：

- ✅ MyBatis原生支持，无需额外框架
- ✅ 编译时确定SQL，性能无损
- ✅ 维护成本低，一套代码管理
- ✅ 升级友好，不影响现有逻辑

### 3.2 核心配置

#### 3.2.1 MyBatis数据库标识配置

```yaml
# application-mysql.yml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/binary_option?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai
    username: root
    password: root
    driver-class-name: com.mysql.cj.jdbc.Driver

mybatis:
  configuration:
    database-id: mysql
    
# application-postgresql.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5433/binary_option
    username: postgres
    password: root
    driver-class-name: org.postgresql.Driver

mybatis:
  configuration:
    database-id: postgresql
```

#### 3.2.2 依赖管理

```xml
<!-- 两个数据库驱动都包含，运行时根据配置选择 -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>
```

## 4. Mapper改造方案

### 4.1 时间函数兼容

**改造前：**
```xml
<insert id="insert" parameterType="com.binaryoption.commonservice.domain.User" 
        useGeneratedKeys="true" keyProperty="id">
    INSERT INTO user (
        external_id, password, nickname, email, phone, status, 
        signature, risk_agreement, aml_agreement, create_time, update_time
    ) VALUES (
        #{externalId}, #{password}, #{nickname}, #{email}, #{phone}, #{status},
        #{signature}, #{riskAgreement}, #{amlAgreement}, NOW(), NOW()
    )
</insert>
```

**改造后：**
```xml
<!-- MySQL版本 -->
<insert id="insert" databaseId="mysql" parameterType="com.binaryoption.commonservice.domain.User" 
        useGeneratedKeys="true" keyProperty="id">
    INSERT INTO user (
        external_id, password, nickname, email, phone, status, 
        signature, risk_agreement, aml_agreement, create_time, update_time
    ) VALUES (
        #{externalId}, #{password}, #{nickname}, #{email}, #{phone}, #{status},
        #{signature}, #{riskAgreement}, #{amlAgreement}, NOW(), NOW()
    )
</insert>

<!-- PostgreSQL版本 -->
<insert id="insert" databaseId="postgresql" parameterType="com.binaryoption.commonservice.domain.User" 
        useGeneratedKeys="true" keyProperty="id">
    INSERT INTO "user" (
        external_id, password, nickname, email, phone, status, 
        signature, risk_agreement, aml_agreement, create_time, update_time
    ) VALUES (
        #{externalId}, #{password}, #{nickname}, #{email}, #{phone}, #{status},
        #{signature}, #{riskAgreement}, #{amlAgreement}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    )
</insert>
```

### 4.2 分页查询兼容

**改造前：**
```xml
<select id="findAll" resultMap="UserResultMap">
    SELECT <include refid="Base_Column_List"/>
    FROM user
    ORDER BY id DESC
    LIMIT #{offset}, #{limit}
</select>
```

**改造后：**
```xml
<!-- MySQL版本 -->
<select id="findAll" databaseId="mysql" resultMap="UserResultMap">
    SELECT <include refid="Base_Column_List"/>
    FROM user
    ORDER BY id DESC
    LIMIT #{offset}, #{limit}
</select>

<!-- PostgreSQL版本 -->
<select id="findAll" databaseId="postgresql" resultMap="UserResultMap">
    SELECT <include refid="Base_Column_List"/>
    FROM "user"
    ORDER BY id DESC
    LIMIT #{limit} OFFSET #{offset}
</select>
```

### 4.3 通用查询保持不变

对于无数据库差异的查询，保持原有写法：

```xml
<!-- 这类查询两个数据库语法相同，无需修改 -->
<select id="findById" parameterType="java.lang.Long" resultMap="UserResultMap">
    SELECT <include refid="Base_Column_List"/>
    FROM "user"  <!-- PostgreSQL用双引号，MySQL兼容 -->
    WHERE id = #{id}
</select>
```

## 5. 完整改造示例

### 5.1 UserMapper.xml改造

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" 
    "http://mybatis.org/dtd/mybatis-3-mapper.dtd">

<mapper namespace="com.binaryoption.commonservice.mapper.UserMapper">
    
    <!-- 结果映射保持不变 -->
    <resultMap id="UserResultMap" type="com.binaryoption.commonservice.domain.User">
        <id column="id" property="id"/>
        <result column="external_id" property="externalId"/>
        <!-- ... 其他字段映射 ... -->
    </resultMap>
    
    <!-- 基础查询字段保持不变 -->
    <sql id="Base_Column_List">
        id, external_id, password, nickname, email, phone, status, 
        signature, risk_agreement, aml_agreement, create_time, update_time
    </sql>
    
    <!-- 通用查询：无差异，使用统一语法 -->
    <select id="findById" parameterType="java.lang.Long" resultMap="UserResultMap">
        SELECT <include refid="Base_Column_List"/>
        FROM "user"  <!-- 双引号兼容两个数据库 -->
        WHERE id = #{id}
    </select>
    
    <!-- 需要区分的查询：INSERT with 时间函数 -->
    <!-- MySQL版本 -->
    <insert id="insert" databaseId="mysql" parameterType="com.binaryoption.commonservice.domain.User" 
            useGeneratedKeys="true" keyProperty="id">
        INSERT INTO user (
            external_id, password, nickname, email, phone, status, 
            signature, risk_agreement, aml_agreement, create_time, update_time
        ) VALUES (
            #{externalId}, #{password}, #{nickname}, #{email}, #{phone}, #{status},
            #{signature}, #{riskAgreement}, #{amlAgreement}, NOW(), NOW()
        )
    </insert>
    
    <!-- PostgreSQL版本 -->
    <insert id="insert" databaseId="postgresql" parameterType="com.binaryoption.commonservice.domain.User" 
            useGeneratedKeys="true" keyProperty="id">
        INSERT INTO "user" (
            external_id, password, nickname, email, phone, status, 
            signature, risk_agreement, aml_agreement, create_time, update_time
        ) VALUES (
            #{externalId}, #{password}, #{nickname}, #{email}, #{phone}, #{status},
            #{signature}, #{riskAgreement}, #{amlAgreement}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
    </insert>
    
    <!-- 需要区分的查询：UPDATE with 时间函数 -->
    <!-- MySQL版本 -->
    <update id="update" databaseId="mysql" parameterType="com.binaryoption.commonservice.domain.User">
        UPDATE user
        <set>
            <if test="externalId != null">external_id = #{externalId},</if>
            <if test="password != null">password = #{password},</if>
            <if test="nickname != null">nickname = #{nickname},</if>
            <if test="email != null">email = #{email},</if>
            <if test="phone != null">phone = #{phone},</if>
            <if test="status != null">status = #{status},</if>
            <if test="signature != null">signature = #{signature},</if>
            <if test="riskAgreement != null">risk_agreement = #{riskAgreement},</if>
            <if test="amlAgreement != null">aml_agreement = #{amlAgreement},</if>
            update_time = NOW()
        </set>
        WHERE id = #{id}
    </update>
    
    <!-- PostgreSQL版本 -->
    <update id="update" databaseId="postgresql" parameterType="com.binaryoption.commonservice.domain.User">
        UPDATE "user"
        <set>
            <if test="externalId != null">external_id = #{externalId},</if>
            <if test="password != null">password = #{password},</if>
            <if test="nickname != null">nickname = #{nickname},</if>
            <if test="email != null">email = #{email},</if>
            <if test="phone != null">phone = #{phone},</if>
            <if test="status != null">status = #{status},</if>
            <if test="signature != null">signature = #{signature},</if>
            <if test="riskAgreement != null">risk_agreement = #{riskAgreement},</if>
            <if test="amlAgreement != null">aml_agreement = #{amlAgreement},</if>
            update_time = CURRENT_TIMESTAMP
        </set>
        WHERE id = #{id}
    </update>
    
    <!-- 需要区分的查询：分页查询 -->
    <!-- MySQL版本 -->
    <select id="findAll" databaseId="mysql" resultMap="UserResultMap">
        SELECT <include refid="Base_Column_List"/>
        FROM user
        ORDER BY id DESC
        LIMIT #{offset}, #{limit}
    </select>
    
    <!-- PostgreSQL版本 -->
    <select id="findAll" databaseId="postgresql" resultMap="UserResultMap">
        SELECT <include refid="Base_Column_List"/>
        FROM "user"
        ORDER BY id DESC
        LIMIT #{limit} OFFSET #{offset}
    </select>
    
</mapper>
```

### 5.2 AccountMapper.xml改造要点

```xml
<!-- 需要修改的语句类型 -->
<!-- 1. 所有包含 NOW() 的INSERT/UPDATE语句 -->
<!-- 2. 所有包含 LIMIT offset, limit 的分页查询 -->
<!-- 3. 表名统一使用双引号（如果不是保留字可选） -->

<!-- MySQL版本示例 -->
<update id="updateBalance" databaseId="mysql">
    UPDATE account
    SET 
        balance = #{balance},
        frozen_balance = #{frozenAmount},
        update_time = NOW()
    WHERE id = #{id}
</update>

<!-- PostgreSQL版本示例 -->
<update id="updateBalance" databaseId="postgresql">
    UPDATE account
    SET 
        balance = #{balance},
        frozen_balance = #{frozenAmount},
        update_time = CURRENT_TIMESTAMP
    WHERE id = #{id}
</update>
```

## 6. 工具类辅助方案

为减少Mapper中重复代码，可以创建数据库方言工具类：

```java
@Component
public class DatabaseDialectHelper {
    
    @Value("${mybatis.configuration.database-id:mysql}")
    private String databaseId;
    
    /**
     * 获取当前时间戳函数
     */
    public String getCurrentTimestamp() {
        return "mysql".equals(databaseId) ? "NOW()" : "CURRENT_TIMESTAMP";
    }
    
    /**
     * 格式化分页SQL
     */
    public String formatLimitSql(int offset, int limit) {
        if ("mysql".equals(databaseId)) {
            return String.format("LIMIT %d, %d", offset, limit);
        } else {
            return String.format("LIMIT %d OFFSET %d", limit, offset);
        }
    }
    
    /**
     * 获取用户表名（处理保留字）
     */
    public String getUserTableName() {
        return "mysql".equals(databaseId) ? "user" : "\"user\"";
    }
}
```

在Service层使用：
```java
@Service
public class UserService {
    
    @Autowired
    private DatabaseDialectHelper dialectHelper;
    
    public void example() {
        String currentTime = dialectHelper.getCurrentTimestamp();
        String tableName = dialectHelper.getUserTableName();
        // 可以在动态SQL中使用
    }
}
```

## 7. 部署配置

### 7.1 Profile配置

```bash
# 启动MySQL版本
java -jar option-common-service.jar --spring.profiles.active=mysql

# 启动PostgreSQL版本
java -jar option-common-service.jar --spring.profiles.active=postgresql
```

### 7.2 Docker环境

```yaml
# docker-compose.yml
version: '3.8'
services:
  common-service-mysql:
    image: option-common-service:latest
    environment:
      - SPRING_PROFILES_ACTIVE=mysql
    profiles: ["mysql"]
    
  common-service-postgresql:
    image: option-common-service:latest
    environment:
      - SPRING_PROFILES_ACTIVE=postgresql
    profiles: ["postgresql"]
    
  mysql:
    image: mysql:8.0
    profiles: ["mysql"]
    
  postgresql:
    image: postgres:13
    environment:
      - POSTGRES_DB=binary_option
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=root
    ports:
      - "5433:5432"
    profiles: ["postgresql"]
```

使用：
```bash
# 启动PostgreSQL环境
docker-compose --profile postgresql up

# 启动MySQL环境
docker-compose --profile mysql up
```

## 8. 测试策略

### 8.1 集成测试

修改现有测试脚本支持数据库选择：

```bash
# test-scripts/common-service-test.sh
#!/bin/bash

DB_TYPE=${1:-mysql}  # 默认MySQL

if [ "$DB_TYPE" = "postgresql" ]; then
    export SPRING_PROFILES_ACTIVE=postgresql
    export DB_URL="jdbc:postgresql://localhost:5433/binary_option"
else
    export SPRING_PROFILES_ACTIVE=mysql
    export DB_URL="jdbc:mysql://localhost:3306/binary_option"
fi

echo "Testing with database: $DB_TYPE"
# 运行具体测试...
```

## 9. 实施计划

### 9.1 阶段一：基础设施准备（1天）
1. 创建Profile配置文件
2. 添加PostgreSQL驱动依赖
3. 配置MyBatis databaseId

### 9.2 阶段二：Mapper改造（2天）
1. **UserMapper.xml改造**
   - 修改17处NOW()函数
   - 修改2处分页查询
   - 处理user表名引用
   
2. **AccountMapper.xml改造**
   - 修改所有UPDATE语句的NOW()
   - 保持其他查询不变
   
3. **其他Mapper改造**
   - BtseTransferLogMapper.xml
   - SymbolConfigMapper.xml
   - AccountTransactionMapper.xml

### 9.3 阶段三：测试验证（1天）
1. 集成测试两个数据库
2. 现有测试脚本适配
3. 基本功能验证测试

### 9.4 阶段四：推广到其他服务（按需）
1. option-order-service
2. option-admin-service
3. option-market-service

## 10. 注意事项

### 10.1 SQL兼容性建议

1. **优先使用标准SQL**：避免数据库特定函数
2. **表名统一处理**：PostgreSQL保留字用双引号
3. **数据类型注意**：TINYINT在PostgreSQL中为SMALLINT
4. **索引名称**：避免过长索引名导致PostgreSQL截断

### 10.2 性能考虑

1. **编译时确定**：MyBatis databaseId机制在编译时确定SQL，无运行时性能损失
2. **连接池配置**：不同数据库连接池参数需要调优
3. **监控指标**：两个数据库的监控指标可能不同

### 10.3 维护建议

1. **代码审查**：新增SQL必须同时支持两个数据库
2. **CI/CD集成**：自动化测试必须覆盖两个数据库
3. **文档同步**：SQL变更必须更新本文档

## 11. FAQ

### Q: 为什么选择MyBatis databaseId而不是其他方案？
A: MyBatis databaseId是官方推荐的多数据库方案，编译时确定SQL，性能无损失，维护成本最低。

### Q: 所有SQL都需要写两遍吗？
A: 不是。只有存在数据库差异的SQL才需要分别实现，大部分通用查询可以共用。

### Q: 如何保证两个数据库的数据一致性？
A: 本方案是单一数据库部署，在应用层面选择数据库类型，不涉及数据同步问题。

### Q: 升级MyBatis版本会影响兼容性吗？
A: databaseId是MyBatis核心特性，版本升级不会影响兼容性。

## 12. 结论

通过MyBatis的databaseId机制，可以优雅地实现MySQL和PostgreSQL的兼容支持。该方案具有代码侵入小、性能无损失、维护成本低的特点，适合作为整个项目数据库兼容的标准方案。

建议首先在option-common-service中实施该方案，验证效果后推广到其他微服务模块。