# Options Betting - Fixture Service API

## 概述

这是一个期权投注的Fixture服务API文档，提供了期权合约（fixtures）的创建、查询、下注和实时价格推送功能。

## REST API

**基础URL**: `<website>/v1/api/`

### 1. 获取期权合约列表

**端点**: `/fixtures`  
**方法**: `GET`

#### 请求参数
```json
{
    "symbol": "<str>",                    // 交易标的符号
    "includeExpiredAfter": "<datetime>"   // 可选：包含此时间后过期的合约
}
```

#### 响应格式
```json
{
    "open": [                             // 开放的合约
        {
            "expiration": "<datetime>",   // 到期时间
            "strike": "<float>",          // 行权价
            "side": "put" / "call",       // 期权类型：看跌/看涨
            "itm": "<bool>",              // 是否价内期权(In The Money)
            "price": "<float>",           // 当前价格 (0-1之间)
            "openInterest": "<int>"       // 未平仓合约数
        },
        ...
    ],
    "closed": [                           // 已关闭的合约
        {
            "expiration": "<datetime>",
            "strike": "<float>",
            "side": "put" / "call",
            "itm": "<bool>",
            "price": "<float>",
            "openInterest": "<int>"
        },
        ...
    ]
}
```

**说明**: 
- 请求所有开放的期权合约
- 可选择性地包含指定日期后已过期的合约
- 服务会自动在指定的到期时间和行权价水平内创建合约
- 价格范围在0-1之间，实际购买时需乘以选定的权利金

### 2. 创建新投注

**端点**: `/newbet`  
**方法**: `POST`

#### 请求参数
```json
{
    "symbol": "<str>",           // 交易标的符号
    "expiration": "<datetime>",  // 到期时间
    "strike": "<float>",         // 行权价
    "side": "put" / "call"       // 期权类型
}
```

#### 响应格式
```json
{
    "status": "ok" / "error",   // 请求状态
    "message": "..."             // 状态描述
}
```

**说明**: 
- 请求购买期权合约
- 主要用于风险管理目的
- 如果合约已过期，将返回错误

## WebSocket API

**基础URL**: `<website>/v1/ws/`

### 1. 订阅元数据更新

#### 发送消息
```json
{
    "subscribe": "meta",
    "symbol": "<str>"
}
```

#### 接收消息
```json
{
    "type": "meta",
    "symbol": "<str>",
    "opened": [                    // 新开放的合约
        {
            "expiration": "<datetime>",
            "strike": "<float>",
            "side": "put" / "call"
        },
        ...
    ],
    "closed": [                    // 已关闭的合约
        {
            "expiration": "<datetime>",
            "strike": "<float>",
            "side": "put" / "call",
            "itm": "<bool>",
            "openInterest": "<int>"
        },
        ...
    ]
}
```

**说明**: 订阅通用更新，如合约创建或到期通知

### 2. 订阅价格更新

#### 发送消息
```json
{
    "subscribe": "tick",
    "symbol": "<str>"
}
```

#### 接收消息
```json
{
    "type": "tick",
    "symbol": "<str>",
    "fixtures": [
        {
            "expiration": "<datetime>",
            "strike": "<float>",
            "side": "put" / "call",
            "itm": "<bool>",
            "price": "<float>"         // 实时价格更新
        },
        ...
    ]
}
```

**说明**: 
- 订阅个别合约的价格更新
- 合约到期时自动终止订阅
- 客户端决定订阅哪些合约

## 重要说明

1. **价格机制**:
   - 没有买卖价差(bid-ask spread)
   - 只有单一价格
   - 所有买卖订单作为"市价单"执行
   - 价格范围: 0-1

2. **架构分离**:
   - 实际的买卖、用户管理在客户端服务(交易所)进行
   - 此API仅用于风险管理目的

---

## 文档理解与分析

### 业务模型理解

这个API描述的是一个**二元期权交易系统**的核心服务：

1. **Fixture（期权合约）概念**:
   - Fixture是预定义的期权合约
   - 包含到期时间(expiration)、行权价(strike)、类型(put/call)
   - 系统自动创建和管理这些合约

2. **价格模型**:
   - 采用0-1之间的概率定价模型
   - 1表示100%会盈利，0表示100%会亏损
   - 实际投注金额 = 价格 × 权利金

3. **ITM (In The Money) 状态**:
   - Call期权: 当前价格 > 行权价时为ITM
   - Put期权: 当前价格 < 行权价时为ITM
   - ITM状态决定到期时是否盈利

### 系统架构特点

1. **服务分离**:
   - Fixture Service: 管理期权合约和定价（此API）
   - Client Service: 处理用户交易和账户管理
   - 这种分离有利于风控和系统稳定性

2. **实时性要求**:
   - WebSocket推送价格更新
   - 支持meta（合约状态）和tick（价格）两种订阅
   - 价格需要根据标的资产实时波动调整

3. **风险管理**:
   - `/newbet`端点用于风控验证
   - 可以拒绝高风险投注
   - 统计未平仓量(openInterest)

### 与现有系统集成建议

1. **数据模型映射**:
   - Fixture → Order (订单表)
   - Symbol → 交易对
   - Price → 赔率

2. **价格计算**:
   - 需要实现Black-Scholes或类似的期权定价模型
   - 根据剩余时间、波动率、标的价格实时计算

3. **WebSocket集成**:
   - 可以复用现有的market-service WebSocket架构
   - 添加fixture类型的消息推送

4. **风控集成**:
   - 在order-service中实现newbet验证逻辑
   - 检查用户余额、持仓限制等

这个API设计简洁清晰，适合快速实现二元期权交易功能。