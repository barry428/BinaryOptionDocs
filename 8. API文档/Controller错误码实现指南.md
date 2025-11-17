# Controller错误码实现指南

## 概述

为了在Controller层实现统一的错误码和HTTP状态码映射，我们提供了`ApiErrorCodeMapper`工具类，主要在Controller层进行修改，无需大幅改动Service层。

## 核心组件

### 1. ApiErrorCodeMapper 错误码映射器

位置：`option-common-utils/src/main/java/com/binaryoption/commonutils/http/ApiErrorCodeMapper.java`

**主要功能：**
- 将业务错误消息码映射为结构化的业务错误码（如10xxx、20xxx等）
- 根据业务错误码自动确定HTTP状态码
- 提供统一的响应格式

**核心方法：**
```java
// 处理业务异常
ResponseEntity<Result<Void>> handleBusinessException(BusinessException e)

// 处理通用异常
ResponseEntity<Result<Void>> handleGenericException(Exception e, String defaultMessageCode)

// 创建成功响应
ResponseEntity<Result<T>> createSuccessResponse(T data)
ResponseEntity<Result<T>> createSuccessResponse(T data, HttpStatus httpStatus)

// 创建错误响应
ResponseEntity<Result<Void>> createErrorResponse(String messageCode)
```

### 2. GlobalApiExceptionHandler 全局异常处理器

位置：`option-common-utils/src/main/java/com/binaryoption/commonutils/http/GlobalApiExceptionHandler.java`

**功能：** 处理Controller层未捕获的异常，作为兜底处理机制。

## 错误码映射规则

### 业务错误码结构
```
ABCDE
├─ A: 服务模块 (1-9)
├─ B: 业务类型 (0-9) 
└─ CDE: 具体错误 (001-999)
```

### HTTP状态码映射表

| 模块 | 业务错误码 | HTTP状态码 | 说明 |
|------|------------|------------|------|
| 用户模块 | 10xxx | 302 | 需要认证 |
| 账户模块 | 20xxx | 422 | 业务规则失败 |
| 订单模块 | 30xxx | 400 | 请求参数错误 |
| 风控模块 | 40xxx | 303 | 访问受限 |
| 市场模块 | 50xxx | 503 | 服务不可用 |
| 外部服务 | 60xxx | 502 | 网关错误 |
| 系统模块 | 90xxx | 500 | 系统错误 |

### 错误消息码到业务错误码映射

```java
// 用户模块示例
"user.not.found" -> 10002
"user.disabled" -> 10005
"user.not.authenticated" -> 10001

// 账户模块示例  
"account.not.found" -> 20001
"account.insufficient.balance" -> 20002
"account.freeze.failed" -> 20005

// 订单模块示例
"order.not.found" -> 30001
"order.create.failed" -> 30003
"trading.round.not.found" -> 30005
```

## Controller实现示例

### 1. 依赖注入

```java
@RestController
@RequiredArgsConstructor
public class OrderController {
    
    private final OrderService orderService;
    private final ApiErrorCodeMapper errorCodeMapper; // 注入错误码映射器
    
    // ...
}
```

### 2. 成功响应处理

```java
@PostMapping
public ResponseEntity<Result<OrderDTO>> createOrder(@RequestBody @Valid OrderCreateRequestDTO request) {
    try {
        Result<OrderDTO> result = orderService.createOrder(request);
        if (result.isSuccess()) {
            // 创建成功，返回201 Created
            return errorCodeMapper.createSuccessResponse(result.getData(), HttpStatus.CREATED);
        } else {
            // Service返回业务错误
            return errorCodeMapper.createErrorResponse("order.create.failed");
        }
    } catch (BusinessException e) {
        return errorCodeMapper.handleBusinessException(e);
    } catch (Exception e) {
        return errorCodeMapper.handleGenericException(e, "order.create.failed");
    }
}
```

### 3. 查询响应处理

