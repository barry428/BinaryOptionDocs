# API响应状态码规范文档

## 概述

为规范二元期权平台API接口响应，统一状态码定义，提升接口调用体验和错误排查效率，特制定本规范。

**当前问题**: 几乎所有接口都返回200状态码，无法通过状态码快速判断请求结果
**目标**: 建立清晰的HTTP状态码 + 业务状态码体系，便于前端处理和运维监控

## 规范原则

### 1. 双层状态码设计
- **HTTP状态码**: 表示网络传输层面的结果
- **业务状态码**: 表示业务逻辑层面的结果

### 2. 语义化设计
- 状态码应清楚表达请求的处理结果
- 便于前端根据状态码做差异化处理
- 便于运维监控和日志分析

### 3. 状态码分类原则
- **2xx**: 成功响应
- **3xx**: 权限错误（特殊用途，非标准重定向）
- **4xx**: 常规错误（客户端错误）
- **5xx**: 系统错误（服务器错误）

## HTTP状态码规范

### 3xx Permission Error (权限错误)

> **注意**: 这是对3xx状态码的特殊使用，不用于标准的重定向场景

| 状态码 | 含义 | 使用场景 | 示例接口 |
|--------|------|----------|----------|
| **301** | Permission Denied | 权限不足 | VIP功能、等级限制 |
| **302** | Authentication Required | 需要认证 | 未登录或Token失效 |
| **303** | Access Restricted | 访问受限 | 访问他人资源、IP限制 |

### 4xx Client Error (常规错误)

| 状态码 | 含义 | 使用场景 | 示例接口 |
|--------|------|----------|----------|
| **400** | Bad Request | 请求参数错误、验证失败 | 订单金额无效、缺少必填参数 |
| **404** | Not Found | 资源不存在 | 订单不存在、用户不存在 |
| **409** | Conflict | 资源冲突 | 重复下单、状态冲突 |
| **422** | Unprocessable Entity | 业务规则验证失败 | 余额不足、风控拦截 |
| **429** | Too Many Requests | 请求频率超限 | 下单频率限制、API限流 |

### 5xx Server Error (服务器错误)

| 状态码 | 含义 | 使用场景 | 示例接口 |
|--------|------|----------|----------|
| **500** | Internal Server Error | 系统内部错误 | 数据库异常、未知错误 |
| **502** | Bad Gateway | 外部服务异常 | BTSE API调用失败 |
| **503** | Service Unavailable | 服务暂不可用 | 系统维护、服务重启 |
| **504** | Gateway Timeout | 网关超时 | 外部API超时、处理超时 |

## 业务状态码规范

### 业务状态码结构
```
ABCDE
├─ A: 服务模块 (1-9)
├─ B: 业务类型 (0-9) 
└─ CDE: 具体错误 (001-999)
```

### 模块编码定义

| 模块代码 | 模块名称 | 说明 |
|----------|----------|------|
| **1xxxx** | 用户模块 | 用户认证、信息管理 |
| **2xxxx** | 账户模块 | 余额管理、转账操作 |
| **3xxxx** | 订单模块 | 订单创建、查询、结算 |
| **4xxxx** | 风控模块 | 风险控制、合规检查 |
| **5xxxx** | 市场模块 | 行情数据、交易对管理 |
| **6xxxx** | 外部模块 | BTSE集成、第三方服务 |
| **9xxxx** | 系统模块 | 系统级错误、通用错误 |


## 接口实现规范

### 1. Response结构标准化

#### 成功响应
```json
{
  "code": 200,
  "message": "success", 
  "data": {
    // 业务数据
  },
  "timestamp": 1699000000000
}
```

#### 业务失败响应  
```json
{
  "code": 30002,
  "message": "订单状态不允许操作",
  "data": null,
  "timestamp": 1699000000000,
  "detail": {
    "orderId": "123456789",
    "currentStatus": "SETTLED", 
    "allowedOperations": ["VIEW"]
  }
}
```

