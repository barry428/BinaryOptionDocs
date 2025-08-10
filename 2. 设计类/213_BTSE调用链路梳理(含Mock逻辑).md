# BTSE API 调用链路梳理（含Mock逻辑）

## 1. 架构概述

### 1.1 整体架构
```
前端/测试脚本
    ↓
UserTransferController (用户主动转账API)
    ↓
BtseTransferService (业务逻辑层)
    ↓
BtseApiClient接口 (抽象层)
    ↓
[根据配置选择实现]
    ├── BtseApiClientImpl (真实API调用)
    └── BtseMockApiClient (Mock模拟)
```

### 1.2 Mock控制机制
- **配置项**: `btse.mock.enabled`
- **默认值**: `false` (使用真实API)
- **切换方式**: 修改 `application.yml` 或环境变量

### 1.3 Spring条件化Bean机制详解

#### 为什么一个配置就能切换Mock和真实实现？

**核心原理**：Spring的`@ConditionalOnProperty`注解会在启动时根据配置决定创建哪个Bean。

**决策流程**：
```
Spring Boot启动
    ↓
读取配置文件 (application.yml)
    ↓
发现配置: btse.mock.enabled = true/false
    ↓
扫描所有@Component类
    ↓
发现两个BtseApiClient实现：
    ├── BtseApiClientImpl 
    │   └── @ConditionalOnProperty(name = "btse.mock.enabled", havingValue = "false", matchIfMissing = true)
    │       含义：当btse.mock.enabled=false或不存在时，创建这个Bean
    │
    └── BtseMockApiClient
        └── @ConditionalOnProperty(name = "btse.mock.enabled", havingValue = "true")
            含义：只有当btse.mock.enabled=true时，才创建这个Bean
    ↓
根据配置值决定：
    - 如果 btse.mock.enabled = true  → 只创建 BtseMockApiClient
    - 如果 btse.mock.enabled = false → 只创建 BtseApiClientImpl
    - 如果 没有配置这个属性        → 创建 BtseApiClientImpl (因为matchIfMissing = true)
```

**具体示例**：

场景1：启用Mock模式
```yaml
btse:
  mock:
    enabled: true
```
- BtseApiClientImpl的条件判断：`true` ≠ `false` → ❌ 不创建
- BtseMockApiClient的条件判断：`true` = `true` → ✅ 创建
- 结果：Spring容器中只有BtseMockApiClient

场景2：使用真实API
```yaml
btse:
  mock:
    enabled: false
```
- BtseApiClientImpl的条件判断：`false` = `false` → ✅ 创建
- BtseMockApiClient的条件判断：`false` ≠ `true` → ❌ 不创建
- 结果：Spring容器中只有BtseApiClientImpl

**依赖注入时**：
```java
@Service
public class BtseTransferService {
    @Autowired
    private BtseApiClient btseApiClient;  // Spring自动注入唯一存在的实现
    
    // 运行时调用的是Mock或真实实现，取决于启动时的配置
}
```

## 2. 核心组件详解

### 2.1 配置层

#### BtseConfig.java
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/integration/BtseConfig.java`
**作用**: BTSE配置管理
```java
@ConfigurationProperties(prefix = "btse")
public class BtseConfig {
    private Api api;      // API配置（URL、认证、超时等）
    private Mock mock;    // Mock配置（启用开关、场景、延迟等）
}
```

#### BtseIntegrationConfig.java
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/config/BtseIntegrationConfig.java`
**作用**: 配置RestTemplate
```java
@Bean(name = "btseRestTemplate")
public RestTemplate btseRestTemplate() {
    // 配置超时、拦截器等
}
```

### 2.2 API客户端层

#### BtseApiClient.java (接口)
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/integration/BtseApiClient.java`
**核心方法**:
```java
public interface BtseApiClient {
    // 用户认证
    BtseAuthResponse authenticateUser(BtseAuthRequest request);
    
    // 余额查询
    BtseBalanceResponse getBalance(String userId, String currency);
    
    // 资金划转
    BtseTransferResponse transfer(BtseTransferRequest request);
    
    // 划转状态查询
    BtseTransferStatusResponse getTransferStatus(String transferId);
}
```

#### BtseApiClientImpl.java (真实实现)
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/integration/BtseApiClientImpl.java`
**特点**:
- 使用 `@Primary` 和 `@ConditionalOnProperty(name = "btse.mock.enabled", havingValue = "false", matchIfMissing = true)`
- 调用真实的BTSE API
- 处理签名认证、错误重试等

