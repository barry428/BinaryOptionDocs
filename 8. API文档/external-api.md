# 外部API接口

## WebSocket实时行情

**连接地址**: `<website>/v1/ws/`

### 订阅请求
```json
{
    "subscribe": "tick",
    "symbol": "BTCUSDT"
}
```

### 推送数据
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

## 期权合约查询

**接口地址**: `POST <website>/v1/api/fixtures`

### 请求
```json
{
    "symbol": "BTCUSDT",
    "includeExpiredAfter": "2025-08-22 10:00:00"
}
```

### 响应
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
            "price": 0.45,
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

## 下单接口

**接口地址**: `POST <website>/v1/api/newbet`

### 请求
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

### 响应
```json
{
    "status": "ok",
    "message": "订单提交成功"
}
```

```json
{
    "status": "error",
    "message": "订单提交失败：余额不足"
}
```

## 历史数据查询

**接口地址**: `POST <website>/v1/api/history`

### 请求
```json
{
    "symbol": "BTCUSDT",
    "expiration": "2025-08-22 12:30:00",
    "strike": 65500.00,
    "side": "call",
    "limitAfter": "2025-08-22 10:00:00"
}
```

### 响应
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