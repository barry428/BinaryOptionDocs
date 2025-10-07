# 二元期权平台 API 文档

## 概述

本文档提供二元期权交易平台的完整 API 文档。该平台由多个微服务组成，处理交易系统的不同方面。

### 服务架构

- **option-common-service** (端口 8080): 账户管理、BTSE 集成、用户管理
- **option-order-service** (端口 8080): 订单处理、风险控制、交易轮次

### 基础 URL

- Common Service: `http://localhost:8080`
- Order Service: `http://localhost:8080`

### 身份认证

所有 API 都需要通过网关传递的 OAuth token 进行身份认证。用户 ID 从网关设置的 `X-User-Id` 头部提取。

---

## 1. 账户管理 API

### 1.1 获取账户列表

**接口:** `GET /api/borc/account/list`

**描述:** 获取当前认证用户的所有账户。

**请求头:**
```
X-User-Id: {userId}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 1,
      "userId": 123,
      "accountType": "REAL",
      "balance": "1000.00",
      "frozenAmount": "100.00",
      "totalProfit": "50.00",
      "totalLoss": "20.00",
      "totalDeposit": "1000.00",
      "totalWithdraw": "0.00",
      "createTime": "2024-01-01T10:00:00",
      "updateTime": "2024-01-01T15:30:00"
    }
  ]
}
```

### 1.2 获取账户余额

**接口:** `GET /api/borc/account/balance/{accountType}`

**描述:** 获取指定账户类型的余额信息。

**路径参数:**
- `accountType` (string, 必需): 账户类型 - `REAL` 或 `DEMO`

**请求头:**
```
X-User-Id: {userId}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 1,
    "userId": 123,
    "accountType": "REAL",
    "balance": "1000.00",
    "frozenAmount": "100.00",
    "availableAmount": "900.00",
    "totalProfit": "50.00",
    "totalLoss": "20.00",
    "totalDeposit": "1000.00",
    "totalWithdraw": "0.00"
  }
}
```

---

## 2. 用户管理 API

### 2.1 获取用户资料

**接口:** `GET /api/borc/user/profile`

**描述:** 获取当前用户的资料信息。

**请求头:**
```
X-User-Id: {userId}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 123,
    "username": "user123",
    "externalId": "btse_user_10001",
    "nickname": "TradingUser",
    "avatar": "https://example.com/avatar.jpg",
    "riskAgreement": 1,
    "amlAgreement": 1,
    "status": "ACTIVE",
    "createTime": "2024-01-01T10:00:00",
    "updateTime": "2024-01-01T15:30:00"
  }
}
```

### 2.2 更新用户协议

**接口:** `PUT /api/borc/user/agreements`

**描述:** 更新用户的协议同意状态。

**请求头:**
```
X-User-Id: {userId}
```

**查询参数:**
- `riskAgreement` (byte, 必需): 风险协议状态 - `0` (未同意) 或 `1` (已同意)
- `amlAgreement` (byte, 必需): AML 协议状态 - `0` (未同意) 或 `1` (已同意)

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": null
}
```

---

## 3. 订单管理 API

### 3.1 创建订单

**接口:** `POST /api/borc/order`

**描述:** 创建新的二元期权订单。

**请求头:**
```
X-User-Id: {userId}
Content-Type: application/json
User-Agent: {userAgent}
X-Forwarded-For: {clientIp}
```

**请求体:**
```json
{
  "symbolId": 1,
  "accountType": "REAL",
  "amount": "100.00",
  "duration": 300,
  "direction": "UP",
  "clientIp": "192.168.1.100",
  "userAgent": "Mozilla/5.0..."
}
```

**字段说明:**
- `symbolId`: 交易对 ID
- `accountType`: 账户类型 (`REAL` 或 `DEMO`)
- `amount`: 订单金额
- `duration`: 订单持续时间（秒）
- `direction`: 交易方向 (`UP` 或 `DOWN`)

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 12345,
    "userId": 123,
    "symbolId": 1,
    "symbol": "BTC-USDT",
    "accountType": "REAL",
    "amount": "100.00",
    "direction": "UP",
    "duration": 300,
    "entryPrice": "45000.00",
    "expectedProfit": "180.00",
    "status": "ACTIVE",
    "roundId": 567,
    "createTime": "2024-01-01T15:30:00"
  }
}
```

### 3.2 获取订单详情

**接口:** `GET /api/borc/order/{id}`