#### BtseMockApiClient.java (Mock实现)
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/integration/BtseMockApiClient.java`
**特点**:
- 使用 `@Primary` 和 `@ConditionalOnProperty(name = "btse.mock.enabled", havingValue = "true")`
- 模拟API响应，不调用真实API
- 支持配置失败率、延迟等场景

### 2.3 业务服务层

#### BtseTransferService.java
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/service/BtseTransferService.java`
**核心方法**:
```java
public class BtseTransferService {
    @Autowired
    private BtseApiClient btseApiClient; // 自动注入（真实或Mock）
    
    // 从BTSE转入
    public BtseTransferResponse transferFromBtse(Long userId, String accountType, 
                                                BigDecimal amount, Long orderId, String description) {
        // 1. 参数验证
        // 2. 调用btseApiClient.getBalance()检查余额
        // 3. 调用btseApiClient.transfer()执行转账
        // 4. 更新本地账户余额 (accountService.addBalance)
        // 5. 记录转账日志 (btse_transfer_log表)
    }
    
    // 转出到BTSE
    public BtseTransferResponse transferToBtse(Long userId, String accountType, 
                                              BigDecimal amount, String reason) {
        // 1. 参数验证
        // 2. 检查本地余额
        // 3. 扣减本地余额 (accountService.subtractBalance)
        // 4. 调用btseApiClient.transfer()执行转账
        // 5. 记录转账日志
    }
}
```

### 2.4 控制器层

#### UserTransferController.java
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/controller/UserTransferController.java`
**端点**:
- `POST /api/account/transfer/from-btse` - 从BTSE转入
- `POST /api/account/transfer/to-btse` - 转出到BTSE
- `GET /api/account/transfer/history` - 查询转账历史

#### BtseTransferRpcController.java
**位置**: `option-common-service/src/main/java/com/binaryoption/commonservice/rpc/BtseTransferRpcController.java`
**内部RPC端点**:
- `/rpc/btse-transfer/check-balance` - 检查BTSE余额
- `/rpc/btse-transfer/transfer-from-btse` - 内部转入调用
- `/rpc/btse-transfer/transfer-to-btse` - 内部转出调用

## 3. 调用链路示例

### 3.1 用户主动转入（从BTSE到系统）

```
1. 用户调用: POST /api/account/transfer/from-btse
   └── UserTransferController.transferFromBtse()
       └── BtseTransferService.transferFromBtse()
           ├── validateTransferParams() // 参数验证
           ├── btseApiClient.getBalance() // 检查BTSE余额
           │   └── [真实API] 或 [Mock返回模拟余额]
           ├── btseApiClient.transfer() // 执行BTSE转账
           │   └── [真实API] 或 [Mock返回成功]
           ├── accountService.addBalance() // 增加本地余额
           │   └── 更新account表 + 记录account_transaction
           └── recordBtseTransferLog() // 记录btse_transfer_log
```

### 3.2 用户主动转出（从系统到BTSE）

```
1. 用户调用: POST /api/account/transfer/to-btse
   └── UserTransferController.transferToBtse()
       └── BtseTransferService.transferToBtse()
           ├── validateTransferParams() // 参数验证
           ├── accountService.hasEnoughBalance() // 检查本地余额
           ├── accountService.subtractBalance() // 扣减本地余额
           │   └── 更新account表 + 记录account_transaction
           ├── btseApiClient.transfer() // 执行BTSE转账
           │   └── [真实API] 或 [Mock返回成功]
           └── recordBtseTransferLog() // 记录btse_transfer_log
```

## 4. Mock逻辑详解

### 4.1 为什么需要Mock？

**开发阶段的痛点**：
1. **BTSE API未就绪**：外部API可能还在开发中
2. **没有测试账号**：需要真实的BTSE账号和资金
3. **网络限制**：开发环境可能无法访问BTSE服务器
4. **调试困难**：真实API调用难以复现特定场景
5. **成本问题**：频繁调用真实API可能产生费用

**Mock的优势**：
- ✅ 无需真实BTSE账号
- ✅ 可以模拟各种异常场景
- ✅ 响应速度快，便于调试
- ✅ 数据可控，便于测试
- ✅ 零成本，无限调用

### 4.2 Mock配置
```yaml
btse:
  mock:
    enabled: true  # 启用Mock
    scenarios:
      authFailureRate: 0.05        # 5%认证失败
      transferFailureRate: 0.02    # 2%转账失败
      balanceInsufficientRate: 0.1 # 10%余额不足
      apiTimeoutRate: 0.01         # 1%超时
    delays:
      minDelay: 100      # 最小延迟100ms
      maxDelay: 1000     # 最大延迟1000ms
      averageDelay: 300  # 平均延迟300ms
```

### 4.2 BtseMockApiClient实现逻辑

#### 余额查询Mock
```java
public BtseBalanceResponse getBalance(String userId, String currency) {
    // 1. 模拟延迟
    simulateDelay();
    
    // 2. 根据配置返回失败场景
    if (shouldSimulateFailure("balance")) {
        throw new BtseApiException("Mock balance query failed");
    }
    
    // 3. 返回模拟余额（基于userId的固定值或随机值）
    return mockBalanceResponse(userId, currency);
}
```

#### 转账Mock
```java
public BtseTransferResponse transfer(BtseTransferRequest request) {
    // 1. 模拟延迟
    simulateDelay();
    
    // 2. 检查是否模拟失败
    if (shouldSimulateTransferFailure()) {
        return failedTransferResponse();
    }
    
    // 3. 更新内存中的模拟余额
    updateMockBalance(request);
    
    // 4. 返回成功响应
    return successTransferResponse(generateTransferId());
}
```

## 5. 数据流转

### 5.1 数据库表
- **account**: 本地账户余额
- **account_transaction**: 账户交易流水
- **btse_transfer_log**: BTSE转账记录

### 5.2 状态流转
```
转入流程:
BTSE余额 → [API/Mock] → 系统验证 → 本地余额增加 → 记录流水

