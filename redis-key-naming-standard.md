# Redis Key 命名规范标准

## 设计原则

### 1. 一致性原则
- 所有key使用统一的命名格式和分隔符
- 避免大小写混用，统一使用小写
- 业务模块分层清晰

### 2. 可读性原则  
- key名称能够直观反映其用途和内容
- 层级结构清晰，便于理解和维护
- 避免缩写，使用完整的英文单词

### 3. 扩展性原则
- 支持未来业务模块的扩展
- 预留足够的命名空间
- 便于添加新的业务类型

## 命名格式标准

### 基础格式
```
{project}:{module}:{business}:{type}:{identifier}
```

### 各部分说明

#### 1. Project (项目前缀)
- **固定值**: `bo` (Binary Option缩写)
- **规则**: 全小写，标识整个项目

#### 2. Module (业务模块)
- **用户模块**: `user` - 用户相关功能
- **认证模块**: `auth` - 认证、授权、会话管理
- **订单模块**: `order` - 订单处理、结算、风控
- **市场模块**: `market` - 行情数据、K线、交易对
- **配置模块**: `config` - 系统配置、参数设置
- **风控模块**: `risk` - 风险管理、黑名单、限制

#### 3. Business (业务场景)
- **用户相关**: `profile`, `stats`, `balance`, `transaction`
- **认证相关**: `token`, `session`, `mapping`, `permission`, `role`
- **订单相关**: `settlement`, `hedge`, `round`, `statistics`
- **市场相关**: `symbols`, `kline`, `tick`, `realtime`
- **配置相关**: `global`, `symbol`, `duration`, `risk`

#### 4. Type (数据类型)
- **cache**: 缓存数据 (最常用)
- **lock**: 分布式锁
- **session**: 会话数据
- **temp**: 临时数据
- **list**: 列表数据
- **hash**: 哈希数据
- **set**: 集合数据
- **counter**: 计数器

#### 5. Identifier (标识符)
- 具体的ID、名称或参数
- 支持多层级: `{id1}:{id2}`
- 特殊标识: `all`, `active`, `default`

## 具体应用示例

### 认证模块 (auth)
```
bo:auth:token:cache:{token}           # OAuth访问令牌
bo:auth:mapping:cache:{username}      # 用户名到ID的映射
bo:auth:session:cache:{userId}        # 用户会话信息  
bo:auth:permission:cache:{userId}     # 用户权限缓存
bo:auth:role:cache:{userId}           # 用户角色缓存
```

### 用户模块 (user)
```
bo:user:profile:cache:{userId}        # 用户基本信息
bo:user:stats:cache:{userId}          # 用户统计数据
bo:user:balance:cache:{userId}:{type} # 用户余额信息
```

### 订单模块 (order)  
```
bo:order:settlement:lock:task         # 结算任务锁
bo:order:hedge:lock:compensation      # 对冲补偿锁
bo:order:round:lock:maintenance       # 轮次维护锁
bo:order:stats:cache:{userId}         # 用户订单统计
```

### 市场模块 (market)
```
bo:market:symbols:cache:active        # 活跃交易对列表
bo:market:symbol:cache:{symbol}       # 单个交易对配置
bo:market:kline:cache:{symbol}:{period} # K线数据
bo:market:tick:cache:{symbol}         # 实时行情
```

### 配置模块 (config)
```
bo:config:global:cache:{key}          # 全局配置
bo:config:symbol:cache:{symbol}       # 交易对配置
bo:config:risk:cache:{type}           # 风控配置
```

### 风控模块 (risk)
```
bo:risk:blacklist:cache:active        # 活跃黑名单
bo:risk:stats:cache:{userId}          # 用户风控统计
bo:risk:limit:cache:{api}:{identifier} # API限流
```

## Spring Cache注解适配

### Cache Names (用于@Cacheable的value属性)
```java
// 格式: {project}:{module}:{business}
String CACHE_AUTH_TOKEN = "bo:auth:token";
String CACHE_USER_PROFILE = "bo:user:profile"; 
String CACHE_MARKET_SYMBOLS = "bo:market:symbols";
String CACHE_ORDER_STATS = "bo:order:stats";
```

### Cache Keys (用于@Cacheable的key属性)
```java
// 使用单引号包围，支持SpEL表达式
String KEY_ACTIVE = "'active'";
String KEY_BY_ID = "'cache:' + #id";
String KEY_BY_SYMBOL = "'cache:' + #symbol";
```

## 迁移对照表

| 旧Key格式 | 新Key格式 | 说明 |
|----------|-----------|------|
| `BO:User:Mapping:{username}` | `bo:auth:mapping:cache:{username}` | 用户映射缓存 |
| `OAuth:AccessToken:{token}` | `bo:auth:token:cache:{token}` | OAuth令牌 |
| `auth:permissions:user:{userId}` | `bo:auth:permission:cache:{userId}` | 用户权限 |
| `auth:roles:user:{userId}` | `bo:auth:role:cache:{userId}` | 用户角色 |
| `bo:symbols::active_v2` | `bo:market:symbols:cache:active` | 活跃交易对 |
| `bo:symbol::v2_{symbol}` | `bo:market:symbol:cache:{symbol}` | 交易对配置 |
| `bo:order:settlement:task` | `bo:order:settlement:lock:task` | 结算任务锁 |
| `market:tick:{symbol}` | `bo:market:tick:cache:{symbol}` | 实时行情 |
| `market:kline:{symbol}:{period}` | `bo:market:kline:cache:{symbol}:{period}` | K线数据 |

## 命名规范检查清单

### 必须遵守
- [ ] 使用统一的5段式格式
- [ ] 全部使用小写字母
- [ ] 使用冒号(:)作为分隔符
- [ ] 业务模块分类正确
- [ ] 数据类型标识准确

### 建议遵守  
- [ ] 避免使用缩写
- [ ] 标识符具有业务含义
- [ ] 支持未来扩展
- [ ] 文档清晰完整

## 工具方法设计

```java
public interface CacheConstants {
    // 基础构建方法
    static String buildKey(String module, String business, String type, String identifier) {
        return String.join(":", PROJECT_PREFIX, module, business, type, identifier);
    }
    
    // 特定业务方法
    static String buildAuthTokenKey(String token) {
        return buildKey("auth", "token", "cache", token);
    }
    
    static String buildUserMappingKey(String username) {
        return buildKey("auth", "mapping", "cache", username);
    }
    
    static String buildMarketSymbolKey(String symbol) {
        return buildKey("market", "symbol", "cache", symbol);
    }
}
```

## 版本控制

- **当前版本**: v2.0
- **升级时间**: 2025-09-17
- **向后兼容**: 通过别名支持旧格式(临时)
- **完全切换**: 预计1个月内完成

## 监控和维护

1. **Key扫描**: 定期扫描Redis中的key，检查命名规范遵守情况
2. **性能监控**: 监控key的访问频率和性能影响
3. **文档更新**: 及时更新key的使用文档和示例
4. **团队培训**: 确保所有开发人员理解和遵守新规范