#### 系统错误响应
```json
{
  "code": 90004,
  "message": "系统内部错误",
  "data": null,
  "timestamp": 1699000000000,
  "traceId": "abc123def456"
}
```

### 2. Controller实现示例

#### 下单接口优化示例
```java
@PostMapping
@Operation(summary = "Create order")
public ResponseEntity<Result<OrderDTO>> createOrder(@RequestBody @Valid OrderCreateRequestDTO request, 
                                                   HttpServletRequest httpRequest) {
    try {
        Long userId = getCurrentUserId();
        request.setUserId(userId);
        request.setClientIp(getClientIp(httpRequest));
        request.setUserAgent(httpRequest.getHeader("User-Agent"));
        
        Result<OrderDTO> result = orderService.createOrder(request);
        
        if (result.isSuccess()) {
            // 创建成功，返回201
            return ResponseEntity.status(HttpStatus.CREATED).body(result);
        } else {
            // 业务失败，根据业务错误码判断HTTP状态码
            HttpStatus httpStatus = mapBusinessCodeToHttpStatus(result.getCode());
            return ResponseEntity.status(httpStatus).body(result);
        }
        
    } catch (BusinessException e) {
        // 业务异常
        String message = messageUtils.getMessage(e.getMessageCode(), e.getArgs());
        Result<OrderDTO> result = Result.error(mapExceptionToBusinessCode(e), message);
        HttpStatus httpStatus = mapBusinessCodeToHttpStatus(result.getCode());
        return ResponseEntity.status(httpStatus).body(result);
        
    } catch (Exception e) {
        // 系统异常
        log.error("Create order failed", e);
        Result<OrderDTO> result = Result.error(90004, messageUtils.getMessage("order.create.failed"));
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(result);
    }
}
```

#### 业务码与HTTP状态码映射
```java
private HttpStatus mapBusinessCodeToHttpStatus(Integer businessCode) {
    if (businessCode == null) return HttpStatus.INTERNAL_SERVER_ERROR;
    
    int category = businessCode / 1000;
    
    return switch (category) {
        case 10 -> {
            // 用户模块：认证相关
            int subCode = businessCode % 1000;
            if (subCode <= 3) {
                yield HttpStatus.FOUND;  // 302 - 需要认证
            } else {
                yield HttpStatus.MOVED_PERMANENTLY;  // 301 - 权限不足
            }
        }
        case 20 -> HttpStatus.UNPROCESSABLE_ENTITY;  // 422 - 账户相关
        case 30 -> HttpStatus.BAD_REQUEST;   // 400 - 订单相关常规错误
        case 40 -> HttpStatus.SEE_OTHER;     // 303 - 风控限制，访问受限
        case 50 -> HttpStatus.SERVICE_UNAVAILABLE;  // 503 - 市场服务相关
        case 60 -> HttpStatus.BAD_GATEWAY;   // 502 - 外部服务相关
        case 90 -> HttpStatus.INTERNAL_SERVER_ERROR;  // 500 - 系统错误
        default -> HttpStatus.INTERNAL_SERVER_ERROR;  // 500 - 未知错误
    };
}
```

### 3. 错误处理优化

#### 全局异常处理器增强
```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(ValidationException.class)
    public ResponseEntity<Result<Void>> handleValidation(ValidationException e) {
        Result<Void> result = Result.error(90005, "参数验证失败");
        return ResponseEntity.badRequest().body(result);
    }
    
    @ExceptionHandler(BusinessException.class) 
    public ResponseEntity<Result<Void>> handleBusiness(BusinessException e) {
        Integer businessCode = mapExceptionToBusinessCode(e);
        Result<Void> result = Result.error(businessCode, e.getMessage());
        HttpStatus httpStatus = mapBusinessCodeToHttpStatus(businessCode);
        return ResponseEntity.status(httpStatus).body(result);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Result<Void>> handleGeneral(Exception e) {
        log.error("Unexpected error", e);
        Result<Void> result = Result.error(90004, "系统内部错误");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(result);
    }
}
```

