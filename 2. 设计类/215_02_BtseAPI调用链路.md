# BTSE API 调用链路文档

## 概述

本文档详细描述了二元期权交易平台中 BTSE External Order API 的完整调用链路，从业务层入口到最终的 API 调用。

## 系统架构图

```
┌─────────────────┐    RPC     ┌──────────────────┐    API     ┌─────────────┐
│ order-service   │ ────────▶ │ common-service   │ ────────▶ │ BTSE API    │
│ 订单服务        │           │ 公共服务          │           │ 外部接口     │
└─────────────────┘           └──────────────────┘           └─────────────┘
```

## 主要调用场景

### 1. 轮次结算转出（ROUND_OUT）

**业务场景**：轮次结算完成后，将盈利资金转出到 BTSE

#### 调用链路：

```
OrderSettlementService.executeRoundMergedTransferOut()
  ↓ RPC调用
BtseTransferRpcClient.transferToBtseWithRound()
  ↓ HTTP请求
BtseTransferRpcController.transferToBtseWithRound()
  ↓ 业务处理
BtseTransferService.transferToBtseWithRound()
  ↓ 内部调用
BtseTransferService.executeBtseTransferOut()
  ↓ 接口调用
BtseApiClient.transfer()
  ↓ 实现选择
BtseApiClientImpl.transfer() [真实环境]
BtseMockApiClient.transfer() [Mock环境]
  ↓ 方法路由
BtseApiClientImpl.callSettlementExternalOrder()
  ↓ HTTP请求
BTSE API: POST /ext-orders/settlement
```

#### 详细文件路径：

1. **入口方法**
   - 文件：`/option-order-service/src/main/java/com/binaryoption/orderservice/service/OrderSettlementService.java`
   - 方法：`executeRoundMergedTransferOut(Long userId, String accountType, BigDecimal totalAmount, BigDecimal netProfit, Long roundId)`

2. **RPC 客户端**
   - 文件：`/option-order-service/src/main/java/com/binaryoption/orderservice/client/BtseTransferRpcClient.java`
   - 方法：`transferToBtseWithRound(Long userId, String accountType, BigDecimal amount, String reason, Long roundId, BigDecimal totalAmount, BigDecimal netProfit)`

3. **RPC 控制器**
   - 文件：`/option-common-service/src/main/java/com/binaryoption/commonservice/rpc/BtseTransferRpcController.java`
   - 方法：`transferToBtseWithRound(@RequestParam...)`

4. **业务服务**
   - 文件：`/option-common-service/src/main/java/com/binaryoption/commonservice/service/BtseTransferService.java`
   - 方法：`transferToBtseWithRound(Long userId, String accountType, BigDecimal amount, String reason, Long roundId, BigDecimal totalAmount, BigDecimal netProfit)`

5. **API 客户端**
   - 文件：`/option-common-service/src/main/java/com/binaryoption/commonservice/integration/BtseApiClientImpl.java`
   - 方法：`callSettlementExternalOrder(BtseTransferRequestDTO request)`

#### 参数映射：

```json
{
  "extRequestId": "btse_transfer_log.id:123456",
  "username": "user_nickname", 
  "currency": "USDT",
  "totalOrderAmount": "1000.00",     // totalAmount 参数
  "totalOrderBonusAmount": "0",      // 第一阶段固定为0
  "pnlAmount": "200.00",             // netProfit 参数
  "pnlBonusAmount": "0",             // 第一阶段固定为0
  "extRefId": "123456"               // btse_transfer_log.id
}
```

### 2. 订单转入（ORDER_IN）

**业务场景**：用户下单时，从 BTSE 转入资金到系统账户

#### 调用链路：

```
[业务触发] 订单创建流程
  ↓ 业务调用
BtseTransferService.transferFromBtse()
  ↓ 内部调用
BtseTransferService.executeTransferWithRetry()
  ↓ 接口调用
BtseApiClient.transfer()
  ↓ 实现选择
BtseApiClientImpl.transfer()
  ↓ 方法路由 (ORDER_IN)
BtseApiClientImpl.callCreateExternalOrder()
  ↓ HTTP请求
BTSE API: PUT /ext-orders/create
```

#### 详细文件路径：

1. **服务入口**
   - 文件：`/option-common-service/src/main/java/com/binaryoption/commonservice/service/BtseTransferService.java`
   - 方法：`transferFromBtse(Long userId, String accountType, BigDecimal amount, Long orderId, String description)`

2. **重试逻辑**
   - 文件：同上
   - 方法：`executeTransferWithRetry(BtseTransferLog transferLog)`

3. **API 实现**
   - 文件：`/option-common-service/src/main/java/com/binaryoption/commonservice/integration/BtseApiClientImpl.java`
   - 方法：`callCreateExternalOrder(BtseTransferRequestDTO request)`

#### 参数映射：

```json
{
  "extRequestId": "btse_transfer_log.id:123456",
  "username": "user_nickname",
  "currency": "USDT", 
  "amount": "100.00",
  "bonusAmount": "0",
  "extRefId": "123456"
}
```

### 3. 订单取消转出（ORDER_OUT）

**业务场景**：订单取消或失败时，退回资金到 BTSE

#### 调用链路：

