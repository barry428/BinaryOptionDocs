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
        "startPrice": 65432.50,
        "endPrice": null,
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
        "startPrice": 65432.50,
        "endPrice": null,
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
        "startPrice": 65420.25,
        "endPrice": null,
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

### 2.2 交易对信息接口

#### 获取支持的交易对

**接口地址**: `GET /api/public/order/symbols`

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

## 3. 用户管理接口 (需要OAuth Token)

### 3.1 用户信息接口

#### 获取当前用户信息

**接口地址**: `GET /api/user/profile`

**描述**: 获取当前登录用户的个人信息

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "userId": "211",
    "externalId": "testuser_1755848172",
    "nickname": "testuser_1755848172",
    "email": "testuser_1755848172@oauth.auto",
    "status": 1,
    "riskAgreement": 1,
    "amlAgreement": 1,
    "createTime": 1755848172573,
    "updateTime": 1755848172573
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

## 4. 账户管理接口 (需要OAuth Token)

### 4.1 账户查询接口

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
    "accountId": "1",
    "userId": "211",
    "accountType": "REAL",
    "balance": 0E-16,
    "frozenBalance": 15.0000000000000000,
    "totalProfit": 6.9500000000000000,
    "totalLoss": 5.0000000000000000,
    "totalDeposit": 20.0000000000000000,
    "totalWithdraw": 20.0000000000000000,
    "createTime": 1755848172573,
    "updateTime": 1755848172573
  },
  "success": true,
  "error": false
}
```

### 4.2 账户操作接口

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

### 4.3 BTSE转账接口

#### BTSE转入（充值）

**接口地址**: `POST /api/account/transfer/from-btse`

**描述**: 从BTSE交易所转入资金到REAL账户

**请求体示例**:
```json
{
  "amount": 20.00
}
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "transferId": "mock_transfer_18f5e109-47ad-4308-a7ed-47e96d7920b1",
    "status": "SUCCESS",
    "amount": 20.00,
    "direction": "FROM_BTSE",
    "createTime": 1755848179419,
    "message": "充值成功"
  },
  "success": true,
  "error": false
}
```

#### BTSE转出（提现）

**接口地址**: `POST /api/account/transfer/to-btse`

**描述**: 从REAL账户转出资金到BTSE交易所

**请求体示例**:
```json
{
  "amount": 20.00
}
```

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "transferId": "mock_transfer_56dfc45f-1eb3-4714-8869-4c7f25972830",
    "status": "SUCCESS",
    "amount": 20.00,
    "direction": "TO_BTSE",
    "createTime": 1755848190385,
    "message": "提现成功"
  },
  "success": true,
  "error": false
}
```

#### 查询转账历史

**接口地址**: `GET /api/account/transfer/history?page=1&size=10`

**描述**: 查询用户的BTSE转账历史记录

**请求参数**:
- **page** (query, 可选): 页码，默认1
- **size** (query, 可选): 每页大小，默认10