## 前端处理指南

### 1. HTTP状态码优先处理
```javascript
// axios拦截器示例
axios.interceptors.response.use(
  response => {
    const { status, data } = response;
    
    // 根据HTTP状态码做差异化处理
    switch (Math.floor(status / 100)) {
      case 3:  // 3xx - 权限相关
        handlePermissionError(status, data);
        break;
      case 4:  // 4xx - 常规错误
        handleClientError(status, data);
        break;
    }
    
    return response;
  },
  error => {
    const { response } = error;
    
    if (!response) {
      message.error('网络异常，请检查网络连接');
      return Promise.reject(error);
    }
    
    const { status, data } = response;
    
    // 处理HTTP错误状态码
    switch (Math.floor(status / 100)) {
      case 3:  // 3xx - 权限错误
        if (status === 302) {
          // 需要登录
          message.warning('请先登录');
          router.push('/login');
        } else if (status === 301) {
          // 权限不足
          message.error('权限不足，无法访问该功能');
        } else if (status === 303) {
          // 访问受限
          message.error('访问受限: ' + (data?.message || ''));
        }
        break;
        
      case 4:  // 4xx - 常规错误
        if (status === 400) {
          message.error('请求参数错误: ' + (data?.message || ''));
        } else if (status === 404) {
          message.error('请求的资源不存在');
        } else if (status === 422) {
          message.error('业务处理失败: ' + (data?.message || ''));
        } else if (status === 429) {
          message.warning('请求过于频繁，请稍后重试');
        } else {
          message.error('请求失败: ' + (data?.message || ''));
        }
        break;
        
      case 5:  // 5xx - 系统错误
        if (status === 500) {
          message.error('服务器内部错误');
        } else if (status === 502) {
          message.error('外部服务异常');
        } else if (status === 503) {
          message.error('服务维护中');
        } else if (status === 504) {
          message.error('请求超时');
        } else {
          message.error('系统错误，请稍后重试');
        }
        break;
        
      default:
        message.error('未知错误');
    }
    
    return Promise.reject(error);
  }
);

// 权限错误处理函数
function handlePermissionError(status, data) {
  switch (status) {
    case 301:
      Modal.warning({
        title: '权限不足',
        content: '您的账户权限不足，无法使用此功能',
        onOk: () => router.push('/account/upgrade')
      });
      break;
    case 302:
      message.info('请先登录');
      router.push('/login');
      break;
    case 303:
      message.warning('访问受限: ' + (data?.message || ''));
      break;
  }
}

// 常规错误处理函数
function handleClientError(status, data) {
  switch (status) {
    case 400:
      message.error('参数错误: ' + (data?.message || ''));
      break;
    case 404:
      message.error('资源不存在');
      break;
    case 422:
      // 业务规则失败，显示详细信息
      if (data?.detail) {
        Modal.error({
          title: '操作失败',
          content: data.message,
          expandedContent: JSON.stringify(data.detail, null, 2)
        });
      } else {
        message.error(data?.message || '业务处理失败');
      }
      break;
    case 429:
      message.warning('操作过于频繁，请稍后重试');
      break;
  }
}
```

### 2. 业务状态码精确处理
```javascript
// 下单接口调用示例
async function createOrder(orderData) {
  try {
    const response = await axios.post('/api/borc/order', orderData);
    
    if (response.data.code === 200) {
      message.success('下单成功');
      return response.data.data;
    } else {
      // 根据业务状态码精确处理
      handleBusinessError(response.data.code, response.data.message);
      return null;
    }
    
  } catch (error) {
    // HTTP级别的错误已在拦截器处理
    console.error('Create order failed:', error);
    return null;
  }
}

function handleBusinessError(code, message) {
  const errorHandlers = {
    20002: () => {
      // 余额不足，引导充值
      Modal.confirm({
        title: '余额不足',
        content: '当前余额不足，是否前往充值？',
        onOk: () => router.push('/deposit')
      });
    },
    30006: () => {
      // 下单频率超限
      message.warning('下单过于频繁，请稍后重试');
    },
    40001: () => {
      // 风控拦截
      Modal.warning({
        title: '交易受限',
        content: '您的账户存在异常交易行为，请联系客服处理'
      });
    }
  };
  
  const handler = errorHandlers[code];
  if (handler) {
    handler();
  } else {
    message.error(message || '操作失败');
  }
}
```

