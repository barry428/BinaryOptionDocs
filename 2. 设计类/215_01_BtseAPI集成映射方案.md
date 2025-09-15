# BTSE External Order API 集成映射方案

## 一、设计理念

将 BTSE External Order API 映射到系统通用的划转接口，保持系统的账户抽象层不变，便于未来接入其他账户系统。

## 二、API 映射关系

### 2.1 接口映射表

| 系统划转操作 | BTSE API | 说明 |
|------------|----------|------|
| 转入 (transferIn) | PUT /ext-orders/create | 从BTSE账户扣款，转入系统 |
| 转出 (transferOut) | PUT /ext-orders/cancel | 退回到BTSE账户 |
| 查询状态 (queryStatus) | GET /ext-orders/{extRequestId} | 查询划转状态 |
| 特殊转出 (settlement) | POST /ext-orders/settlement | 轮次结算专用 |

### 2.2 映射原理

- **转入逻辑**：`/ext-orders/create` 虽然名为"创建订单"，实际是从BTSE扣除资产，等同于转入系统
- **转出逻辑**：`/ext-orders/cancel` 虽然名为"取消订单"，实际是退回资产到BTSE，等同于转出系统
- **结算逻辑**：`/ext-orders/settlement` 是特殊的转出场景，用于轮次合并结算

## 三、实现方案

### 3.1 BtseApiClient 接口设计

```java
public interface BtseApiClient {
    
    // 通用转账接口（内部根据direction和场景调用不同API）
    BtseTransferResponseDTO transfer(BtseTransferRequestDTO request);
    
    // 查询转账状态
    BtseTransferStatusDTO getTransferStatus(String transferId);
    
    // 轮次结算（特殊场景）
    BtseTransferResponseDTO settlement(BtseSettlementRequestDTO request);
}
```

### 3.2 BtseApiClientImpl 实现逻辑

```java
@Override
public BtseTransferResponseDTO transfer(BtseTransferRequestDTO request) {
    // 根据direction判断调用哪个API
    if ("IN".equals(request.getDirection())) {
        // 转入：调用 /ext-orders/create
        return callCreateOrder(request);
    } else if ("OUT".equals(request.getDirection())) {
        // 转出：调用 /ext-orders/cancel
        return callCancelOrder(request);
    }
}

private BtseTransferResponseDTO callCreateOrder(BtseTransferRequestDTO request) {
    // PUT /ext-orders/create
    Map<String, Object> body = new HashMap<>();
    body.put("extRequestId", formatExtRequestId(request.getTransferId()));
    body.put("username", request.getUsername());
    body.put("currency", request.getCurrency());
    body.put("amount", request.getAmount().toString());
    body.put("extRefId", request.getReferId());
    // 调用API...
}

private BtseTransferResponseDTO callCancelOrder(BtseTransferRequestDTO request) {
    // PUT /ext-orders/cancel
    // 参数结构相同，只是API路径不同
}
```

## 四、业务流程映射

### 4.1 用户下单流程（转入）

```
用户下单
    ↓
BtseTransferService.transferFromBtse()
    ↓
BtseApiClient.transfer(direction="IN")
    ↓
内部调用 PUT /ext-orders/create
    ↓
从BTSE扣除资产（相当于转入系统）
```

### 4.2 订单失败退款流程（转出）

```
订单失败/超时
    ↓
BtseTransferService.executeRefundAfterCompensation()
    ↓
BtseApiClient.transfer(direction="OUT")
    ↓
内部调用 PUT /ext-orders/cancel
    ↓
退回资产到BTSE（相当于转出系统）
```

### 4.3 轮次结算流程（特殊转出）

```
轮次结算完成
    ↓
OrderSettlementService.executeRoundMergedTransferOut()
    ↓
BtseApiClient.settlement()
    ↓
内部调用 POST /ext-orders/settlement
    ↓
合并结算到BTSE
```

### 4.4 状态查询流程

```
补偿机制定时任务
    ↓
BtseTransferService.compensate()
    ↓
BtseApiClient.getTransferStatus()
    ↓
内部调用 GET /ext-orders/{extRequestId}
    ↓
更新转账状态
```