**响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "records": [
      {
        "id": "505",
        "userId": "211",
        "direction": "OUT",
        "amount": 20.0000000000000000,
        "status": "SUCCESS",
        "transferId": "mock_transfer_56dfc45f-1eb3-4714-8869-4c7f25972830",
        "createTime": 1755848189759
      },
      {
        "id": "504",
        "userId": "211", 
        "direction": "IN",
        "amount": 5.0000000000000000,
        "status": "SUCCESS",
        "transferId": "mock_transfer_cbcff0d5-16a3-4f13-a2cb-be3a7b484c72",
        "createTime": 1755848187826
      },
      {
        "id": "503",
        "userId": "211",
        "direction": "IN", 
        "amount": 5.0000000000000000,
        "status": "SUCCESS",
        "transferId": "mock_transfer_3ef9f5d6-011e-436a-bbfa-3576f68fde9e",
        "createTime": 1755848185124
      }
    ],
    "total": 5,
    "page": 1,
    "size": 10,
    "pages": 1,
    "hasNext": false,
    "hasPrevious": false
  },
  "success": true,
  "error": false
}
```

**字段说明**:
- `direction`: 转账方向（"IN" 转入 / "OUT" 转出）
- `status`: 转账状态（"SUCCESS" 成功 / "PENDING" 处理中 / "FAILED" 失败）
- `transferId`: BTSE交易所的转账ID
- `createTime`: 转账创建时间（毫秒时间戳）

---

## 5. 订单管理接口 (需要OAuth Token)

### 5.1 订单创建接口

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
    "orderId": "277",
    "userId": "211",
    "accountType": "DEMO",
    "symbolId": "1",
    "roundId": "359",
    "roundNo": "S1_D5_202508221535",
    "direction": "UP",
    "amount": 10.00,
    "odds": 1.72,
    "expectedProfit": 7.20,
    "orderPrice": 55652.78,
    "status": "ACTIVE",
    "fee": 0,
    "createTime": 1755848175186,
    "updateTime": 1755848175199
  },
  "success": true,
  "error": false
}
```

### 5.2 订单查询接口

#### 查询历史订单列表

**接口地址**: `POST /api/order/list/history?accountType=DEMO`

**描述**: 查询当前用户状态为WIN或LOSE的已结算订单，按交易轮次聚合展示

**请求参数**:
- **accountType** (query, 可选): 账户类型 (REAL:实盘, DEMO:模拟)