## 实施计划

### Phase 1: 核心接口改造 (1周)
- [ ] 下单接口 (POST /api/borc/order)
- [ ] 订单查询接口 (GET /api/borc/order/{id})
- [ ] 订单取消接口 (POST /api/borc/order/{id}/cancel)
- [ ] 用户登录接口
- [ ] 账户余额接口

### Phase 2: 业务接口完善 (1周)  
- [ ] 历史订单接口
- [ ] 用户统计接口
- [ ] 转账相关接口
- [ ] 风控检查接口

### Phase 3: 系统接口规范化 (1周)
- [ ] 健康检查接口
- [ ] 配置管理接口  
- [ ] 监控接口
- [ ] RPC接口规范化

### Phase 4: 前端适配优化 (1周)
- [ ] 前端状态码处理逻辑更新
- [ ] 错误提示优化
- [ ] 用户体验提升
- [ ] 测试和验证

## 监控和运维

### 1. 日志记录
```java
// 在Controller中记录关键状态码信息
@PostMapping
public ResponseEntity<Result<OrderDTO>> createOrder(...) {
    // ... 业务逻辑
    
    // 记录响应状态
    log.info("Order creation response - userId:{}, httpStatus:{}, businessCode:{}, orderId:{}", 
            userId, httpStatus.value(), result.getCode(), 
            result.getData() != null ? result.getData().getId() : null);
    
    return ResponseEntity.status(httpStatus).body(result);
}
```

### 2. 监控指标
- HTTP状态码分布统计
- 业务状态码TOP错误统计  
- API响应时间监控
- 错误率监控和告警

### 3. 告警规则
```yaml
# Prometheus告警规则示例
- alert: HighBusinessErrorRate
  expr: rate(api_business_errors_total[5m]) > 0.1
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "业务错误率过高"
    description: "接口业务错误率超过10%"

- alert: HTTPErrorRate  
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "HTTP错误率过高"
    description: "5xx错误率超过5%"
```

## 最佳实践

### 1. 状态码选择原则
- **2xx成功**: 请求成功处理
- **3xx权限**: 认证授权相关错误（特殊用途）
- **4xx常规**: 参数验证、业务规则等常规错误
- **5xx系统**: 系统故障、外部服务异常

### 2. 错误信息设计
- **用户友好**: 错误信息要便于用户理解
- **开发友好**: 包含足够的调试信息
- **国际化支持**: 支持多语言错误提示

### 3. 兼容性考虑
- **渐进式改造**: 新接口使用新规范，老接口逐步迁移
- **向下兼容**: 保证前端现有逻辑不被破坏
- **文档同步**: 及时更新API文档和前端接入文档

### 4. 特殊说明
#### 关于3xx状态码的使用
传统HTTP协议中，3xx用于重定向。在本规范中，我们将3xx用于权限相关错误：
- **301**: 权限级别不足（如VIP功能）
- **302**: 需要登录认证
- **303**: 访问受限（如风控、IP限制）

这种设计让前端能够通过状态码快速区分：
- 是权限问题（3xx）还是业务错误（4xx）
- 是否需要引导用户登录或升级权限
- 便于统一的权限错误处理逻辑

---

**版本**: v1.0  
**创建日期**: 2025-11-06  
**维护团队**: Binary Option 开发团队  
**审批状态**: 待审批