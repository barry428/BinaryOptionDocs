# Binary Option 前端 API 文档

> 版本: 1.1.0
> Gateway 地址: `http://gateway-host:8080`
> 最后更新: 2025-12-18

---

## 认证机制

### 用户类型

| 用户类型 | 说明 | 认证方式 |
|---------|------|---------|
| OAuth 用户 | 正式用户，通过 BTSE OAuth 登录 | `Authorization: Bearer <token>` |
| Demo 用户 | 演示用户，可直接体验 | `X-Demo-Token: <token>` |

### 认证流程

```
┌─────────────────────────────────────────────────────────────────┐
│                        前端请求流程                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 新用户首次访问 (无任何Token)                                   │
│     └─> Gateway 自动创建 Demo 用户                               │
│     └─> 响应头返回 X-Demo-Token，前端需保存                        │
│                                                                 │
│  2. Demo 用户后续请求                                            │
│     └─> 请求头带 X-Demo-Token: <saved_token>                     │
│                                                                 │
│  3. OAuth 用户登录后                                             │
│     └─> 请求头带 Authorization: Bearer <oauth_token>             │
│     └─> OAuth Token 优先级高于 Demo Token                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 请求头说明

**OAuth 用户请求:**
```http
GET /api/borc/order/list/active HTTP/1.1
Host: gateway-host:8080
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