**响应说明**:
- 返回的数据按交易轮次（round）聚合
- 每个轮次包含该轮次的基本信息和盈亏汇总
- `totalOrders`: 该轮次订单总数
- `totalAmount`: 该轮次投注总金额
- `totalProfit`: 该轮次所有盈利订单的利润总和
- `totalLoss`: 该轮次所有亏损订单的损失总和
- `netProfit`: 该轮次的净利润（totalProfit - totalLoss）
- `orders`: 该轮次下的所有订单详细列表
- **重要字段变化**:
  - `orderId`: 订单ID（字符串格式）
  - `odds`: 赔率（取代原`ratio`字段）
  - `orderPrice`: 下单时价格（订单记录的当时价格）
  - `settlePrice`: 结算价格（轮次结束时的最终价格）
  - `profit`: 实际盈亏（取代原`actualProfit`字段）
  - `settleTime`: 结算时间（毫秒时间戳）
  - `updateTime`: 订单最后更新时间

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
    "records": [
      {
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "symbolId": "1",
        "symbol": "BTCUSDT",
        "durationMinutes": 5,
        "startPrice": 57480.8200000000000000,
        "endPrice": 52387.0200000000000000,
        "openTime": 1755848100000,
        "closeTime": 1755848400000,
        "settleTime": 1755848190740,
        "roundStatus": "SETTLED",
        "totalOrders": 6,
        "totalAmount": 45.0000000000000000,
        "totalProfit": 13.6100000000000000,
        "totalLoss": 25.0000000000000000,
        "netProfit": -11.3900000000000000,
        "orders": [
          {
            "orderId": "282",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 5.0000000000000000,
            "odds": 1.6800,
            "expectedProfit": 3.4000000000000000,
            "orderPrice": 58046.3200000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 3.3300000000000000,
            "fee": 0.0700000000000000,
            "settleTime": 1755848192711,
            "createTime": 1755848186717,
            "updateTime": 1755848190740
          },
          {
            "orderId": "281",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 5.0000000000000000,
            "odds": 1.7400,
            "expectedProfit": 3.7000000000000000,
            "orderPrice": 50359.7900000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 3.6200000000000000,
            "fee": 0.0800000000000000,
            "settleTime": 1755848191762,
            "createTime": 1755848183957,
            "updateTime": 1755848190740
          },
          {
            "orderId": "280",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 5.0000000000000000,
            "odds": 1.8100,
            "expectedProfit": 4.0500000000000000,
            "orderPrice": 52088.9700000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -5.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191755,
            "createTime": 1755848179499,
            "updateTime": 1755848190740
          },
          {
            "orderId": "279",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 10.0000000000000000,
            "odds": 1.6900,
            "expectedProfit": 6.9000000000000000,
            "orderPrice": 53306.4300000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -10.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191745,
            "createTime": 1755848176525,
            "updateTime": 1755848190740
          },
          {
            "orderId": "278",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 10.0000000000000000,
            "odds": 1.6800,
            "expectedProfit": 6.8000000000000000,
            "orderPrice": 59548.5900000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 6.6600000000000000,
            "fee": 0.1400000000000000,
            "settleTime": 1755848191734,
            "createTime": 1755848175796,
            "updateTime": 1755848190740
          },
          {
            "orderId": "277",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 10.0000000000000000,
            "odds": 1.7200,
            "expectedProfit": 7.2000000000000000,
            "orderPrice": 55652.7800000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -10.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191713,
            "createTime": 1755848174949,
            "updateTime": 1755848190740
          }
        ]
      }
    ],
    "total": "1",
    "page": 1,
    "size": 10,
    "pages": 1,
    "hasNext": false,
    "hasPrevious": false
  },
  "success": true,
  "error": false
}
```

#### 根据轮次查询订单列表

**接口地址**: `GET /api/order/list/round/{roundId}?accountType=DEMO`

**描述**: 查询当前用户在指定交易轮次中的所有订单

**请求参数**:
- **roundId** (path): 交易轮次ID
- **accountType** (query, 可选): 账户类型 (REAL:实盘, DEMO:模拟)

**响应说明**:
- 对于已结算的轮次，所有字段都有值
- 对于未结算的轮次，以下字段可能为空值或0：
  - `endPrice`: 结算价格，未结算时为 null
  - `settleTime`: 结算时间，未结算时为 null
  - `actualProfit`: 实际盈亏，未结算时为 0
  - `totalProfit`: 总盈利，未结算时为 0
  - `totalLoss`: 总亏损，未结算时为 0
  - `netProfit`: 净盈亏，未结算时为 0

**响应示例（已结算轮次）**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "roundInfo": {
      "roundId": "359",
      "roundNo": "S1_D5_202508221535",
      "symbolId": "1",
      "symbol": "BTCUSDT",
      "durationMinutes": 5,
      "startPrice": 57480.8200000000000000,
      "openTime": 1755848100000,
      "closeTime": 1755848400000,
      "settleTime": 1755848186717,
      "roundStatus": "OPEN"
    },
    "userSummary": {
      "totalOrders": 3,
      "totalAmount": 30.0000000000000000,
      "totalProfit": 0,
      "totalLoss": 0,
      "netProfit": 0
    },
    "orders": [
      {
        "orderId": "279",
        "userId": "211",
        "accountType": "DEMO",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "UP",
        "amount": 10.0000000000000000,
        "odds": 1.6900,
        "expectedProfit": 6.9000000000000000,
        "orderPrice": 53306.4300000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848176525,
        "updateTime": 1755848176525
      },
      {
        "orderId": "278",
        "userId": "211",
        "accountType": "DEMO",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "DOWN",
        "amount": 10.0000000000000000,
        "odds": 1.6800,
        "expectedProfit": 6.8000000000000000,
        "orderPrice": 59548.5900000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848175796,
        "updateTime": 1755848175796
      },
      {
        "orderId": "277",
        "userId": "211",
        "accountType": "DEMO",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "UP",
        "amount": 10.0000000000000000,
        "odds": 1.7200,
        "expectedProfit": 7.2000000000000000,
        "orderPrice": 55652.7800000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848174949,
        "updateTime": 1755848174949
      }
    ]
  },
  "success": true,
  "error": false
}
```

