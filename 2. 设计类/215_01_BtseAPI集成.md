# BTSE External Order API 集成方案

## 一、概述

本文档描述 BinaryOption 系统与 BTSE External Order API 的集成方案，实现用户资产的扣除、退回、查询和轮次结算功能。

## 二、API 接口说明

### 2.1 创建订单（扣除资产）
**接口**: `PUT /ext-orders/create`

**用途**: 用户下单时从 BTSE 账户扣除资产

**请求参数**:
```json
{
  "extRequestId": "btse_transfer_log.id:123456",  // btse_transfer_log表的ID
  "username": "user.nickname",                     // 用户昵称
  "currency": "USDT",
  "amount": "100.0",
  "bonusAmount": "0",
  "extRefId": "123456"                            // 订单ID
}
```

**调用位置**: 
- `BtseTransferService.transferFromBtse()` - 用户下单时调用

### 2.2 取消订单（退回资产）
**接口**: `PUT /ext-orders/cancel`

**用途**: 订单失败后退回用户资产

**请求参数**:
```json
{
  "extRequestId": "btse_transfer_log.id:123457",
  "username": "user.nickname",
  "currency": "USDT",
  "amount": "100.0",
  "bonusAmount": "0",
  "extRefId": "123456"                            // 订单ID
}
```

**调用位置**:
- `BtseTransferService.executeRefundAfterCompensation()` - 步骤4：立即执行退还操作（因为用户下单已失败）

### 2.3 查询订单状态
**接口**: `GET /ext-orders/{extRequestId}`

**用途**: 查询划转（转入/转出）是否成功

**响应数据**:
```json
{
  "code": 1,
  "msg": "Success",
  "data": {
    "extRequestId": "btse_transfer_log.id:123456",
    "username": "user.nickname",
    "currency": "USDT",
    "amount": "100.0",
    "bonusAmount": "0",
    "extRefId": "123456"
  },
  "success": true
}
```

**调用位置**:
- 补偿机制定时任务中查询转账状态

### 2.4 轮次结算
**接口**: `POST /ext-orders/settlement`

**用途**: 订单按轮次结算后，将每个用户每个轮次的合并结算结果回传给 BTSE

**请求参数**:
```json
{
  "extRequestId": "btse_transfer_log.id:123458",
  "username": "user.nickname",
  "currency": "USDT",
  "totalOrderAmount": "350.00",     // 该轮次总投入金额
  "totalOrderBonusAmount": "0.0",
  "pnlAmount": "180.00",            // 总收益（可为负）
  "pnlBonusAmount": "0.0",
  "extRefId": "6008"                // 轮次ID
}
```

**调用位置**:
- `OrderSettlementService.executeRoundMergedTransferOut()` - 轮次结算完成后调用

## 三、认证机制

### 3.1 Server to Server 认证

基于 OAuth 2.0 client_credentials 授权模式：

1. **获取 Access Token**
```json
POST /oauth/token
{
  "client_id": "{{CLIENT_ID}}",
  "client_secret": "{{CLIENT_SECRET}}",
  "grant_type": "client_credentials"
}
```

2. **使用 Token**
- 在所有 API 请求的 Header 中添加: `Authorization: Bearer {access_token}`

3. **Token 管理**
- Access Token 有效期内重复使用
- 过期后使用 refresh_token 刷新
- refresh_token 也过期则重新获取

4. **环境配置**
- Dev: https://api.btse.dev/oauth/token
- Staging: https://api.btse.co/oauth/token
- Testnet: https://testapi.btse.io/oauth/token
- Production: https://api.btse.com/oauth/token

## 四、接入方案

### 4.1 整体架构

```
订单服务 (option-order-service)
    ↓ RPC调用
公共服务 (option-common-service)
    ↓ HTTP请求
BTSE External Order API
```

### 4.2 核心流程

#### 4.2.1 下单流程
1. 用户发起下单请求
2. 订单服务通过 RPC 调用公共服务的 `transferFromBtse`
3. 公共服务调用 BTSE `/ext-orders/create` 扣除资产
4. 创建 `btse_transfer_log` 记录（transfer_type = "ORDER_IN"）
5. 成功后创建订单，失败则返回错误

#### 4.2.2 轮次结算流程
1. 轮次结算触发
2. 计算每个用户的总投入和净收益
3. 调用 BTSE `/ext-orders/settlement` 回传结算结果
4. 创建 `btse_transfer_log` 记录（transfer_type = "ROUND_OUT"）
5. 更新 `user_round` 状态

#### 4.2.3 补偿退款流程
1. 检测到订单失败或超时
2. 调用 BTSE `/ext-orders/cancel` 退回资产
3. 更新订单和转账日志状态

## 五、改动点清单

### 5.1 公共服务 (option-common-service)