**描述:** 根据订单 ID 获取订单详情。

**路径参数:**
- `id` (long, 必需): 订单 ID

**请求头:**
```
X-User-Id: {userId}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": 12345,
    "userId": 123,
    "symbolId": 1,
    "symbol": "BTC-USDT",
    "accountType": "REAL",
    "amount": "100.00",
    "direction": "UP",
    "duration": 300,
    "entryPrice": "45000.00",
    "exitPrice": "45500.00",
    "expectedProfit": "180.00",
    "actualProfit": "75.00",
    "status": "WIN",
    "roundId": 567,
    "createTime": "2024-01-01T15:30:00",
    "settleTime": "2024-01-01T15:35:00"
  }
}
```

### 3.3 获取历史订单

**接口:** `POST /api/borc/order/list/history`

**描述:** 获取用户按交易轮次分组的历史订单。

**请求头:**
```
X-User-Id: {userId}
Content-Type: application/json
```

**查询参数:**
- `accountType` (string, 可选): 账户类型过滤器

**请求体:**
```json
{
  "pageNum": 1,
  "pageSize": 10,
  "sortField": "createTime",
  "sortOrder": "DESC"
}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "records": [
      {
        "roundId": 567,
        "symbol": "BTC-USDT",
        "startTime": "2024-01-01T15:30:00",
        "endTime": "2024-01-01T15:35:00",
        "duration": 300,
        "entryPrice": "45000.00",
        "exitPrice": "45500.00",
        "orders": [
          {
            "id": 12345,
            "amount": "100.00",
            "direction": "UP",
            "expectedProfit": "180.00",
            "actualProfit": "75.00",
            "status": "WIN"
          }
        ],
        "totalOrderCount": 1,
        "totalAmount": "100.00",
        "totalProfit": "75.00"
      }
    ],
    "total": 25,
    "pageNum": 1,
    "pageSize": 10,
    "pages": 3
  }
}
```

### 3.4 按轮次获取订单

**接口:** `GET /api/borc/order/list/round/{roundId}`

**描述:** 获取指定交易轮次的所有订单。

**路径参数:**
- `roundId` (long, 必需): 交易轮次 ID

**查询参数:**
- `accountType` (string, 可选): 账户类型过滤器

**请求头:**
```
X-User-Id: {userId}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "roundId": 567,
    "symbol": "BTC-USDT",
    "startTime": "2024-01-01T15:30:00",
    "endTime": "2024-01-01T15:35:00",
    "duration": 300,
    "entryPrice": "45000.00",
    "exitPrice": "45500.00",
    "status": "LOCKED",
    "orders": [
      {
        "id": 12345,
        "amount": "100.00",
        "direction": "UP",
        "expectedProfit": "180.00",
        "actualProfit": "75.00",
        "status": "WIN",
        "createTime": "2024-01-01T15:30:00"
      }
    ],
    "totalOrderCount": 1,
    "totalAmount": "100.00",
    "totalProfit": "75.00"
  }
}
```

### 3.5 获取订单统计

**接口:** `GET /api/borc/order/stats`

**描述:** 获取用户的订单统计摘要。

**查询参数:**
- `accountType` (string, 可选): 账户类型过滤器

**请求头:**
```
X-User-Id: {userId}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "totalOrders": 100,
    "winOrders": 65,
    "loseOrders": 30,
    "drawOrders": 5,
    "winRate": "65.00",
    "totalAmount": "10000.00",
    "totalProfit": "1500.00",
    "totalLoss": "800.00",
    "netProfit": "700.00",
    "todayOrders": 5,
    "todayProfit": "150.00"
  }
}
```

---

## 4. 公开 API（无需身份认证）

### 4.1 获取交易标的

**接口:** `GET /api/borc/public/order/symbols`