**响应示例（未结算轮次）**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "roundInfo": {
      "roundId": "359",
      "roundNo": "S1_D5_202508221535",
      "symbolId": "1",
      "symbol": "BTCUSDT",
      "durationMinutes": 5,
      "startPrice": 57480.8200000000000000,
      "openTime": 1755848100000,
      "closeTime": 1755848400000,
      "settleTime": 1755848186717,
      "roundStatus": "OPEN"
    },
    "userSummary": {
      "totalOrders": 3,
      "totalAmount": 15.0000000000000000,
      "totalProfit": 0,
      "totalLoss": 0,
      "netProfit": 0
    },
    "orders": [
      {
        "orderId": "282",
        "userId": "211",
        "accountType": "REAL",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "DOWN",
        "amount": 5.0000000000000000,
        "odds": 1.6800,
        "expectedProfit": 3.4000000000000000,
        "orderPrice": 58046.3200000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848186717,
        "updateTime": 1755848186717
      },
      {
        "orderId": "281",
        "userId": "211",
        "accountType": "REAL",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "UP",
        "amount": 5.0000000000000000,
        "odds": 1.7400,
        "expectedProfit": 3.7000000000000000,
        "orderPrice": 50359.7900000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848183957,
        "updateTime": 1755848183957
      },
      {
        "orderId": "280",
        "userId": "211",
        "accountType": "REAL",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "DOWN",
        "amount": 5.0000000000000000,
        "odds": 1.8100,
        "expectedProfit": 4.0500000000000000,
        "orderPrice": 52088.9700000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848179499,
        "updateTime": 1755848179499
      }
    ]
  },
  "success": true,
  "error": false
}
```

### 5.3 订单操作接口

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

### 5.4 订单统计接口

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

## 6. WebSocket接口

### 6.1 行情数据WebSocket

**连接地址**: `ws://localhost:8083/ws/market`

**描述**: 实时行情数据WebSocket接口，订阅BTSE交易数据并转发给客户端

#### 订阅行情数据

发送订阅消息：
```
subscribe:BTCUSDT
```

**消息格式说明**:
- 使用简单的文本格式：`subscribe:交易对名称`
- 支持的交易对：BTCUSDT, ETHUSDT, BNBUSDT, ADAUSDT, XRPUSDT, SOLUSDT, DOTUSDT, DOGEUSDT
- 取消订阅：`unsubscribe:BTCUSDT`
- 心跳检测：`ping`

#### 连接成功响应

连接建立后会收到欢迎消息：
```json
{
  "type": "welcome",
  "supportedSymbols": ["BTCUSDT", "ETHUSDT", "BNBUSDT", "ADAUSDT", "XRPUSDT", "SOLUSDT", "DOTUSDT", "DOGEUSDT"],
  "message": "连接成功，请使用subscribe:SYMBOL订阅行情数据"
}
```

#### 订阅确认响应

订阅成功后会收到确认消息：
```json
{
  "type": "subscribed",
  "symbol": "BTCUSDT",
  "message": "已订阅BTCUSDT行情数据"
}
```

#### 行情数据推送

服务端推送的实时行情数据格式：
```json
{
    "type": "tick",
    "symbol": "BTCUSDT",
    "price": 65432.10,
    "price24hMin": 64000.00,
    "price24hMax": 66000.00,
    "price24hChange": 0.0224,
    "fixtures": [
        {
            "expiration": "2025-08-22 12:30:00",
            "strike": 65500.00,
            "side": "call",
            "itm": false,
            "price": 0.45
        },
        {
            "expiration": "2025-08-22 12:30:00",
            "strike": 65300.00,
            "side": "put",
            "itm": true,
            "price": 0.55
        }
    ]
}
```

**字段说明**:
- `type`: 消息类型，固定为 "tick"
- `symbol`: 交易对名称
- `price`: 当前价格
- `price24hMin`: 24小时最低价
- `price24hMax`: 24小时最高价
- `price24hChange`: 24小时涨跌幅（百分比小数，如 0.0224 表示 2.24%）
- `fixtures`: 期权合约数组
  - `expiration`: 到期时间（UTC）
  - `strike`: 行权价格
  - `side`: 期权类型（"call" 看涨期权 / "put" 看跌期权）
  - `itm`: 是否价内期权（In The Money）
  - `price`: 期权价格（**注意：赔率 = 1/price**）