```
[业务触发] 订单取消/失败
  ↓ 业务调用
BtseTransferService.transferToBtse() / transferToBtseWithOrder()
  ↓ 内部调用
BtseTransferService.executeBtseTransferOut()
  ↓ 接口调用
BtseApiClient.transfer()
  ↓ 实现选择
BtseApiClientImpl.transfer()
  ↓ 方法路由 (ORDER_OUT)
BtseApiClientImpl.callCancelExternalOrder()
  ↓ HTTP请求
BTSE API: PUT /ext-orders/cancel
```

#### 参数映射：

```json
{
  "extRequestId": "btse_transfer_log.id:123456",
  "username": "user_nickname",
  "currency": "USDT",
  "amount": "100.00", 
  "bonusAmount": "0",
  "extRefId": "123456"
}
```

### 4. 转账状态查询

**业务场景**：补偿机制或状态确认时查询转账状态

#### 调用链路：

```
[补偿任务/状态查询]
  ↓ 业务调用
BtseTransferService.queryTransferStatus()
  ↓ 接口调用
BtseApiClient.getTransferStatus()
  ↓ 实现选择
BtseApiClientImpl.getTransferStatus()
  ↓ HTTP请求
BTSE API: GET /ext-orders/btse_transfer_log.id%3A123456
```

#### 详细文件路径：

1. **状态查询入口**
   - 文件：`/option-common-service/src/main/java/com/binaryoption/commonservice/service/BtseTransferService.java`
   - 方法：`queryTransferStatus(String transferId)` 
   - 调用点：`compensateTransferInRecord()`, `compensateTransferOutRecord()`

2. **API 实现**
   - 文件：`/option-common-service/src/main/java/com/binaryoption/commonservice/integration/BtseApiClientImpl.java`
   - 方法：`getTransferStatus(String transferId)`

#### URL 构建：

```java
// transferId = "123456" (普通ID)
String extRequestId = "btse_transfer_log.id:" + transferId;  // 拼接前缀
String url = baseUrl + "/ext-orders/" + URLEncoder.encode(extRequestId, "UTF-8");
// 最终URL: /ext-orders/btse_transfer_log.id%3A123456
```

## 关键技术点

### 1. 转账类型路由

在 `BtseApiClientImpl.transfer()` 方法中，根据 `transferType` 路由到不同的 API：

```java
if (BusinessConstants.TransferType.ORDER_IN.equals(request.getTransferType())) {
    return callCreateExternalOrder(request);        // PUT /ext-orders/create
} else if (BusinessConstants.TransferType.ORDER_OUT.equals(request.getTransferType())) {
    return callCancelExternalOrder(request);        // PUT /ext-orders/cancel  
} else if (BusinessConstants.TransferType.ROUND_OUT.equals(request.getTransferType())) {
    return callSettlementExternalOrder(request);    // POST /ext-orders/settlement
}
```

### 2. ID 格式处理

**业务层传递**：普通ID（如 "123456"）

**API 调用时拼接**：
- `extRequestId`: `"btse_transfer_log.id:123456"` 
- `extRefId`: `"123456"`

### 3. OAuth 认证

所有 External Order API 调用都需要 OAuth 认证：

```java
// 在 createAuthHeaders() 中获取访问令牌
String accessToken = getOrRefreshAccessToken();
headers.setBearerAuth(accessToken);
```

### 4. Mock 环境切换

通过配置项 `btse.mock.enabled` 切换实现：
- `true`: 使用 `BtseMockApiClient`
- `false`: 使用 `BtseApiClientImpl`

## 配置依赖

### 1. 服务配置

```yaml
# order-service 配置
feign:
  client:
    config:
      option-common-service:
        url: http://localhost:8081

# common-service 配置  
btse:
  mock:
    enabled: false  # 切换真实/Mock环境
  orderApi:
    baseUrl: https://api.btse.com
    oauth:
      clientId: your_client_id
      clientSecret: your_client_secret
```

### 2. 数据库表

转账记录存储在 `btse_transfer_log` 表：
- `id`: 主键，用于生成 extRequestId
- `trace_id`: 链路追踪ID  
- `user_id`: 用户ID
- `transfer_type`: 转账类型（ORDER_IN/ORDER_OUT/ROUND_OUT）
- `amount`: 转账金额
- `status`: 状态（PENDING/SUCCESS/FAILED）

## 错误处理与重试

### 1. 重试机制

```java
// 在 executeTransferWithRetry 和 executeBtseTransferOut 中
final int MAX_RETRY = 3;
final long RETRY_INTERVAL_MS = 1000; // 递增间隔：1s, 2s, 3s
```

### 2. 补偿机制

定时任务检查超时的 PENDING 记录：
- `compensatePendingTransferIn()`: 处理转入超时
- `compensatePendingTransferOut()`: 处理转出超时

## 监控与日志

### 1. 关键日志点

- 方法入口：记录请求参数
- API 调用前：记录请求体
- API 调用后：记录响应结果
- 异常处理：记录错误详情

### 2. 链路追踪

每个转账记录都有唯一的 `trace_id`，用于跨服务链路追踪。

## 总结

BTSE API 调用链路设计遵循分层架构原则：
- **业务层**：处理业务逻辑，传递简单参数
- **服务层**：处理转账逻辑，管理状态和重试
- **集成层**：处理API调用，格式转换和认证
- **传输层**：HTTP 请求和响应处理

整个链路具有良好的封装性、可测试性和可维护性。