**描述:** 获取所有活跃交易对的列表。

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": 1,
      "symbol": "BTC-USDT",
      "name": "Bitcoin/USDT",
      "baseAsset": "BTC",
      "quoteAsset": "USDT",
      "status": "ACTIVE",
      "minAmount": "10.00",
      "maxAmount": "10000.00",
      "profitRate": "0.75",
      "durations": [60, 300, 600, 900, 1800]
    }
  ]
}
```

### 4.2 获取当前交易轮次

**接口:** `GET /api/borc/public/order/round/current/{symbolId}`

**描述:** 获取指定标的的当前活跃交易轮次。

**路径参数:**
- `symbolId` (long, 必需): 交易对 ID

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "symbolId": 1,
    "symbol": "BTC-USDT",
    "rounds": [
      {
        "id": 567,
        "symbolId": 1,
        "symbol": "BTC-USDT",
        "duration": 300,
        "startTime": "2024-01-01T15:30:00",
        "endTime": "2024-01-01T15:35:00",
        "entryPrice": "45000.00",
        "exitPrice": null,
        "status": "OPEN"
      },
      {
        "id": 568,
        "symbolId": 1,
        "symbol": "BTC-USDT",
        "duration": 600,
        "startTime": "2024-01-01T15:25:00",
        "endTime": "2024-01-01T15:35:00",
        "entryPrice": "44980.00",
        "exitPrice": null,
        "status": "OPEN"
      }
    ]
  }
}
```

### 4.3 获取市场历史数据

**接口:** `POST /api/borc/public/order/market/history`

**描述:** 获取期权合约的历史市场数据。

**请求体:**
```json
{
  "symbol": "BTC-USDT",
  "expiration": "2024-01-01T15:35:00",
  "side": "UP",
  "limitAfter": 100
}
```

**响应:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "symbol": "BTC-USDT",
    "expiration": "2024-01-01T15:35:00",
    "side": "UP",
    "history": [
      {
        "timestamp": "2024-01-01T15:30:00",
        "price": "45000.00",
        "volume": "1500.00"
      },
      {
        "timestamp": "2024-01-01T15:31:00",
        "price": "45100.00",
        "volume": "1200.00"
      }
    ]
  }
}
```

---

## 错误处理

### 标准错误响应格式

```json
{
  "code": 400,
  "message": "错误描述",
  "data": null
}
```

### 常见错误代码

- `200`: 成功
- `400`: 错误请求（验证错误、业务逻辑错误）
- `401`: 未授权（需要身份认证）
- `403`: 禁止访问（拒绝访问）
- `404`: 未找到
- `500`: 内部服务器错误

### 业务错误消息

所有错误消息支持国际化，根据客户端的语言环境返回。常见业务错误包括：

- `account.not.found`: 账户未找到
- `account.balance.insufficient`: 账户余额不足
- `order.create.failed`: 订单创建失败
- `order.not.found`: 订单未找到
- `order.access.denied`: 订单访问被拒绝
- `user.not.found`: 用户未找到

---

## 请求/响应示例

### 示例：创建订单流程

1. **获取交易标的**
```bash
curl -X GET "http://localhost:8082/api/borc/public/order/symbols"
```

2. **获取当前交易轮次**
```bash
curl -X GET "http://localhost:8082/api/borc/public/order/round/current/1"
```

3. **创建订单**
```bash
curl -X POST "http://localhost:8082/api/borc/order" \
  -H "Content-Type: application/json" \
  -H "X-User-Id: 123" \
  -d '{
    "symbolId": 1,
    "accountType": "REAL",
    "amount": "100.00",
    "duration": 300,
    "direction": "UP"
  }'
```

### 示例：账户余额检查

**检查账户余额**
```bash
curl -X GET "http://localhost:8081/api/borc/account/balance/REAL" \
  -H "X-User-Id: 123"
```

---

## 限流

- 默认限流：每用户每分钟 100 次请求
- 订单创建：每用户每分钟 20 次请求

限流在网关层面实现，超出限制时返回 HTTP 429 状态。

---

## API 版本控制

当前 API 版本：v1

API 通过 URL 路径进行版本控制。未来版本将以以下形式提供：
- `/api/borc/v2/...`

新版本发布后至少保持 6 个月的向后兼容性。

---

## WebSocket API（市场服务）

### 市场数据流

**接口:** `ws://localhost:8080/ws/market`

**消息格式:**
```json
{
  "action": "subscribe",
  "symbol": "BTC-USDT"
}
```

**实时市场数据:**
```json
{
  "symbol": "BTC-USDT",
  "price": "45000.00",
  "timestamp": "2024-01-01T15:30:00Z",
  "volume": "1500.00",
  "change24h": "2.5"
}
```

支持的操作：`subscribe`、`unsubscribe`、`ping`、`pong`

---

本文档涵盖了二元期权平台的所有控制器接口。如需更多技术细节，请参考源代码注释和各服务的 `/swagger-ui.html` 接口提供的 Swagger UI。