**使用说明**:
- 这是从BTSE获取的行情数据，通过Market Service转发
- 数据更新频率约为每秒一次
- 期权价格字段表示的是成本，实际赔率需要计算：赔率 = 1/price
- 支持同时订阅多个交易对

### 6.2 外部期权合约API

**接口地址**: `GET <website>/v1/api/fixtures`

**描述**: 获取期权合约的开仓和平仓数据

#### 请求参数

**Query参数**:
- `symbol`: 交易对名称（如 "BTCUSDT"）
- `includeExpiredAfter`: 包含到期时间阈值（UTC），只返回到期时间 >= 此值的合约（格式："2025-08-22 10:00:00"）

**示例**:
```
GET <website>/v1/api/fixtures?symbol=BTCUSDT&includeExpiredAfter=2025-08-22%2010:00:00
```

#### 响应格式

```json
{
    "open": [
        {
            "expiration": "2025-08-22 12:30:00",
            "strike": 65500.00,
            "side": "call",
            "itm": false,
            "price": 0.45,
            "priceUnderlying": 65432.10,
            "openInterest": 1250,
            "openInterestValue": 562.50
        },
        {
            "expiration": "2025-08-22 12:30:00",
            "strike": 65300.00,
            "side": "put",
            "itm": true,
            "price": 0.55,
            "priceUnderlying": 65432.10,
            "openInterest": 800,
            "openInterestValue": 440.00
        }
    ],
    "closed": [
        {
            "expiration": "2025-08-22 12:00:00",
            "strike": 65000.00,
            "side": "call",
            "itm": true,
            "price": 0.85,
            "priceUnderlying": 65432.10,
            "openInterest": 0,
            "openInterestValue": 0.00
        },
        {
            "expiration": "2025-08-22 12:00:00",
            "strike": 65000.00,
            "side": "put",
            "itm": true,
            "price": 0.55,
            "priceUnderlying": 65432.10,
            "openInterest": 0,
            "openInterestValue": 0.00
        }
    ]
}
```

**字段说明**:
- `open`: 当前开放的期权合约数组
- `closed`: 已关闭的期权合约数组
- **期权合约字段**:
  - `expiration`: 到期时间（UTC）
  - `strike`: 行权价格
  - `side`: 期权类型（"call" 看涨期权 / "put" 看跌期权）
  - `itm`: 是否价内期权（In The Money）
  - `price`: 期权价格（**注意：赔率 = 1/price**）
  - `priceUnderlying`: 标的资产当前价格
  - `openInterest`: 未平仓合约数量
  - `openInterestValue`: 未平仓合约价值

**使用说明**:
- 这是外部第三方提供的期权合约数据
- 只返回到期时间 >= `includeExpiredAfter` 的期权合约
- `open` 数组包含当前可交易的期权合约
- `closed` 数组包含已到期或已关闭的期权合约
- 需要替换 `<website>` 为实际的服务地址
- 期权价格字段表示的是成本，实际赔率需要计算：赔率 = 1/price
- 通过调整 `includeExpiredAfter` 参数可以过滤掉过早到期的合约

### 6.3 外部下单API

**接口地址**: `POST <website>/v1/api/newbet`

**描述**: 向外部第三方提交新的期权交易订单

#### 请求参数

```json
{
    "symbol": "BTCUSDT",
    "expiration": "2025-08-22 12:30:00",
    "strike": 65500.00,
    "side": "call",
    "currentPrice": 65432.10,
    "price": 0.45,
    "amount": 100.00,
    "tradeId": 12345
}
```

**参数说明**:
- `symbol`: 交易对名称（如 "BTCUSDT"）
- `expiration`: 期权到期时间（UTC）
- `strike`: 行权价格
- `side`: 期权类型（"call" 看涨期权 / "put" 看跌期权）
- `currentPrice`: 下单时的当前价格
- `price`: 期权价格（成本价格，非赔率）
- `amount`: 投注金额
- `tradeId`: 交易ID（本地订单的唯一标识）