转出流程:
本地余额 → 扣减 → [API/Mock] → BTSE余额增加 → 记录流水
```

## 6. 异常处理

### 6.1 异常类型
- `BtseApiException`: BTSE API调用异常
- `BusinessException`: 业务逻辑异常
- `InsufficientBalanceException`: 余额不足

### 6.2 异常处理链
```
BtseApiClient异常
    ↓
BtseTransferService捕获并记录
    ↓
返回失败响应给Controller
    ↓
统一异常处理返回给前端
```

## 7. 监控与日志

### 7.1 监控组件
- **BtseMonitoringService**: 监控服务
- **BtseMonitoringController**: 监控端点
- **BtseExceptionHandlerService**: 异常处理服务

### 7.2 日志记录
- 所有API调用都记录请求和响应
- 异常情况记录详细错误信息
- Mock模式下特别标记为"[MOCK]"

## 8. 测试建议

### 8.1 如何验证当前使用的实现？

**方法1：查看启动日志**
```java
@Service
public class BtseTransferService {
    @Autowired
    private BtseApiClient btseApiClient;
    
    @PostConstruct
    public void init() {
        log.info("BTSE API Client实现类: {}", btseApiClient.getClass().getSimpleName());
        // Mock模式输出: BtseMockApiClient
        // 真实模式输出: BtseApiClientImpl
    }
}
```

**方法2：查看Spring Bean**
```bash
# 通过Spring Actuator端点查看
curl http://localhost:8081/actuator/beans | grep -A 5 "btseApiClient"
```

**方法3：观察API响应**
- Mock响应通常包含 "Mock" 字样
- Mock响应速度非常快（无网络延迟）
- Mock数据通常是固定或可预测的

### 8.2 Mock模式测试
1. 设置 `btse.mock.enabled=true`
2. 运行测试脚本 `test-scripts/simple-flow-test.sh`
3. 验证转入转出功能正常
4. 日志中应该看到 "[MOCK]" 标记

### 8.3 真实API测试
1. 设置 `btse.mock.enabled=false`
2. 配置真实的API Key和Secret
3. 使用测试环境进行验证
4. 注意网络连接和API限流

### 8.4 切换测试
```bash
# 使用Mock模式
export BTSE_MOCK_ENABLED=true
./test-scripts/simple-flow-test.sh

# 使用真实API
export BTSE_MOCK_ENABLED=false
./test-scripts/simple-flow-test.sh
```

## 9. 注意事项

1. **生产环境**: 必须设置 `btse.mock.enabled=false`
2. **API密钥**: 真实环境需要配置有效的API Key和Secret
3. **网络要求**: 真实API调用需要能访问BTSE服务器
4. **Mock数据**: Mock模式下的数据不会持久化，重启后重置
5. **并发安全**: Mock实现需要考虑线程安全

## 10. 扩展点

- 可以实现更复杂的Mock场景
- 可以添加Mock数据持久化
- 可以实现Mock数据的Web管理界面
- 可以添加更多的监控指标

## 11. 常见问题（FAQ）

### Q1: 为什么两个实现类都标记了@Primary？
**A**: 虽然由于`@ConditionalOnProperty`的存在，同一时间只会有一个Bean被创建，但标记`@Primary`是个好习惯：
- 明确表示这个Bean应该是首选的
- 防止未来如果有其他实现类加入时产生歧义
- 提高代码可读性

### Q2: 如果忘记配置btse.mock.enabled会怎样？
**A**: 会使用真实API实现（BtseApiClientImpl），因为它的注解中有`matchIfMissing = true`。

### Q3: 能否在运行时动态切换Mock和真实API？
**A**: 不能。Spring的条件化Bean是在启动时决定的，运行时无法切换。如需切换，必须重启应用。

### Q4: Mock数据会持久化吗？
**A**: 当前实现中，Mock数据存储在内存中，重启后会重置。如需持久化，可以扩展Mock实现。

### Q5: 如何添加新的Mock场景？
**A**: 在`BtseMockApiClient`中添加新的场景逻辑，并在`btse.mock.scenarios`配置中添加相应参数。

### Q6: Mock模式下的性能如何？
**A**: Mock模式性能很好，因为：
- 无网络I/O
- 数据在内存中
- 可配置的模拟延迟（用于测试慢速网络）

### Q7: 生产环境如何确保不会误用Mock？
**A**: 
- 生产配置文件中明确设置 `btse.mock.enabled=false`
- 可以通过启动脚本强制覆盖配置
- 添加启动检查，生产环境禁止Mock

### Q8: 如何调试Mock和真实API的差异？
**A**: 
- 启用详细日志记录
- Mock模式日志带[MOCK]标记
- 对比相同操作在两种模式下的日志

---

*最后更新: 2024-12-10*
*作者: Claude Assistant*