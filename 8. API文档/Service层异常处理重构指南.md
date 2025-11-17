# Service层异常处理重构指南

## 概述

为了配合Controller层的错误码映射实现，需要对Service层进行相应的重构，统一异常处理模式，让Controller层能够更好地处理错误码映射。

## 重构原则

### 1. 统一返回模式
**修改前：** 混合使用Result<T>返回和BusinessException抛出
**修改后：** 统一使用直接返回数据 + BusinessException抛出

```java
// 修改前 - 混合模式
public Result<OrderDTO> createOrder(OrderCreateRequestDTO request) {
    try {
        // 业务逻辑
        return Result.success(data);
    } catch (Exception e) {
        return Result.error(message); // 有时返回Result.error
    }
}

public OrderDTO getOrder(Long id) {
    Order order = orderMapper.findById(id);
    if (order == null) {
        return null; // 有时返回null
    }
    return orderConverter.toDTO(order);
}

// 修改后 - 统一模式
public OrderDTO createOrder(OrderCreateRequestDTO request) {
    try {
        // 业务逻辑
        return orderConverter.toDTO(order);
    } catch (BusinessException e) {
        throw e; // 重新抛出业务异常
    } catch (Exception e) {
        throw new BusinessException(500, "order.create.failed", new Object[]{e.getMessage()});
    }
}

public OrderDTO getOrder(Long id) {
    Order order = orderMapper.findById(id);
    if (order == null) {
        throw new BusinessException(404, "order.not.found", new Object[]{id});
    }
    return orderConverter.toDTO(order);
}
```

### 2. 业务异常使用规范

```java
// 基本用法
throw new BusinessException(httpStatusCode, messageCode, messageArgs);

// 示例
throw new BusinessException(404, "order.not.found", new Object[]{orderId});
throw new BusinessException(422, "account.insufficient.balance", new Object[]{userId, amount});
throw new BusinessException(403, "risk.check.failed", new Object[]{userId, reason});
```

### 3. 错误码映射表

| 异常场景 | HTTP状态码 | 错误消息码 | 业务错误码 |
|---------|------------|------------|------------|
| 资源不存在 | 404 | `*.not.found` | 模块码xxx1 |
| 权限不足 | 403 | `*.access.denied` | 模块码xxx2 |
| 业务规则失败 | 422 | `*.business.rule.failed` | 模块码xxx3 |
| 参数无效 | 400 | `*.invalid.parameter` | 模块码xxx4 |
| 服务不可用 | 503 | `*.service.unavailable` | 模块码xxx5 |

## 具体重构示例

### 1. OrderService 重构

```java
@Service
public class OrderService {
    
    /**
     * 创建订单 - 重构后
     */
    @Transactional
    public OrderDTO createOrder(OrderCreateRequestDTO request) {
        try {
            // 1. 前置验证
            OrderCreationContext context = validateOrderRequest(request);
            
            // 2. 风控检查
            if (orderConfig.getRiskControlEnabled()) {
                RiskCheckResult riskResult = riskControlService.checkOrderRisk(request);
                if (!riskResult.isPass()) {
                    // 风控检查失败，抛出业务异常
                    String errorCode = riskResult.getErrorCode() != null ? 
                        riskResult.getErrorCode() : "risk.check.failed";
                    throw new BusinessException(403, errorCode, riskResult.getMessageArgs());
                }
            }
            
            // 3. 业务逻辑处理
            Order order = processOrderCreation(request, context);
            
            return orderConverter.toDTO(order);
            
        } catch (BusinessException e) {
            // 直接重新抛出业务异常
            throw e;
        } catch (Exception e) {
            // 将通用异常转换为业务异常
            throw new BusinessException(500, "order.create.failed", new Object[]{e.getMessage()});
        }
    }
    
    /**
     * 查询订单详情 - 重构后
     */
    @Transactional(readOnly = true)
    public OrderDTO getOrderById(Long id) {
        Order order = orderMapper.findById(id);
        if (order == null) {
            throw new BusinessException(404, "order.not.found", new Object[]{id});
        }
        return orderConverter.toDTO(order);
    }
    
    /**
     * 取消订单 - 重构后
     */
    @Transactional
    public boolean cancelOrder(Long orderId, Long userId) {
        Order order = orderMapper.findById(orderId);
        if (order == null) {
            throw new BusinessException(404, "order.not.found", new Object[]{orderId});
        }
        
        // 验证订单所有者
        if (!order.getUserId().equals(userId)) {
            throw new BusinessException(403, "order.access.denied", new Object[]{orderId, userId});
        }
        
        // 验证订单状态
        if (!BusinessConstants.OrderStatus.PENDING.equals(order.getStatus())) {
            throw new BusinessException(422, "order.cannot.cancel", new Object[]{orderId, order.getStatus()});
        }
        
        // 执行取消逻辑
        return executeCancelLogic(order);
    }
}
```

### 2. AccountService 重构

