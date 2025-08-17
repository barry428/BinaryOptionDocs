# 二元期权交易平台 API 文档

## 1. 概述

本文档描述了二元期权交易平台的 REST API 和 WebSocket 接口，包括用户管理、账户管理、订单管理、行情数据查询等功能。

### 1.1 认证方式

- **OAuth Token认证**：所有请求必须通过Gateway（8080端口）转发，携带有效的OAuth token
- **统一入口**：所有API请求都需要通过Gateway进行访问
- **请求头示例**：
  ```http
  Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  Content-Type: application/json
  ```
- **公开接口**：少数接口无需token验证，但仍需通过Gateway访问

### 1.2 响应格式

所有API接口均返回统一的JSON格式：

```json
{
  "code": 200,
  "message": "success",
  "data": {},
  "success": true,
  "error": false
}
```

### 1.3 服务架构

- **Gateway**: 8080 (统一入口，所有API请求都通过此端口)
- **Common Service**: 8081 (用户和账户管理，仅内部访问)
- **Order Service**: 8082 (订单管理，仅内部访问)
- **Market Service**: 8083 (行情数据，仅内部访问 + WebSocket直连)

### 1.4 时间格式

所有时间字段统一返回时间戳格式（毫秒），例如：`1755424200000`

---

## 2. 公开接口 (需要通过Gateway，无需Token)

### 2.1 交易轮次接口

#### 获取当前交易轮次信息

**接口地址**: `GET /api/public/order/round/current/{symbolId}`

**描述**: 获取指定交易对的symbol信息和所有当前活跃轮次（5分钟、10分钟、15分钟等）

**请求参数**:
- **symbolId** (path): 交易对ID

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "symbolId": "1",
    "symbol": "BTCUSDT",
    "rounds": [
      {
        "symbolId": "1",
        "durationMinutes": 5,
        "roundNo": "S1_D5_202508171750",
        "openTime": 1755424200000,
        "closeTime": 1755424500000,
        "lockTime": 1755424470000,
        "status": "OPEN",
        "upAmount": 0,
        "downAmount": 0,
        "createTime": 1755424230790,
        "updateTime": 1755424230790,
        "roundId": "269"
      },
      {
        "symbolId": "1",
        "durationMinutes": 10,
        "roundNo": "S1_D10_202508171750",
        "openTime": 1755424200000,
        "closeTime": 1755424800000,
        "lockTime": 1755424770000,
        "status": "OPEN",
        "upAmount": 0,
        "downAmount": 0,
        "createTime": 1755424230790,
        "updateTime": 1755424230790,
        "roundId": "270"
      },
      {
        "symbolId": "1",
        "durationMinutes": 15,
        "roundNo": "S1_D15_202508171745",
        "openTime": 1755423900000,
        "closeTime": 1755424800000,
        "lockTime": 1755424770000,
        "status": "OPEN",
        "upAmount": 0,
        "downAmount": 0,
        "createTime": 1755424178933,
        "updateTime": 1755424178933,
        "roundId": "268"
      }
    ]
  },
  "success": true,
  "error": false
}
```

---

## 3. 行情数据接口 (需要通过Gateway，无需Token)

### 3.1 交易对信息接口

#### 获取支持的交易对

**接口地址**: `GET /api/market/symbols`

**描述**: 获取平台支持的所有交易对列表

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "symbolId": "1",
      "symbol": "BTCUSDT",
      "baseCurrency": "BTC",
      "quoteCurrency": "USDT",
      "enabled": true,
      "minOrderAmount": 10,
      "maxOrderAmount": 10000,
      "sortOrder": 1,
      "createTime": 1721808297000,
      "updateTime": 1723872570000
    },
    {
      "symbolId": "2",
      "symbol": "ETHUSDT",
      "baseCurrency": "ETH",
      "quoteCurrency": "USDT",
      "enabled": true,
      "minOrderAmount": 10,
      "maxOrderAmount": 10000,
      "sortOrder": 2,
      "createTime": 1721808297000,
      "updateTime": 1723872570000
    }
  ],
  "success": true,
  "error": false
}
```