```
option-common-service/
├── src/main/java/com/binaryoption/commonservice/
│   ├── integration/
│   │   ├── BtseApiClient.java                [新增接口方法]
│   │   │   ├── createExternalOrder()         // 创建订单
│   │   │   ├── cancelExternalOrder()         // 取消订单
│   │   │   ├── queryExternalOrder()          // 查询状态
│   │   │   └── settlementExternalOrder()     // 轮次结算
│   │   │
│   │   ├── BtseApiClientImpl.java            [实现接口]
│   │   │   ├── createExternalOrder()         // PUT /ext-orders/create
│   │   │   ├── cancelExternalOrder()         // PUT /ext-orders/cancel
│   │   │   ├── queryExternalOrder()          // GET /ext-orders/{id}
│   │   │   ├── settlementExternalOrder()     // POST /ext-orders/settlement
│   │   │   ├── createAuthHeaders()           // OAuth认证头
│   │   │   └── getOrRefreshAccessToken()     // Token管理
│   │   │
│   │   └── BtseMockApiClient.java            [Mock实现]
│   │       └── 同上四个方法的Mock实现
│   │
│   └── service/
│       └── BtseTransferService.java          [调用集成]
│           ├── transferFromBtse()            // 调用createExternalOrder
│           ├── executeRefundAfterCompensation() // 调用cancelExternalOrder
│           └── settlementWithRound()         // 调用settlementExternalOrder
```

### 5.2 订单服务 (option-order-service)

```
option-order-service/
├── src/main/java/com/binaryoption/orderservice/
│   └── service/
│       └── OrderSettlementService.java       [调用RPC]
│           └── executeRoundMergedTransferOut()
│               └── 调用 btseTransferRpcClient.settlementWithRound()
```

### 5.3 数据模型

#### btse_transfer_log 表
- `extRequestId` 格式: "btse_transfer_log.id:{id}"
- `transfer_type`: ORDER_IN / ROUND_OUT / CANCEL
- `refer_id`: 订单ID或轮次ID

#### user_round 表
- 记录轮次结算状态
- 状态流转: PENDING → SETTLED → TRANSFERRED → SUCCESS/FAILED

## 六、关键实现细节

### 6.1 请求ID格式
- `extRequestId` 统一格式: `"btse_transfer_log.id:{id}"`
- 确保请求幂等性和可追溯性

### 6.2 用户标识
- 使用 `user.nickname` 作为 BTSE 系统的用户标识
- 保持与 BTSE OAuth 认证系统的用户体系一致

### 6.3 金额处理
- 所有金额使用 `DECIMAL(22,8)` 格式
- 在 JSON 中以字符串形式传输，避免精度损失
- `bonusAmount` 和 `pnlBonusAmount` 在第一阶段固定为 "0"

### 6.4 错误处理
- HTTP 400: 业务错误（如余额不足）
- 错误码 11000013: Insufficient Balance in Wallet
- 所有错误需记录到 `btse_transfer_log` 的 `error_message` 字段

### 6.5 Mock模式
- 通过配置 `btse.mock.enabled` 切换真实/Mock实现
- Mock模式用于开发和测试环境
- 保持相同的接口签名和业务逻辑

## 七、配置要求

### 7.1 OAuth配置
```yaml
btse:
  oauth:
    client-id: ${BTSE_CLIENT_ID}
    client-secret: ${BTSE_CLIENT_SECRET}
    scope: wallet.write trade.write
```

### 7.2 API配置
```yaml
btse:
  api:
    base-url: ${BTSE_API_BASE_URL}
    timeout: 30000
```

### 7.3 Mock配置
```yaml
btse:
  mock:
    enabled: true  # 开发环境为true，生产环境为false
```

## 八、测试要点

1. **创建订单测试**
   - 正常扣款流程
   - 余额不足处理
   - 网络超时重试

2. **取消订单测试**
   - 正常退款流程
   - 重复退款幂等性
   - 异常订单退款

3. **查询状态测试**
   - 成功状态查询
   - 失败状态查询
   - 不存在的订单查询

4. **轮次结算测试**
   - 盈利场景（pnlAmount > 0）
   - 亏损场景（pnlAmount < 0）
   - 边界条件（totalOrderAmount + pnlAmount = 0）

## 九、监控指标

1. **API调用监控**
   - 接口响应时间
   - 成功率/失败率
   - 错误类型分布

2. **业务监控**
   - 日均转账次数
   - 转账金额统计
   - 轮次结算频率

3. **告警规则**
   - API响应超时
   - 连续失败次数超限
   - 余额异常波动

## 十、上线计划

1. **第一阶段**: Mock模式测试
   - 验证业务流程
   - 完善错误处理

2. **第二阶段**: 测试环境对接
   - 使用真实API
   - 小额测试验证

3. **第三阶段**: 生产环境部署
   - 灰度发布
   - 监控和回滚方案