```java
@Service
public class AccountService {
    
    /**
     * 获取账户信息 - 重构后
     */
    @Transactional(readOnly = true)
    public AccountDTO getAccountByUserIdAndType(Long userId, String accountType) {
        Account account = accountMapper.findByUserIdAndAccountType(userId, accountType);
        if (account == null) {
            throw new BusinessException(404, "account.not.found", 
                new Object[]{userId, accountType});
        }
        return accountConverter.toDTO(account);
    }
    
    /**
     * 资金冻结 - 重构后
     */
    @Transactional
    public void freezeBalance(Long userId, String accountType, BigDecimal amount) {
        Account account = getAccountEntity(userId, accountType);
        
        if (account.getBalance().compareTo(amount) < 0) {
            throw new BusinessException(422, "account.insufficient.balance", 
                new Object[]{userId, accountType, amount, account.getBalance()});
        }
        
        // 执行冻结逻辑
        executeFreezeLogic(account, amount);
    }
    
    /**
     * 领取Demo奖金 - 重构后
     */
    @Transactional
    public boolean claimDemoBonus(Long userId) {
        // 检查用户状态
        Account demoAccount = getAccountEntity(userId, BusinessConstants.AccountType.DEMO);
        
        // 检查是否达到条件
        if (!canClaimBonus(demoAccount)) {
            throw new BusinessException(422, "account.claim.bonus.conditions.not.met", 
                new Object[]{userId, demoAccount.getBalance()});
        }
        
        // 执行领取逻辑
        return executeClaimLogic(demoAccount);
    }
}
```

### 3. 私有方法异常处理

```java
/**
 * 私有方法也应该抛出BusinessException
 */
private void validateUser(Long userId) {
    var result = userRpcClient.getUserById(userId);
    if (!result.isSuccess() || result.getData() == null) {
        throw new BusinessException(404, "user.not.found", new Object[]{userId});
    }
    if (result.getData().getStatus() != 1) {
        throw new BusinessException(403, "user.disabled", new Object[]{userId});
    }
}

private void validateAccountBalance(Long userId, String accountType, BigDecimal amount) {
    // REAL账户不需要检查本地余额
    if (BusinessConstants.AccountType.REAL.equals(accountType)) {
        return;
    }
    
    var result = accountRpcClient.getAccountBalance(userId, accountType);
    if (!result.isSuccess() || result.getData() == null) {
        throw new BusinessException(404, "account.not.found", new Object[]{userId, accountType});
    }
    
    AccountDTO balance = result.getData();
    if (balance.getAvailableAmount().compareTo(amount) < 0) {
        throw new BusinessException(422, "account.insufficient.balance", 
            new Object[]{userId, accountType, amount});
    }
}
```

## Controller层适配

### 1. 方法返回类型调整

```java
// 修改前
public Result<OrderDTO> createOrder(@RequestBody OrderCreateRequestDTO request) {
    Result<OrderDTO> result = orderService.createOrder(request);
    return result;
}

// 修改后
public ResponseEntity<Result<OrderDTO>> createOrder(@RequestBody OrderCreateRequestDTO request) {
    try {
        OrderDTO orderDTO = orderService.createOrder(request);
        return errorCodeMapper.createSuccessResponse(orderDTO, HttpStatus.CREATED);
    } catch (BusinessException e) {
        return errorCodeMapper.handleBusinessException(e);
    } catch (Exception e) {
        return errorCodeMapper.handleGenericException(e, "order.create.failed");
    }
}
```

### 2. 异常处理模式

```java
@GetMapping("/{id}")
public ResponseEntity<Result<OrderDTO>> getOrder(@PathVariable Long id) {
    try {
        OrderDTO order = orderService.getOrderById(id);
        return errorCodeMapper.createSuccessResponse(order);
    } catch (BusinessException e) {
        // BusinessException会被errorCodeMapper自动映射为合适的HTTP状态码
        return errorCodeMapper.handleBusinessException(e);
    } catch (Exception e) {
        return errorCodeMapper.handleGenericException(e, "order.query.failed");
    }
}
```

## 重构步骤

### Step 1: 修改Service方法签名
1. 将返回类型从`Result<T>`改为直接返回`T`
2. 添加`throws BusinessException`声明（可选，运行时异常无需声明）

### Step 2: 替换错误处理逻辑
1. 将`return Result.error(...)`替换为`throw new BusinessException(...)`
2. 将`return null`替换为`throw new BusinessException(404, "*.not.found", ...)`

### Step 3: 统一异常转换
1. 在catch块中将通用Exception转换为BusinessException
2. 保持BusinessException直接重新抛出

### Step 4: 更新Controller
1. 修改方法返回类型为`ResponseEntity<Result<T>>`
2. 使用try-catch处理Service抛出的异常
3. 使用errorCodeMapper构建响应

### Step 5: 测试验证
1. 测试正常流程返回正确的HTTP状态码
2. 测试异常情况返回正确的错误码和状态码
3. 验证国际化消息正常工作

## 注意事项

### 1. 异常链保持
```java
try {
    // 业务逻辑
} catch (DataAccessException e) {
    // 保持原始异常信息
    throw new BusinessException(500, "database.access.failed", new Object[]{e.getMessage()}, e);
}
```

### 2. 事务回滚
```java
@Transactional
public OrderDTO createOrder(OrderCreateRequestDTO request) {
    // BusinessException会自动触发事务回滚
    // RuntimeException及其子类默认回滚事务
}
```

### 3. 日志记录
```java
try {
    // 业务逻辑
} catch (Exception e) {
    log.error("Order creation failed - userId:{}, request:{}", request.getUserId(), request, e);
    throw new BusinessException(500, "order.create.failed", new Object[]{e.getMessage()});
}
```

### 4. 参数验证
```java
public OrderDTO getOrder(Long id) {
    if (id == null || id <= 0) {
        throw new BusinessException(400, "order.invalid.id", new Object[]{id});
    }
    // 继续业务逻辑
}
```

## 优势

1. **统一性** - 所有Service方法使用相同的异常处理模式
2. **清晰性** - 错误处理逻辑集中在Controller层
3. **可维护性** - 错误码映射集中管理，易于修改
4. **扩展性** - 新增错误类型只需要在映射表中添加
5. **测试友好** - 异常处理逻辑独立，易于单元测试

---

**版本**: v1.0  
**创建日期**: 2025-11-06  
**维护团队**: Binary Option 开发团队