---

## 4. 用户管理接口 (需要OAuth Token)

### 4.1 用户信息接口

#### 获取当前用户信息

**接口地址**: `GET /api/user/profile`

**描述**: 获取当前登录用户的个人信息

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": "10001",
    "username": "john_doe",
    "email": "john@example.com",
    "mobile": "138****1234",
    "riskAgreement": 1,
    "amlAgreement": 1,
    "status": "ACTIVE",
    "createTime": 1721808297000,
    "updateTime": 1723872570000
  },
  "success": true,
  "error": false
}
```

#### 更新用户协议同意状态

**接口地址**: `PUT /api/user/agreements`

**描述**: 更新当前用户的风险协议和AML协议同意状态

**请求参数**:
- **riskAgreement** (query): 风险协议 0:未同意 1:已同意
- **amlAgreement** (query): AML协议 0:未同意 1:已同意

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": null,
  "success": true,
  "error": false
}
```

---

## 5. 账户管理接口 (需要OAuth Token)

### 5.1 账户查询接口

#### 获取账户余额信息

**接口地址**: `GET /api/account/balance/{accountType}`

**描述**: 获取当前用户指定类型的账户信息（包含余额、统计等完整信息）

**请求参数**:
- **accountType** (path): 账户类型 (REAL:实盘, DEMO:模拟)

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": "1",
    "userId": "10001",
    "accountType": "REAL",
    "balance": 1000.00,
    "frozenBalance": 50.00,
    "totalProfit": 150.00,
    "totalLoss": 80.00,
    "totalDeposit": 1000.00,
    "totalWithdraw": 0.00,
    "createTime": 1721808297000,
    "updateTime": 1723872570000
  },
  "success": true,
  "error": false
}
```

### 5.2 账户操作接口

#### 领取模拟账户初始资金

**接口地址**: `POST /api/account/demo/claim-bonus`

**描述**: 根据系统配置动态领取DEMO资金，会检查余额阈值和领取次数限制

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": true,
  "success": true,
  "error": false
}
```

---

## 6. 订单管理接口 (需要OAuth Token)

### 6.1 订单创建接口

#### 创建订单

**接口地址**: `POST /api/order`

**描述**: 创建新的二元期权订单

**请求体示例**:
```json
{
  "symbolId": 1,
  "accountType": "DEMO",
  "amount": 100.00,
  "direction": "UP",
  "roundId": 1001
}
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": "10001",
    "userId": "10001",
    "symbolId": 1,
    "symbol": "BTCUSDT",
    "roundId": 1001,
    "roundNumber": "R20250817001",
    "accountType": "DEMO",
    "amount": 100.00,
    "direction": "UP",
    "status": "ACTIVE",
    "openPrice": 65432.10,
    "expectedProfit": 185.00,
    "fee": 5.00,
    "createTime": 1723865400000,
    "clientIp": "192.168.1.1",
    "userAgent": "Mozilla/5.0..."
  },
  "success": true,
  "error": false
}
```

### 6.2 订单查询接口

#### 查询订单详情

**接口地址**: `GET /api/order/{id}`

**描述**: 查询当前用户的订单详情

