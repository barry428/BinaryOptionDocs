# Binary Option Platform API Documentation

## Overview

This document provides comprehensive API documentation for the Binary Option Trading Platform. The platform consists of multiple microservices that handle different aspects of the trading system.

### Service Architecture

- **option-common-service** (Port 8081): Account management, BTSE integration, User management
- **option-order-service** (Port 8082): Order processing, Risk control, Trading rounds

### Base URLs

- Common Service: `http://localhost:8081`
- Order Service: `http://localhost:8082`

### Authentication

All APIs require authentication via OAuth token passed through the Gateway. The user ID is extracted from the `X-User-Id` header set by the Gateway.

---

## 1. Account Management APIs

### 1.1 Get Account List

**Endpoint:** `GET /api/borc/account/list`

**Description:** Retrieves all accounts for the current authenticated user.

**Request Headers:**
```
X-User-Id: {userId}
```

**Response:**
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

### 1.2 Get Account Balance

**Endpoint:** `GET /api/borc/account/balance/{accountType}`

**Description:** Retrieves balance information for a specific account type.

**Path Parameters:**
- `accountType` (string, required): Account type - `REAL` or `DEMO`

**Request Headers:**
```
X-User-Id: {userId}
```

**Response:**
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

## 2. User Management APIs

### 2.1 Get User Profile

**Endpoint:** `GET /api/borc/user/profile`

**Description:** Retrieves current user's profile information.

**Request Headers:**
```
X-User-Id: {userId}
```

**Response:**
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

### 2.2 Update User Agreements

**Endpoint:** `PUT /api/borc/user/agreements`

**Description:** Updates user's agreement consent status.

**Request Headers:**
```
X-User-Id: {userId}
```

**Query Parameters:**
- `riskAgreement` (byte, required): Risk agreement status - `0` (Not agreed) or `1` (Agreed)
- `amlAgreement` (byte, required): AML agreement status - `0` (Not agreed) or `1` (Agreed)

**Response:**
```json
{
  "code": 200,
  "message": "success",
  "data": null
}
```

---

## 4. Order Management APIs

### 4.1 Create Order

**Endpoint:** `POST /api/borc/order`

**Description:** Creates a new binary option order.

**Request Headers:**
```
X-User-Id: {userId}
Content-Type: application/json
User-Agent: {userAgent}
X-Forwarded-For: {clientIp}
```

**Request Body:**
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

**Field Descriptions:**
- `symbolId`: Trading pair ID
- `accountType`: Account type (`REAL` or `DEMO`)
- `amount`: Order amount
- `duration`: Order duration in seconds
- `direction`: Trading direction (`UP` or `DOWN`)

**Response:**
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

### 4.2 Get Order Details

**Endpoint:** `GET /api/borc/order/{id}`

**Description:** Retrieves order details by order ID.

**Path Parameters:**
- `id` (long, required): Order ID

**Request Headers:**
```
X-User-Id: {userId}
```

**Response:**
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

### 4.3 Get Historical Orders

**Endpoint:** `POST /api/borc/order/list/history`

**Description:** Retrieves user's historical orders grouped by trading rounds.

**Request Headers:**
```
X-User-Id: {userId}
Content-Type: application/json
```

**Query Parameters:**
- `accountType` (string, optional): Account type filter

**Request Body:**
```json
{
  "pageNum": 1,
  "pageSize": 10,
  "sortField": "createTime",
  "sortOrder": "DESC"
}
```

**Response:**
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

### 4.4 Get Orders by Round

**Endpoint:** `GET /api/borc/order/list/round/{roundId}`

**Description:** Retrieves all orders for a specific trading round.

**Path Parameters:**
- `roundId` (long, required): Trading round ID

**Query Parameters:**
- `accountType` (string, optional): Account type filter

**Request Headers:**
```
X-User-Id: {userId}
```

**Response:**
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

### 4.5 Get Order Statistics

**Endpoint:** `GET /api/borc/order/stats`

**Description:** Retrieves user's order statistics summary.

**Query Parameters:**
- `accountType` (string, optional): Account type filter

**Request Headers:**
```
X-User-Id: {userId}
```

**Response:**
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

## 3. Public APIs (No Authentication Required)

### 3.1 Get Trading Symbols

**Endpoint:** `GET /api/borc/public/order/symbols`

**Description:** Retrieves list of all active trading pairs.

**Response:**
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

### 3.2 Get Current Trading Rounds

**Endpoint:** `GET /api/borc/public/order/round/current/{symbolId}`

**Description:** Retrieves current active trading rounds for a symbol.

**Path Parameters:**
- `symbolId` (long, required): Trading pair ID

**Response:**
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

### 3.3 Get Market History

**Endpoint:** `POST /api/borc/public/order/market/history`

**Description:** Retrieves historical market data for option contracts.

**Request Body:**
```json
{
  "symbol": "BTC-USDT",
  "expiration": "2024-01-01T15:35:00",
  "side": "UP",
  "limitAfter": 100
}
```

**Response:**
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

## Error Handling

### Standard Error Response Format

```json
{
  "code": 400,
  "message": "Error description",
  "data": null
}
```

### Common Error Codes

- `200`: Success
- `400`: Bad Request (validation error, business logic error)
- `401`: Unauthorized (authentication required)
- `403`: Forbidden (access denied)
- `404`: Not Found
- `500`: Internal Server Error

### Business Error Messages

All error messages support internationalization and are returned based on the client's locale. Common business errors include:

- `account.not.found`: Account not found
- `account.balance.insufficient`: Insufficient account balance
- `order.create.failed`: Order creation failed
- `order.not.found`: Order not found
- `order.access.denied`: Access denied to order
- `transfer.deposit.failed`: Deposit failed
- `transfer.withdraw.failed`: Withdrawal failed
- `user.not.found`: User not found

---

## Request/Response Examples

### Example: Create Order Flow

1. **Get Trading Symbols**
```bash
curl -X GET "http://localhost:8082/api/borc/public/order/symbols"
```

2. **Get Current Trading Rounds**
```bash
curl -X GET "http://localhost:8082/api/borc/public/order/round/current/1"
```

3. **Create Order**
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

### Example: Account Balance Check

**Check Account Balance**
```bash
curl -X GET "http://localhost:8081/api/borc/account/balance/REAL" \
  -H "X-User-Id: 123"
```

---

## Rate Limiting

- Default rate limit: 100 requests per minute per user
- Transfer operations: 10 requests per minute per user
- Order creation: 20 requests per minute per user

Rate limiting is implemented at the Gateway level and returns HTTP 429 status when exceeded.

---

## API Versioning

Current API version: v1

APIs are versioned through URL path. Future versions will be available as:
- `/api/borc/v2/...`

Backward compatibility is maintained for at least 6 months after new version release.

---

## WebSocket APIs (Market Service)

### Market Data Streaming

**Endpoint:** `ws://localhost:8083/ws/market`

**Message Format:**
```json
{
  "action": "subscribe",
  "symbol": "BTC-USDT"
}
```

**Real-time Market Data:**
```json
{
  "symbol": "BTC-USDT",
  "price": "45000.00",
  "timestamp": "2024-01-01T15:30:00Z",
  "volume": "1500.00",
  "change24h": "2.5"
}
```

Supported actions: `subscribe`, `unsubscribe`, `ping`, `pong`

---

This documentation covers all the controller endpoints in the Binary Option Platform. For additional technical details, refer to the source code comments and the Swagger UI available at each service's `/swagger-ui.html` endpoint.