#### 响应格式

**成功响应**:
```json
{
    "status": "ok",
    "message": "订单提交成功"
}
```

**失败响应**:
```json
{
    "status": "error",
    "message": "订单提交失败：余额不足"
}
```

**字段说明**:
- `status`: 请求状态（"ok" 成功 / "error" 失败）
- `message`: 响应消息，包含成功确认或错误详情

**使用说明**:
- 这是外部第三方提供的下单接口
- 需要替换 `<website>` 为实际的服务地址
- `tradeId` 应使用本地订单ID，用于后续对账和追踪
- 请求成功不代表交易成功，只表示订单已被接受
- 建议在调用前先通过fixtures API确认期权合约的可用性

### 6.4 外部历史数据API

**接口地址**: `GET <website>/v1/api/history`

**描述**: 获取指定期权合约的历史价格数据

#### 请求参数

**Query参数**:
- `symbol`: 交易对名称（如 "BTCUSDT"）
- `expiration`: 期权到期时间（格式："2025-08-22 12:30:00"）
- `side`: 期权类型（"put" 看跌期权 / "call" 看涨期权）
- `limitAfter`: 限制返回时间晚于此时间的数据（格式："2025-08-22 10:00:00"）

**示例**:
```
GET <website>/v1/api/history?symbol=BTCUSDT&expiration=2025-08-22%2012:30:00&side=call&limitAfter=2025-08-22%2010:00:00
```

**参数说明**:
- `symbol`: 交易对名称（如 "BTCUSDT"）
- `expiration`: 期权到期时间（UTC）
- `side`: 期权类型（"call" 看涨期权 / "put" 看跌期权）
- `limitAfter`: 查询起始时间（UTC），只返回此时间之后的数据

#### 响应格式

```json
{
    "symbol": "BTCUSDT",
    "expiration": "2025-08-22 12:30:00",
    "strike": 65500.00,
    "side": "call",
    "history": [
        [1692700800000, 65432.10, 0.45],
        [1692700860000, 65435.20, 0.46],
        [1692700920000, 65440.50, 0.47],
        [1692700980000, 65438.30, 0.46]
    ]
}
```

**字段说明**:
- `symbol`: 交易对名称
- `expiration`: 期权到期时间
- `strike`: 行权价格
- `side`: 期权类型
- `history`: 历史数据数组，每个元素包含三个值：
  - `[0]`: 时间戳（毫秒）
  - `[1]`: 标的资产价格
  - `[2]`: 期权价格

**使用说明**:
- 这是外部第三方提供的历史数据接口
- 需要替换 `<website>` 为实际的服务地址
- 数据按时间顺序返回，从 `limitAfter` 时间开始
- 历史数据用于分析期权价格变化趋势
- 建议合理设置 `limitAfter` 参数，避免返回过多数据

---

## 7. 错误码说明

### 7.1 通用错误码

- **200**: 成功
- **400**: 请求参数错误
- **401**: 未认证或认证失败
- **403**: 权限不足
- **404**: 资源不存在
- **500**: 服务器内部错误

### 7.2 业务错误码

- **10001**: 用户不存在
- **10002**: 账户余额不足
- **10003**: 订单不存在
- **10004**: 订单状态不允许此操作
- **10005**: 交易轮次已锁定
- **10006**: 交易对不存在
- **10007**: 账户类型错误

### 7.3 错误响应示例

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
- **订阅机制**：支持多个交易对同时订阅BTSE行情数据
- **推送频率**：BTSE行情数据约每秒推送一次
- **数据来源**：行情数据来自BTSE交易所（Mock模式下为模拟数据）
- **测试页面**：可访问 `http://localhost:8083/market-test.html` 进行WebSocket测试
- **心跳检测**：支持ping/pong机制保持连接活跃