**请求参数**:
- **id** (path): 订单ID

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "id": "10001",
    "userId": "10001",
    "symbolId": 1,
    "symbol": "BTCUSDT",
    "roundId": 1001,
    "roundNumber": "R20250817001",
    "accountType": "DEMO",
    "amount": 100.00,
    "direction": "UP",
    "status": "WIN",
    "openPrice": 65432.10,
    "settlePrice": 65800.50,
    "expectedProfit": 185.00,
    "actualProfit": 185.00,
    "fee": 5.00,
    "createTime": 1723865400000,
    "settleTime": 1723865700000
  },
  "success": true,
  "error": false
}
```

#### 查询活跃订单列表

**接口地址**: `POST /api/order/list/active?accountType=DEMO`

**描述**: 查询当前用户状态为ACTIVE的订单

**请求参数**:
- **accountType** (query, 可选): 账户类型 (REAL:实盘, DEMO:模拟)

**请求体示例**:
```json
{
  "page": 1,
  "size": 20
}
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "page": 1,
    "size": 20,
    "total": 5,
    "totalPages": 1,
    "records": [
      {
        "id": "10001",
        "symbolId": 1,
        "symbol": "BTCUSDT",
        "accountType": "DEMO",
        "amount": 100.00,
        "direction": "UP",
        "status": "ACTIVE",
        "openPrice": 65432.10,
        "expectedProfit": 185.00,
        "createTime": 1723865400000
      }
    ]
  },
  "success": true,
  "error": false
}
```

#### 查询历史订单列表

**接口地址**: `POST /api/order/list/history?accountType=DEMO`

**描述**: 查询当前用户状态为WIN或LOSE的已结算订单

**请求参数**:
- **accountType** (query, 可选): 账户类型 (REAL:实盘, DEMO:模拟)

**请求体示例**:
```json
{
  "page": 1,
  "size": 20
}
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "page": 1,
    "size": 20,
    "total": 50,
    "totalPages": 3,
    "records": [
      {
        "id": "10001",
        "symbolId": 1,
        "symbol": "BTCUSDT",
        "accountType": "DEMO",
        "amount": 100.00,
        "direction": "UP",
        "status": "WIN",
        "openPrice": 65432.10,
        "settlePrice": 65800.50,
        "expectedProfit": 185.00,
        "actualProfit": 185.00,
        "createTime": 1723865400000,
        "settleTime": 1723865700000
      }
    ]
  },
  "success": true,
  "error": false
}
```

### 6.3 订单操作接口

#### 取消订单

**接口地址**: `POST /api/order/{id}/cancel`

**描述**: 取消指定的订单（仅限ACTIVE状态）

**请求参数**:
- **id** (path): 订单ID

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": true,
  "success": true,
  "error": false
}
```

### 6.4 订单统计接口

#### 获取订单统计

**接口地址**: `GET /api/order/stats?accountType=DEMO`

**描述**: 获取当前用户的订单统计信息

**请求参数**:
- **accountType** (query, 可选): 账户类型 (REAL:实盘, DEMO:模拟)

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "totalOrders": 100,
    "winOrders": 55,
    "loseOrders": 40,
    "drawOrders": 5,
    "winRate": 55.0,
    "totalProfit": 1500.00,
    "totalLoss": 800.00,
    "netProfit": 700.00,
    "todayOrders": 10,
    "todayProfit": 150.00
  },
  "success": true,
  "error": false
}
```

---

## 7. WebSocket接口

### 7.1 实时行情推送

**连接地址**: `ws://localhost:8083/ws/market`

**描述**: 提供实时行情数据推送服务，支持订阅指定交易对的实时价格和24小时统计数据

#### 连接建立

连接成功后，服务端会发送欢迎消息：
```json
{
  "type": "welcome",
  "supportedSymbols": ["BTCUSDT", "ETHUSDT", "BNBUSDT"],
  "features": ["tick", "stats"]
}
```

#### 订阅行情数据

发送订阅命令：
```
subscribe:BTCUSDT
```

服务端确认响应：
```json
{
  "type": "subscribed",
  "symbol": "BTCUSDT",
  "dataType": "tick"
}
```

行情数据推送（每500ms）：
```json
{
  "type": "marketData",
  "data": [
    {
      "symbol": "BTCUSDT",
      "price": 65432.10,
      "high24h": 66000.00,
      "low24h": 64000.00,
      "change24h": 1432.10,
      "changePercent24h": 2.24,
      "volume": 12345.67,
      "timestamp": 1723865400123
    }
  ]
}
```

#### 订阅24小时统计

发送订阅命令：
```
subscribe-stats:BTCUSDT
```

服务端确认响应：
```json
{
  "type": "subscribed",
  "symbol": "BTCUSDT",
  "dataType": "stats"
}
```

