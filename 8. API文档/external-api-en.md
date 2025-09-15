# External API Documentation

## WebSocket Real-time Market Data

**Endpoint**: `<website>/v1/ws/`

### Subscribe Request
```json
{
    "subscribe": "tick",
    "symbol": "BTCUSDT"
}
```

### Market Data Push
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
            "strike": 65500.00, //not need
            "side": "call",
            "itm": false, //not need
            "price": 0.45
        },
        {
            "expiration": "2025-08-22 12:30:00",
            "strike": 65300.00, //not need
            "side": "put",
            "itm": true, //not need
            "price": 0.55
        }
    ]
}
```

## Options Contracts Query

**Endpoint**: `GET <website>/v1/api/fixtures`

### Request Parameters
**Query Parameters**:
- `symbol`: Trading pair symbol (e.g., "BTCUSDT")
- `includeExpiredAfter`: Include contracts expiring after this time (format: "2025-08-22 10:00:00")

**Example**:
```
GET <website>/v1/api/fixtures?symbol=BTCUSDT&includeExpiredAfter=2025-08-22%2010:00:00
```

### Response
```json
{
    "open": [
        {
            "expiration": "2025-08-22 12:30:00",
            "strike": 65500.00, //not need
            "side": "call",
            "itm": false, //not need
            "price": 0.45,
            "priceUnderlying": 65432.10,
            "openInterest": 1250, //not need
            "openInterestValue": 562.50 //not need
        },
        {
            "expiration": "2025-08-22 12:30:00",
            "strike": 65300.00, //not need
            "side": "put",
            "itm": true, //not need
            "price": 0.55,
            "priceUnderlying": 65432.10,
            "openInterest": 800, //not need
            "openInterestValue": 440.00 //not need
        }
    ],
    "closed": [
        {
            "expiration": "2025-08-22 12:00:00",
            "strike": 65000.00, //not need
            "side": "call",
            "itm": true, //not need
            "price": 0.45,
            "priceUnderlying": 65432.10,
            "openInterest": 0, //not need
            "openInterestValue": 0.00 //not need
        },
        {
            "expiration": "2025-08-22 12:00:00",
            "strike": 65000.00, //not need
            "side": "put",
            "itm": true, //not need
            "price": 0.55,
            "priceUnderlying": 65432.10,
            "openInterest": 0, //not need
            "openInterestValue": 0.00 //not need
        }
    ]
}
```

## Place Order

**Endpoint**: `POST <website>/v1/api/newbet`

### Request
```json
{
    "symbol": "BTCUSDT",
    "expiration": "2025-08-22 12:30:00",
    "strike": 65500.00, //not need
    "side": "call",
    "currentPrice": 65432.10,
    "price": 0.45,
    "amount": 100.00,
    "tradeId": 12345
}
```

### Response
```json
{
    "status": "ok",
    "message": "Order submitted successfully"
}
```

```json
{
    "status": "error",
    "message": "Order submission failed: Insufficient balance"
}
```

## Historical Data Query

**Endpoint**: `GET <website>/v1/api/history`

### Request Parameters
**Query Parameters**:
- `symbol`: Trading pair symbol (e.g., "BTCUSDT")
- `expiration`: Options expiration time (format: "2025-08-22 12:30:00")
- `side`: Options type ("put" for put options / "call" for call options)
- `limitAfter`: Limit data to after this time (format: "2025-08-22 10:00:00")

**Example**:
```
GET <website>/v1/api/history?symbol=BTCUSDT&expiration=2025-08-22%2012:30:00&side=call&limitAfter=2025-08-22%2010:00:00
```

### Response
```json
{
    "symbol": "BTCUSDT",
    "expiration": "2025-08-22 12:30:00",
    "side": "call",
    "history": [
        [1692700800000, 65432.10, 0.45],
        [1692700860000, 65435.20, 0.46],
        [1692700920000, 65440.50, 0.47],
        [1692700980000, 65438.30, 0.46]
    ]
}
```