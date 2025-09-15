# Fixture 实际需要的参数

## 项目需求概述

根据我们二元期权交易平台的实际业务需求，以下是各个接口和功能模块所需的具体参数。

## 1. WebSocket 实时推送需求

### 1.1 历史价格数据
- **标的资产历史价格**（Historical Price）
  - 开盘价（Open）
  - 最高价（High）
  - 最低价（Low）
  - 收盘价（Close）
  - 时间戳（Timestamp）
- **用途**：用于绘制K线图和价格走势图
- **更新频率**：每秒推送一次

### 1.2 实时行情数据
- **当前标的价格**（Current Underlying Price）
- **交易对符号**（Symbol）
- **价格变化率**（Change Percentage）

## 2. API 交易接口需求

### 2.1 下单时需要的参数
- **当前下单价格**（Strike Price）
  - 说明：用户下单时的标的资产价格，作为执行价格
- **看涨赔率**（Call Odds / Up Payout）
  - 说明：选择"涨"时的赔率（如 1.95）
- **看跌赔率**（Put Odds / Down Payout）  
  - 说明：选择"跌"时的赔率（如 1.95）
- **交易对**（Symbol）
- **到期时间**（Expiry Time）
- **最小/最大下注金额**（Min/Max Bet Amount）

### 2.2 结算时需要的参数
- **结算时刻的标的价格**（Settlement Price）
- **结算时刻的看涨赔率**（Settlement Call Odds）
- **结算时刻的看跌赔率**（Settlement Put Odds）
- **订单状态**（Order Status: WIN/LOSE/DRAW）
- **盈亏金额**（Profit/Loss Amount）

## 3. 对冲接口需求

### 3.1 订单对冲参数
- **订单ID**（Order ID）
- **下单价格**（Entry Price）
  - 说明：用户下单时的执行价格
- **方向**（Direction）
  - UP（看涨）
  - DOWN（看跌）
- **数量/金额**（Amount）
  - 说明：需要对冲的金额
- **交易对**（Symbol）
- **到期时间**（Expiry Time）
- **当前标的价格**（Current Underlying Price）
  - 说明：用于计算对冲比例

## 4. 数据结构示例

### 4.1 下单请求示例
```json
{
  "symbol": "BTCUSDT",
  "strike_price": 50000.00,
  "direction": "UP",
  "amount": 100.00,
  "call_odds": 1.95,
  "put_odds": 1.95,
  "expiry_time": "2025-01-15T10:30:00Z"
}
```

### 4.2 结算响应示例
```json
{
  "order_id": "ORD123456",
  "settlement_price": 50100.00,
  "strike_price": 50000.00,
  "direction": "UP",
  "status": "WIN",
  "profit": 95.00,
  "settlement_call_odds": 1.95,
  "settlement_put_odds": 1.95
}
```

### 4.3 对冲请求示例
```json
{
  "order_id": "ORD123456",
  "symbol": "BTCUSDT",
  "entry_price": 50000.00,
  "direction": "UP",
  "amount": 100.00,
  "current_price": 50050.00,
  "expiry_time": "2025-01-15T10:30:00Z"
}
```

## 5. 注意事项

### 5.1 价格精度
- 所有价格字段需保留合适的小数位数（如BTCUSDT保留2位）
- 赔率通常保留2-3位小数

### 5.2 时间处理
- 所有时间使用UTC时区
- 时间格式遵循ISO 8601标准

### 5.3 数据更新频率
- WebSocket历史价格：每秒更新
- 当前价格：实时更新
- 赔率：根据市场波动动态调整

### 5.4 对冲策略
- 对冲金额根据用户下注金额和当前风险敞口计算
- 需要实时监控标的价格变化
- 在临近到期时可能需要调整对冲仓位

## 6. 与Fixture调整的关系

根据之前的fixture调整：
- **Partial Fixture**（部分合约）：对应我们的"可下单合约"，提供当前赔率
- **Full Fixture**（完整合约）：对应我们的"已下单合约"，包含固定的执行价格和方向
- 优化了数据传输，避免重复传输标的价格
- 历史数据只包含标的资产价格，不包含合约价格历史

## 7. 实施建议

1. **数据缓存**：频繁查询的数据（如当前赔率）应适当缓存
2. **并发处理**：下单和对冲操作需要考虑并发安全
3. **风控检查**：所有交易操作前需进行风控验证
4. **日志记录**：记录所有关键参数用于审计和问题排查