## 五、参数映射规则

### 5.1 通用参数映射

| 系统参数 | BTSE参数 | 说明 |
|---------|----------|------|
| transferId | extRequestId | 格式: "btse_transfer_log.id:{id}" |
| username | username | 使用 user.nickname |
| amount | amount | 字符串格式，避免精度损失 |
| currency | currency | 默认 "USDT" |
| referId | extRefId | 订单ID或轮次ID |

### 5.2 特殊参数处理

- `bonusAmount`: 第一阶段固定为 "0"
- `direction`: 系统内部使用，不传给BTSE
- `totalOrderAmount` / `pnlAmount`: 仅settlement接口使用

## 六、改动点分析

### 6.1 最小化改动原则

```
option-common-service/
├── integration/
│   ├── BtseApiClient.java          [保持现有接口]
│   │   ├── transfer()               // 已有方法
│   │   ├── getTransferStatus()     // 已有方法
│   │   └── settlement()            // 新增方法(仅此一个)
│   │
│   └── BtseApiClientImpl.java      [内部实现调整]
│       ├── transfer()               // 内部路由到create/cancel
│       ├── getTransferStatus()     // 调用query接口
│       └── settlement()            // 调用settlement接口
│
└── service/
    └── BtseTransferService.java    [无需修改]
        ├── transferFromBtse()       // 继续调用transfer(IN)
        ├── transferToBtse()         // 继续调用transfer(OUT)
        └── settlementWithRound()    // 调用settlement()
```

### 6.2 影响范围

- **最小改动**：仅在 BtseApiClientImpl 内部调整API调用逻辑
- **接口不变**：BtseApiClient 接口基本保持不变（仅新增settlement）
- **服务层不变**：BtseTransferService 逻辑无需调整
- **订单服务不变**：继续通过RPC调用，无感知底层变化

## 七、扩展性设计

### 7.1 接入新账户系统

未来接入其他账户系统时，只需：

1. 实现新的 `XxxApiClient`
2. 保持相同的 `transfer()` 和 `getTransferStatus()` 接口
3. 在配置中切换实现类

### 7.2 适配器模式

```java
public interface AccountSystemAdapter {
    TransferResponse transferIn(TransferRequest request);
    TransferResponse transferOut(TransferRequest request);
    TransferStatus queryStatus(String transferId);
    TransferResponse settlement(SettlementRequest request);
}

// BTSE实现
public class BtseAccountAdapter implements AccountSystemAdapter {
    // 映射到BTSE的create/cancel/query/settlement
}

// 未来其他系统
public class OtherAccountAdapter implements AccountSystemAdapter {
    // 映射到其他系统的API
}
```

## 八、配置示例

### 8.1 账户系统选择

```yaml
account:
  system:
    provider: btse  # btse / other / mock
    
btse:
  api:
    create-url: /ext-orders/create
    cancel-url: /ext-orders/cancel
    query-url: /ext-orders/{id}
    settlement-url: /ext-orders/settlement
```

### 8.2 Mock模式配置

```yaml
account:
  system:
    provider: mock  # 开发测试使用
    
mock:
  balance:
    default: 10000
  failure:
    rate: 0.05
```

## 九、优势总结

### 9.1 设计优势

- **统一抽象**：保持划转接口的通用性
- **最小改动**：复用现有transfer逻辑
- **易于扩展**：方便接入其他账户系统
- **解耦设计**：业务逻辑与具体API分离

### 9.2 维护优势

- **代码复用**：不需要新增4个方法
- **逻辑清晰**：转入/转出概念统一
- **测试简单**：Mock实现保持一致

### 9.3 未来扩展

- 支持多账户系统并存
- 动态路由到不同账户系统
- 统一的账户抽象层

## 十、注意事项

1. **语义差异**：
   - create实际是"扣款"（转入系统）
   - cancel实际是"退款"（转出系统）
   - 文档和注释需要说明清楚

2. **参数适配**：
   - 统一使用transfer请求结构
   - 内部转换为BTSE要求的参数

3. **错误处理**：
   - 统一错误码映射
   - 保持错误信息的一致性