**Demo 用户请求:**
```http
GET /api/borc/order/list/active HTTP/1.1
Host: gateway-host:8080
X-Demo-Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

### 新用户首次访问

首次访问任何需要认证的接口时，如果没有携带任何 Token，Gateway 会：
1. 自动创建一个 Demo 用户
2. 在**响应头**中返回 `X-Demo-Token`
3. 前端需要保存此 Token 用于后续请求

```javascript
// 前端处理示例
const response = await fetch('/api/borc/account/list');
const newDemoToken = response.headers.get('X-Demo-Token');
if (newDemoToken) {
  localStorage.setItem('demoToken', newDemoToken);
}
```

---

## 接口权限

| 路径前缀 | 认证要求 | 说明 |
|---------|---------|------|
| `/api/borc/public/**` | 无需认证 | 公开接口，任何人可访问 |
| `/api/borc/order/**` | 需要认证 | 订单相关接口 |
| `/api/borc/account/**` | 需要认证 | 账户相关接口 |
| `/api/borc/user/**` | 需要认证 | 用户相关接口 |

### 账户访问限制

| 用户类型 | 可访问账户 | 可使用功能 |
|---------|-----------|-----------|
| Demo 用户 | 仅 DEMO 账户 | 下单、查询、领取Demo奖金 |
| OAuth 用户 | DEMO + REAL 账户 | 全部功能，包括资金划转 |

---

## 公开接口 (无需认证)

### 获取交易对列表

获取所有可交易的交易对。

```
GET /api/borc/public/order/symbols
```

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "symbolId": 1,
      "symbol": "BTC-USDT",
      "baseCurrency": "BTC",
      "quoteCurrency": "USDT",
      "enabled": true,
      "minOrderAmount": 10.00,
      "maxOrderAmount": 10000.00,
      "baseOdds": 1.85,
      "feeRate": 0.01,
      "sortOrder": 1
    }
  ]
}
```

---

### 获取热门交易对

获取热门/推荐的交易对列表，基于24小时交易量排序，包含各时间区间的交易量数据。

```
GET /api/borc/public/order/symbols/hot
```

**请求参数:**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| limit | Integer | 否 | 10 | 返回数量，最大50 |

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "symbolId": 1,
        "symbol": "BTC-USDT",
        "totalVolume24h": 10000000.00,
        "durationVolumes": [
          { "duration": 1, "volume24h": 5000000.00 },
          { "duration": 3, "volume24h": 3000000.00 },
          { "duration": 5, "volume24h": 1500000.00 },
          { "duration": 15, "volume24h": 500000.00 }
        ]
      },
      {
        "symbolId": 2,
        "symbol": "ETH-USDT",
        "totalVolume24h": 8000000.00,
        "durationVolumes": [
          { "duration": 3, "volume24h": 4000000.00 },
          { "duration": 1, "volume24h": 2500000.00 },
          { "duration": 5, "volume24h": 1000000.00 },
          { "duration": 15, "volume24h": 500000.00 }
        ]
      }
    ]
  }
}
```

**响应字段说明:**

| 字段 | 类型 | 说明 |
|------|------|------|
| items | Array | 热门交易对列表 |
| items[].symbolId | Long | 交易对ID |
| items[].symbol | String | 交易对名称，如 `BTC-USDT` |
| items[].totalVolume24h | BigDecimal | 该交易对24h总交易量（所有区间之和） |
| items[].durationVolumes | Array | 各时间区间的交易量列表（按交易量降序排列） |
| items[].durationVolumes[].duration | Integer | 时间区间（分钟）：1, 3, 5, 15 |
| items[].durationVolumes[].volume24h | BigDecimal | 该区间24h交易量 |

**排序规则:**
1. **第一级排序**: 按 `totalVolume24h` 降序（交易量最大的交易对排在前面）
2. **第二级排序**: 同一交易对内，`durationVolumes` 数组按 `volume24h` 降序排列（最热门的时间区间排在前面）

> **说明:**
> - 返回基于24小时交易量排序的热门交易对
> - 每个交易对包含各时间区间的交易量明细
> - `durationVolumes[0]` 即为该交易对最热门的时间区间
> - 如果某个区间没有交易记录，该区间不会出现在 `durationVolumes` 中

---

### 获取交易周期配置

获取所有可用的交易周期（时长）配置。

```
GET /api/borc/public/order/durations
```

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "id": "1",
      "durationMinutes": 1,
      "durationName": "1分钟",
      "lockSeconds": 10,
      "baseOdds": 1.9,
      "feeRate": 0.1,
      "sortOrder": 1
    },
    {
      "id": "2",
      "durationMinutes": 3,
      "durationName": "3分钟",
      "lockSeconds": 30,
      "baseOdds": 1.9,
      "feeRate": 0.1,
      "sortOrder": 2
    },
    {
      "id": "3",
      "durationMinutes": 5,
      "durationName": "5分钟",
      "lockSeconds": 30,
      "baseOdds": 1.9,
      "feeRate": 0.1,
      "sortOrder": 3
    },
    {
      "id": "4",
      "durationMinutes": 15,
      "durationName": "15分钟",
      "lockSeconds": 30,
      "baseOdds": 1.9,
      "feeRate": 0.1,
      "sortOrder": 4
    }
  ]
}
```

**字段说明:**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long | 周期配置ID |
| durationMinutes | Integer | 周期时长（分钟） |
| durationName | String | 周期显示名称 |
| lockSeconds | Integer | 锁单时间（秒），轮次结束前多少秒停止下单 |
| baseOdds | BigDecimal | 基础赔率 |
| feeRate | BigDecimal | 手续费率（0.10 表示 10%） |
| sortOrder | Integer | 排序顺序 |

> **说明:** 返回所有启用的交易周期选项，前端可据此展示可选的交易时长。

---

### 获取指定交易对轮次

获取指定交易对的所有当前活跃轮次。

```
GET /api/borc/public/order/round/current/{symbolId}
```

**参数:**
| 参数 | 位置 | 类型 | 必填 | 说明 |
|------|------|------|------|------|
| symbolId | path | Long | 是 | 交易对ID |

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "symbolId": 1,
    "symbol": "BTC-USDT",
    "rounds": [
      {
        "roundId": 100,
        "durationMinutes": 5,
        "roundNo": "R20251208150000",
        "startPrice": 45000.00,
        "openTime": "2025-12-08T15:00:00",
        "closeTime": "2025-12-08T15:05:00",
        "lockTime": "2025-12-08T15:04:55",
        "status": "OPEN"
      }
    ]
  }
}
```

**轮次状态:**
| 状态 | 说明 | 可下单 |
|------|------|--------|
| OPEN | 开放中 | 是 |
| LOCKED | 已锁定 | 否 |
| SETTLED | 已结算 | 否 |

---

### 获取历史行情

获取历史价格数据用于绘制价格曲线图。

```
POST /api/borc/public/order/market/history
```

**请求体:**
```json
{
  "symbol": "BTC-USDT",
  "limitAfter": "300"
}
```

**请求参数:**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| symbol | String | 是 | 交易对符号，如 `BTC-USDT` |
| limitAfter | String | 否 | 返回的数据条数，默认 300，最大 300 |

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "symbol": "BTC-USDT",
    "history": [
      [1733644800000, 45000.00],
      [1733644801000, 45005.50],
      [1733644802000, 45010.25],
      [1733644803000, 45008.00]
    ]
  }
}
```

**数据格式:** `[时间戳(毫秒), 价格]`

> **说明:**
> - 数据频率为每秒一条，按时间升序排列
> - 默认返回最近 300 秒的历史价格数据
> - 用于绘制实时价格曲线图

---

## 用户接口 (需要认证)

### 获取用户信息

```
GET /api/borc/user/profile
```

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "userId": 1001,
    "nickname": "TraderJohn",
    "status": 1,
    "isDemo": false,
    "riskAgreement": 1,
    "amlAgreement": 1,
    "createTime": "2025-01-01T00:00:00"
  }
}
```

---

### 更新协议状态

```
PUT /api/borc/user/agreements?riskAgreement=1&amlAgreement=1
```

**参数:**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| riskAgreement | Byte | 是 | 风险协议: 0=未同意, 1=已同意 |
| amlAgreement | Byte | 是 | 反洗钱协议: 0=未同意, 1=已同意 |

---

## 账户接口 (需要认证)

### 获取账户列表

```
GET /api/borc/account/list
```

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "accountId": 1,
      "accountType": "DEMO",
      "currency": "USDT",
      "balance": 10000.00,
      "frozenBalance": 500.00,
      "availableAmount": 9500.00,
      "totalProfit": 1500.00,
      "totalLoss": 500.00,
      "winRate": 0.6000,
      "status": 1
    }
  ]
}
```

---

### 获取账户余额

```
GET /api/borc/account/balance/{accountType}
```

**参数:**
| 参数 | 位置 | 类型 | 必填 | 说明 |
|------|------|------|------|------|
| accountType | path | String | 是 | `DEMO` 或 `REAL` |

> **注意:** Demo 用户只能查询 DEMO 账户

---

### 领取Demo奖金

```
POST /api/borc/account/demo/claim-bonus
```

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": true
}
```

---

## 订单接口 (需要认证)

### 创建订单

```
POST /api/borc/order
```

**请求体:**
```json
{
  "accountType": "DEMO",
  "symbolId": 1,
  "roundId": 100,
  "direction": "UP",
  "amount": 100.00
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accountType | String | 是 | `DEMO` 或 `REAL` |
| symbolId | Long | 是 | 交易对ID |
| roundId | Long | 否 | 轮次ID，不传自动选择当前轮次 |
| direction | String | 是 | `UP` (看涨) 或 `DOWN` (看跌) |
| amount | BigDecimal | 是 | 下单金额 |

> **注意:** Demo 用户只能交易 DEMO 账户

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "orderId": 12345,
    "accountType": "DEMO",
    "symbolName": "BTC-USDT",
    "roundNo": "R20251208150000",
    "direction": "UP",
    "amount": 100.00,
    "odds": 1.85,
    "expectedProfit": 85.00,
    "orderPrice": 45000.50,
    "status": "ACTIVE",
    "createTime": "2025-12-08T15:00:30"
  }
}
```

---

### 查询订单详情

```
GET /api/borc/order/{orderId}
```

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "orderId": 12345,
    "accountType": "DEMO",
    "symbolName": "BTC-USDT",
    "direction": "UP",
    "amount": 100.00,
    "odds": 1.85,
    "orderPrice": 45000.50,
    "settlePrice": 45100.00,
    "status": "WIN",
    "profit": 85.00,
    "fee": 0.85,
    "settleTime": "2025-12-08T15:05:00"
  }
}
```

**订单状态:**
| 状态 | 说明 |
|------|------|
| PENDING | 待处理 |
| ACTIVE | 进行中 |
| WIN | 盈利 |
| LOSE | 亏损 |
| DRAW | 平局 |
| CANCELLED | 已取消 |

---

### 查询活跃订单

查询当前进行中的订单。

```
GET /api/borc/order/list/active?accountType=DEMO&symbolId=1
```

**参数:**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| accountType | String | 否 | 账户类型筛选 |
| symbolId | Long | 否 | 交易对筛选 |

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "rounds": [
      {
        "roundId": 100,
        "roundNo": "R20251208150000",
        "symbol": "BTC-USDT",
        "durationMinutes": 5,
        "startTime": "2025-12-08T15:00:00",
        "endTime": "2025-12-08T15:05:00",
        "startPrice": 45000.00,
        "endPrice": null,
        "status": "OPEN",
        "settleTime": null,
        "orders": [
          {
            "orderId": 12345,
            "direction": "UP",
            "amount": 100.00,
            "odds": 1.85,
            "expectedProfit": 85.00,
            "status": "ACTIVE"
          }
        ],
        "userStats": {
          "totalOrders": 1,
          "totalAmount": 100.00,
          "totalProfit": 0,
          "totalLoss": 0,
          "netProfit": 0
        }
      }
    ],
    "totalRounds": 1,
    "totalOrders": 1
  }
}
```

> **说明:** 活跃订单的 `userStats` 统计字段都为0，因为尚未结算

---

### 查询历史订单

查询已结算的历史订单，支持分页。

```
GET /api/borc/order/list/history?accountType=DEMO&page=1&pageSize=10&startTime=1734192000000&endTime=1734278399999
```

**参数:**
| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| accountType | String | 否 | - | 账户类型筛选 |
| symbolId | Long | 否 | - | 交易对筛选 |
| startTime | Long | 否 | - | 开始时间 (Unix 毫秒时间戳) |
| endTime | Long | 否 | - | 结束时间 (Unix 毫秒时间戳) |
| page | Integer | 否 | 1 | 页码 |
| pageSize | Integer | 否 | 10 | 每页数量 (最大100) |

**时间参数说明:**
- `startTime`: 查询范围的开始时间，Unix 毫秒时间戳，如 `1734192000000` 表示 2025-12-15 00:00:00
- `endTime`: 查询范围的结束时间，Unix 毫秒时间戳，如 `1734278399999` 表示 2025-12-15 23:59:59.999

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "rounds": [
      {
        "roundId": 99,
        "roundNo": "R20251208145500",
        "symbol": "BTC-USDT",
        "startPrice": 44900.00,
        "endPrice": 45000.00,
        "status": "SETTLED",
        "settleTime": "2025-12-08T15:00:05",
        "orders": [
          {
            "orderId": 12340,
            "direction": "UP",
            "amount": 100.00,
            "status": "WIN",
            "profit": 85.00,
            "fee": 0.85
          }
        ],
        "userStats": {
          "totalOrders": 1,
          "totalAmount": 100.00,
          "totalProfit": 85.00,
          "totalLoss": 0,
          "netProfit": 85.00,
          "winCount": 1,
          "loseCount": 0,
          "winRate": 1.0000
        }
      }
    ],
    "total": 50,
    "page": 1,
    "pageSize": 10,
    "totalPages": 5,
    "hasNext": true,
    "hasPrevious": false
  }
}
```

---

## 错误处理

### 统一响应格式

```json
{
  "code": 200,
  "message": "success",
  "data": { ... },
  "timestamp": "2025-12-08T15:00:00"
}
```

- `code`: 响应码，200 表示成功，其他为业务错误码
- `message`: 响应消息（支持国际化）
- `data`: 响应数据，错误时为 null
- `timestamp`: 响应时间戳

### 业务错误码

错误码格式：`ABCDE` (A=模块, BCDE=具体错误)

#### 用户模块 (10xxx)

| code | 说明 | HTTP状态码 |
|------|------|-----------|
| 10001 | 用户未认证 | 302 |
| 10002 | 用户不存在 | 302 |
| 10005 | 用户已禁用 | 302 |

#### 账户模块 (20xxx)

| code | 说明 | HTTP状态码 |
|------|------|-----------|
| 20001 | 账户不存在 | 422 |
| 20002 | 账户余额不足 | 422 |
| 20004 | 领取奖金失败 | 422 |
| 20005 | 账户冻结失败 | 422 |

#### 订单模块 (30xxx)

| code | 说明 | HTTP状态码 |
|------|------|-----------|
| 30001 | 订单不存在 | 400 |
| 30002 | 订单无权访问 | 400 |
| 30003 | 订单创建失败 | 400 |
| 30005 | 交易轮次不存在/未开放/已锁定 | 400 |
| 30007 | 订单取消失败 | 400 |

#### 风控模块 (40xxx)

| code | 说明 | HTTP状态码 |
|------|------|-----------|
| 40001 | 风控检查失败/用户被拦截 | 303 |
| 40002 | IP受限 | 303 |
| 40004 | 交易限额 | 303 |
| 40005 | 日限额超出 | 303 |
| 40006 | 月限额超出 | 303 |

#### 市场模块 (50xxx)

| code | 说明 | HTTP状态码 |
|------|------|-----------|
| 50001 | 交易品种不存在 | 503 |
| 50002 | 市场数据不可用 | 503 |
| 50003 | 市场服务错误 | 503 |
| 50004 | 交易品种未启用 | 503 |

#### 外部服务模块 (60xxx)

| code | 说明 | HTTP状态码 |
|------|------|-----------|
| 60001 | BTSE服务错误 | 502 |
| 60003 | BTSE转账失败 | 502 |
| 60004 | 市场价格不可用 | 502 |

#### 系统模块 (90xxx)

| code | 说明 | HTTP状态码 |
|------|------|-----------|
| 90002 | 配置未找到 | 500 |
| 90004 | 系统内部错误 | 500 |

### 错误响应示例

**业务错误示例:**
```json
{
  "code": 20002,
  "message": "账户余额不足",
  "data": null
}
```

**订单错误示例:**
```json
{
  "code": 30005,
  "message": "交易轮次已锁定，无法下单",
  "data": null
}
```

**风控拦截示例:**
```json
{
  "code": 40005,
  "message": "今日交易额度已用完",
  "data": null
}
```

---

## WebSocket 实时行情接口

### 连接地址

```
ws://gateway-host:8080/ws/borc
```

> **说明:** WebSocket 连接无需认证，任何客户端都可以连接并订阅行情数据。

---

### 连接示例

```javascript
const ws = new WebSocket('ws://gateway-host:8080/ws/borc');

ws.onopen = () => {
  console.log('WebSocket 已连接');
  // 订阅多个交易对
  ws.send(JSON.stringify({ subscribe: ['BTC-USDT', 'ETH-USDT'] }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('收到消息:', data);
};

ws.onclose = () => {
  console.log('WebSocket 已断开');
};
```

---

### 客户端命令

#### 订阅行情

订阅指定交易对的实时行情推送。使用数组格式，支持订阅多个交易对或所有交易对。

**请求格式:**
```json
{ "subscribe": ["BTC-USDT", "ETH-USDT", "SOL-USDT"] }
```

**订阅所有交易对:**
```json
{ "subscribe": ["*"] }
```

**响应示例:**
```json
{
  "type": "subscribed",
  "symbols": ["BTC-USDT", "ETH-USDT", "SOL-USDT"],
  "count": 3,
  "message": "Subscribed to 3 symbols"
}
```

**订阅所有响应:**
```json
{
  "type": "subscribed",
  "symbols": [],
  "all": true,
  "message": "Subscribed to all market data"
}
```

> **说明:** 使用 `["*"]` 订阅所有交易对，订阅后会自动接收所有可用交易对的实时行情推送。

---

#### 取消订阅

取消指定交易对的行情推送。使用数组格式。

**请求格式:**
```json
{ "unsubscribe": ["BTC-USDT", "ETH-USDT"] }
```

**取消订阅所有:**
```json
{ "unsubscribe": ["*"] }
```

**响应示例:**
```json
{
  "type": "unsubscribed",
  "symbols": ["BTC-USDT", "ETH-USDT"],
  "count": 2,
  "message": "Unsubscribed from 2 symbols"
}
```

**取消订阅所有响应:**
```json
{
  "type": "unsubscribed",
  "symbols": [],
  "all": true,
  "message": "Unsubscribed from all market data"
}
```

---

#### 心跳检测

发送 ping 命令检测连接状态。

**请求格式 (JSON):**
```json
{ "ping": true }
```

**请求格式 (文本):**
```
ping
```

**响应示例:**
```json
{
  "type": "pong",
  "timestamp": 1733644800000
}
```

> **建议:** 客户端每 30 秒发送一次 ping 命令保持连接活跃。

---

### 服务端推送消息

#### 实时行情数据 (tick)

订阅成功后，服务端会按固定间隔（默认 1 秒）推送行情数据。

**推送格式:**
```json
{
  "type": "tick",
  "symbol": "BTC-USDT",
  "price": 45000.50,
  "price24hMin": 44500.00,
  "price24hMax": 46000.00,
  "price24hChange": 2.35,
  "odds": [
    { "duration": 1, "upOdds": 1.95, "downOdds": 1.95 },
    { "duration": 3, "upOdds": 1.95, "downOdds": 1.95 },
    { "duration": 5, "upOdds": 1.95, "downOdds": 1.95 },
    { "duration": 15, "upOdds": 1.95, "downOdds": 1.95 }
  ],
  "timestamp": 1733644800000
}
```

**字段说明:**

| 字段 | 类型 | 说明 |
|------|------|------|
| type | String | 消息类型，固定为 `tick` |
| symbol | String | 交易对符号，如 `BTC-USDT` |
| price | BigDecimal | 当前实时价格 |
| price24hMin | BigDecimal | 24小时最低价 |
| price24hMax | BigDecimal | 24小时最高价 |
| price24hChange | BigDecimal | 24小时价格变化百分比 |
| odds | Array | 各时间区间的赔率数组 |
| timestamp | Long | 时间戳（毫秒） |

**赔率对象 (odds) 字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| duration | Integer | 时间区间（分钟），支持 1, 3, 5, 15 |
| upOdds | BigDecimal | 看涨赔率 |
| downOdds | BigDecimal | 看跌赔率 |

---

### 消息类型汇总

| type | 说明 | 触发场景 |
|------|------|---------|
| subscribed | 订阅确认 | 客户端发送订阅命令后 |
| unsubscribed | 取消订阅确认 | 客户端发送取消订阅命令后 |
| pong | 心跳响应 | 客户端发送 ping 命令后 |
| echo | 回显消息 | 客户端发送未识别的文本命令时 |
| tick | 实时行情 | 服务端定时推送（默认每秒） |

---

### 前端完整集成示例

```javascript
class MarketWebSocket {
  constructor(url) {
    this.url = url;
    this.ws = null;
    this.subscriptions = new Set();
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectDelay = 3000;
    this.pingInterval = null;
  }

  connect() {
    this.ws = new WebSocket(this.url);

    this.ws.onopen = () => {
      console.log('Market WebSocket connected');
      this.reconnectAttempts = 0;

      // 重新订阅之前的交易对
      this.subscriptions.forEach(symbol => {
        this.subscribe(symbol);
      });

      // 启动心跳
      this.startPing();
    };

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.handleMessage(data);
    };

    this.ws.onclose = () => {
      console.log('Market WebSocket disconnected');
      this.stopPing();
      this.tryReconnect();
    };

    this.ws.onerror = (error) => {
      console.error('Market WebSocket error:', error);
    };
  }

  handleMessage(data) {
    switch (data.type) {
      case 'tick':
        this.onTick(data);
        break;
      case 'subscribed':
        console.log(`Subscribed to ${data.symbol}`);
        break;
      case 'unsubscribed':
        console.log(`Unsubscribed from ${data.symbol}`);
        break;
      case 'pong':
        console.log('Pong received:', data.timestamp);
        break;
      default:
        console.log('Unknown message:', data);
    }
  }

  onTick(tick) {
    // 覆盖此方法处理行情数据
    console.log(`${tick.symbol}: ${tick.price}`);
  }

  // 订阅交易对（支持单个或多个）
  subscribe(symbols) {
    const symbolArray = Array.isArray(symbols) ? symbols : [symbols];
    symbolArray.forEach(s => this.subscriptions.add(s));
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ subscribe: symbolArray }));
    }
  }

  // 订阅所有交易对
  subscribeAll() {
    this.subscriptions.add('*');
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ subscribe: ['*'] }));
    }
  }

  // 取消订阅交易对（支持单个或多个）
  unsubscribe(symbols) {
    const symbolArray = Array.isArray(symbols) ? symbols : [symbols];
    symbolArray.forEach(s => this.subscriptions.delete(s));
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ unsubscribe: symbolArray }));
    }
  }

  // 取消订阅所有交易对
  unsubscribeAll() {
    this.subscriptions.clear();
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ unsubscribe: ['*'] }));
    }
  }

  startPing() {
    this.pingInterval = setInterval(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ ping: true }));
      }
    }, 30000);
  }

  stopPing() {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
  }

  tryReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`Reconnecting... attempt ${this.reconnectAttempts}`);
      setTimeout(() => this.connect(), this.reconnectDelay);
    }
  }

  disconnect() {
    this.stopPing();
    if (this.ws) {
      this.ws.close();
    }
  }
}

// 使用示例
const marketWs = new MarketWebSocket('ws://gateway-host:8080/ws/borc');

// 自定义行情处理
marketWs.onTick = (tick) => {
  // 更新 UI
  updatePriceDisplay(tick.symbol, tick.price, tick.price24hChange);
  updateOddsDisplay(tick.symbol, tick.odds);
};

// 连接并订阅
marketWs.connect();

// 订阅单个或多个交易对
marketWs.subscribe('BTC-USDT');
marketWs.subscribe(['ETH-USDT', 'SOL-USDT', 'BNB-USDT']);

// 订阅所有交易对
marketWs.subscribeAll();

// 取消订阅
marketWs.unsubscribe(['ETH-USDT', 'SOL-USDT']);
marketWs.unsubscribeAll();
```

---

## 频率限制

| 接口 | 限制 |
|------|------|
| 创建订单 | 30次/分钟 |
| 订单查询 | 100次/分钟 |
| 历史订单 | 50次/分钟 |
| 公开接口 | 200次/分钟 |
| 账户接口 | 80次/分钟 |
| 用户接口 | 40次/分钟 |

超出限制返回 HTTP 429 状态码。

---

## 前端集成示例

### Axios 请求封装

```javascript
import axios from 'axios';

const api = axios.create({
  baseURL: 'http://gateway-host:8080',
  timeout: 10000,
});

// 错误码模块定义
const ERROR_MODULES = {
  USER: 10000,      // 用户模块
  ACCOUNT: 20000,   // 账户模块
  ORDER: 30000,     // 订单模块
  RISK: 40000,      // 风控模块
  MARKET: 50000,    // 市场模块
  EXTERNAL: 60000,  // 外部服务模块
  SYSTEM: 90000,    // 系统模块
};

// 判断错误码所属模块
function getErrorModule(code) {
  const moduleCode = Math.floor(code / 10000) * 10000;
  return Object.entries(ERROR_MODULES).find(([_, v]) => v === moduleCode)?.[0];
}

// 请求拦截器 - 添加认证头
api.interceptors.request.use((config) => {
  const oauthToken = localStorage.getItem('oauthToken');
  const demoToken = localStorage.getItem('demoToken');

  if (oauthToken) {
    config.headers['Authorization'] = `Bearer ${oauthToken}`;
  } else if (demoToken) {
    config.headers['X-Demo-Token'] = demoToken;
  }

  return config;
});

// 响应拦截器 - 处理响应和错误
api.interceptors.response.use(
  (response) => {
    // 保存新的 Demo Token
    const newDemoToken = response.headers['x-demo-token'];
    if (newDemoToken) {
      localStorage.setItem('demoToken', newDemoToken);
    }

    // 检查业务错误码
    const { code, message, data } = response.data;
    if (code !== 200) {
      const error = new Error(message);
      error.code = code;
      error.module = getErrorModule(code);
      error.data = data;
      return Promise.reject(error);
    }

    return response.data;
  },
  (error) => {
    // HTTP 错误处理
    if (error.response) {
      const { status, data } = error.response;

      // 尝试解析业务错误码
      if (data && data.code) {
        const err = new Error(data.message || '请求失败');
        err.code = data.code;
        err.module = getErrorModule(data.code);
        err.httpStatus = status;
        return Promise.reject(err);
      }

      // 通用 HTTP 错误
      const err = new Error(`HTTP Error: ${status}`);
      err.httpStatus = status;
      return Promise.reject(err);
    }

    return Promise.reject(error);
  }
);

export default api;
export { ERROR_MODULES, getErrorModule };
```

### 错误处理示例

```javascript
import api, { ERROR_MODULES } from './api';

// 下单并处理错误
async function createOrder(orderData) {
  try {
    const result = await api.post('/api/borc/order', orderData);
    return result.data;
  } catch (error) {
    // 根据错误模块分类处理
    switch (error.module) {
      case 'ACCOUNT':
        if (error.code === 20002) {
          showToast('余额不足，请充值');
        }
        break;

      case 'ORDER':
        if (error.code === 30005) {
          showToast('轮次已锁定，请选择其他轮次');
        }
        break;

      case 'RISK':
        showToast('交易受限: ' + error.message);
        break;

      case 'USER':
        // 跳转登录
        router.push('/login');
        break;

      default:
        showToast(error.message || '操作失败');
    }
    throw error;
  }
}
```

### 使用示例

```javascript
// 获取交易对 (无需认证)
const { data: symbols } = await api.get('/api/borc/public/order/symbols');

// 创建订单 (需要认证)
const { data: order } = await api.post('/api/borc/order', {
  accountType: 'DEMO',
  symbolId: 1,
  direction: 'UP',
  amount: 100
});

// 查询活跃订单
const { data: activeOrders } = await api.get('/api/borc/order/list/active', {
  params: { accountType: 'DEMO' }
});
```