统计数据推送（每2秒）：
```json
{
  "type": "24hStats",
  "data": [
    {
      "symbol": "BTCUSDT",
      "currentPrice": 65432.10,
      "high24h": 66000.00,
      "low24h": 64000.00,
      "change24h": 1432.10,
      "changePercent24h": 2.24,
      "volume24h": 12345.67,
      "timestamp": 1723865400000,
      "trend": "up"
    }
  ]
}
```

#### 取消订阅

取消行情订阅：
```
unsubscribe:BTCUSDT
```

取消统计订阅：
```
unsubscribe-stats:BTCUSDT
```

服务端确认响应：
```json
{
  "type": "unsubscribed",
  "symbol": "BTCUSDT",
  "dataType": "tick"
}
```

#### 心跳检测

客户端发送：
```
ping
```

服务端响应：
```json
{
  "type": "pong",
  "timestamp": 1723865400000
}
```

#### 调试命令

任何非命令文本都会被echo回显：
```
hello
```

服务端响应：
```json
{
  "type": "echo",
  "message": "hello"
}
```

测试统计数据：
```
test-stats
```

服务端响应并立即推送BTCUSDT的统计数据：
```json
{
  "type": "test",
  "message": "已添加BTCUSDT到统计订阅列表"
}
```

---

## 8. 错误码说明

### 8.1 通用错误码

- **200**: 成功
- **400**: 请求参数错误
- **401**: 未认证或认证失败
- **403**: 权限不足
- **404**: 资源不存在
- **500**: 服务器内部错误

### 8.2 业务错误码

- **10001**: 用户不存在
- **10002**: 账户余额不足
- **10003**: 订单不存在
- **10004**: 订单状态不允许此操作
- **10005**: 交易轮次已锁定
- **10006**: 交易对不存在
- **10007**: 账户类型错误

### 8.3 错误响应示例

```json
{
  "code": 10002,
  "message": "账户余额不足",
  "data": null,
  "success": false,
  "error": true
}
```

---

## 9. 注意事项

### 9.1 认证和访问说明

- **统一入口**：所有API请求必须通过Gateway（8080端口）进行
- **OAuth Token验证**：除公开接口外，所有请求都需要在请求头中携带有效的OAuth token
- **请求头格式**：
  ```http
  GET /api/user/profile HTTP/1.1
  Host: gateway.domain.com:8080
  Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  Content-Type: application/json
  ```
- **公开接口**：少数接口（如交易轮次、交易对列表）无需token，但仍需通过Gateway访问

### 9.2 分页说明

- 分页参数统一使用 `page`（页码，从1开始）和 `size`（每页大小）
- 分页响应包含 `total`（总记录数）和 `totalPages`（总页数）

### 9.3 时间格式

- 所有时间字段统一返回时间戳格式（毫秒）
- 示例：`1723865400000` 对应 2025-08-17 10:30:00 东八区时间

### 9.4 金额精度

- 所有金额字段使用 `BigDecimal` 类型，保证精度
- JSON响应中金额保持数字格式，不转换为字符串

### 9.5 ID字段

- 所有ID字段（如userId、orderId等）在JSON响应中转换为字符串格式
- 避免JavaScript大数字精度丢失问题

### 9.6 状态枚举

#### 订单状态
- **PENDING**: 待处理
- **ACTIVE**: 活跃中
- **WIN**: 盈利
- **LOSE**: 亏损
- **DRAW**: 平局
- **CANCELLED**: 已取消

#### 交易轮次状态
- **OPEN**: 开放下单
- **LOCKED**: 锁定下单
- **SETTLED**: 已结算

#### 账户类型
- **REAL**: 实盘账户
- **DEMO**: 模拟账户

#### 订单方向
- **UP**: 看涨
- **DOWN**: 看跌

### 9.7 WebSocket注意事项

- **直连访问**：WebSocket连接直接访问Market Service（8083端口），不通过Gateway
- **无需认证**：WebSocket连接无需OAuth token验证
- **订阅机制**：支持多个交易对同时订阅行情和统计数据
- **推送频率**：行情数据500ms/次，统计数据2秒/次
- **性能监控**：每30秒输出性能报告到服务端日志