```java
@GetMapping("/{id}")
public ResponseEntity<Result<OrderDTO>> getOrder(@PathVariable Long id) {
    try {
        OrderDTO order = orderService.getOrderById(id);
        
        if (order == null) {
            // 订单不存在 -> 30001 -> 400 Bad Request
            return errorCodeMapper.createErrorResponse("order.not.found");
        }
        
        // 权限检查
        if (!order.getUserId().equals(getCurrentUserId())) {
            // 访问拒绝 -> 30002 -> 400 Bad Request  
            return errorCodeMapper.createErrorResponse("order.access.denied");
        }
        
        // 查询成功 -> 200 OK
        return errorCodeMapper.createSuccessResponse(order);
        
    } catch (Exception e) {
        return errorCodeMapper.handleGenericException(e, "order.query.failed");
    }
}
```

### 4. 账户相关接口示例

```java
@GetMapping("/balance/{accountType}")
public ResponseEntity<Result<AccountDTO>> getAccountBalance(@PathVariable String accountType) {
    try {
        Long userId = getCurrentUserId();
        AccountDTO balance = accountService.getAccountBalance(userId, accountType);
        
        if (balance == null) {
            // 账户不存在 -> 20001 -> 422 Unprocessable Entity
            return errorCodeMapper.createErrorResponse("account.not.found");
        }
        
        return errorCodeMapper.createSuccessResponse(balance);
        
    } catch (Exception e) {
        return errorCodeMapper.handleGenericException(e, "account.balance.query.failed");
    }
}
```

## 响应格式示例

### 成功响应
```json
HTTP/1.1 200 OK
Content-Type: application/json

{
  "code": 200,
  "message": "success",
  "data": {
    "id": 12345,
    "amount": 100.00,
    "status": "ACTIVE"
  },
  "timestamp": 1699000000000
}
```

### 业务错误响应  
```json
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "code": 30001,
  "message": "Order not found",
  "data": null,
  "timestamp": 1699000000000
}
```

### 权限错误响应
```json
HTTP/1.1 302 Found
Content-Type: application/json

{
  "code": 10001,
  "message": "User not authenticated",
  "data": null,
  "timestamp": 1699000000000
}
```

### 业务规则失败响应
```json
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/json

{
  "code": 20002,
  "message": "Insufficient balance",
  "data": null,
  "timestamp": 1699000000000
}
```

### 系统错误响应
```json
HTTP/1.1 500 Internal Server Error
Content-Type: application/json

{
  "code": 90004,
  "message": "System internal error",
  "data": null,
  "timestamp": 1699000000000
}
```

## 实施步骤

### 1. 添加依赖注入
在Controller中注入`ApiErrorCodeMapper`：
```java
private final ApiErrorCodeMapper errorCodeMapper;
```

### 2. 修改方法返回类型
将方法返回类型从`Result<T>`改为`ResponseEntity<Result<T>>`：
```java
// 修改前
public Result<OrderDTO> createOrder(...)

// 修改后  
public ResponseEntity<Result<OrderDTO>> createOrder(...)
```

### 3. 替换响应构建逻辑
使用`errorCodeMapper`的方法替换原有的`Result.success()`和`Result.error()`：
```java
// 修改前
return Result.success(data);
return Result.error("Error message");

// 修改后
return errorCodeMapper.createSuccessResponse(data);
return errorCodeMapper.createErrorResponse("error.message.code");
```

### 4. 统一异常处理
使用错误码映射器处理异常：
```java
try {
    // 业务逻辑
} catch (BusinessException e) {
    return errorCodeMapper.handleBusinessException(e);
} catch (Exception e) {
    return errorCodeMapper.handleGenericException(e, "default.error.code");
}
```

## 优势

1. **最小侵入性** - 主要修改Controller层，Service层保持不变
2. **统一标准** - 所有API接口使用相同的错误码和状态码规范
3. **自动映射** - 错误消息码自动映射为结构化业务错误码和HTTP状态码
4. **易于维护** - 集中管理错误码映射关系
5. **国际化支持** - 继续使用MessageUtils的国际化机制
6. **向后兼容** - 现有Service层逻辑无需修改

## 注意事项

1. **错误消息码** - 确保使用的错误消息码在映射表中已定义
2. **HTTP状态码** - 根据业务场景选择合适的HTTP状态码
3. **异常处理** - 区分BusinessException和通用Exception
4. **响应格式** - 保持统一的JSON响应格式
5. **日志记录** - 错误码映射器会自动记录相关日志

---

**版本**: v1.0  
**创建日期**: 2025-11-06  
**维护团队**: Binary Option 开发团队