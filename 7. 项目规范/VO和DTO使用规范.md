# DTO使用规范

## 📖 概述

本文档定义了二元期权交易平台项目中DTO（Data Transfer Object）的使用规范，旨在规范数据传输层的设计，提高代码的可维护性和一致性。

> **💡 架构选择说明**：在现代前后端分离架构中，我们推荐统一使用DTO，不再使用VO（View Object）的概念。后端专注于数据传输，前端负责所有展示格式化工作。

## 🎯 核心设计原则

| 类型 | 全称 | 用途 | 使用场景 | 命名规范 |
|-----|------|------|----------|---------|
| **DTO** | Data Transfer Object | 数据传输 | Service间、RPC调用、API请求响应、前端数据交换 | `XxxDTO`, `XxxRequestDTO`, `XxxResponseDTO` |

### 设计原则

1. **统一使用DTO**：所有数据传输场景都使用DTO，包括前端接口
2. **职责单一**：每个DTO只负责一种特定场景的数据结构
3. **无业务逻辑**：DTO不包含任何业务逻辑，保持"贫血"状态
4. **命名规范**：严格按照用途和场景命名
5. **前后端分离**：后端专注数据传输，前端负责展示格式化

## 📋 DTO分类详解

### 1. 请求DTO（RequestDTO）

**用途**：封装客户端请求参数

**命名规范**：`XxxRequestDTO`

**使用场景**：
- Controller接收POST/PUT请求体
- 复杂查询参数封装
- 表单提交数据

**示例**：
```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class OrderCreateRequestDTO {
    @JsonProperty("accountType")
    @NotBlank(message = "账户类型不能为空")
    private String accountType;
    
    @JsonProperty("symbolId")
    @NotNull(message = "交易对ID不能为空")
    private Long symbolId;
    
    // ... 其他请求字段
}
```

### 2. 响应DTO（ResponseDTO）

**用途**：封装API响应数据

**命名规范**：`XxxResponseDTO`

**使用场景**：
- 复杂操作的响应结果
- 包含多种数据类型的响应
- 需要特殊字段映射的响应

**示例**：
```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class LoginResponseDTO {
    @JsonProperty("token")
    private String token;
    
    @JsonProperty("userId")
    private Long userId;
    
    @JsonProperty("expiresIn")
    private Long expiresIn;
}
```

### 3. 实体传输DTO（EntityDTO）

**用途**：传输业务实体数据

**命名规范**：`XxxDTO`

**使用场景**：
- RPC服务间调用
- 缓存数据存储
- 消息队列传输
- API标准响应

**示例**：
```java
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class OrderDTO {
    @JsonProperty("orderId")
    private Long id;
    
    @JsonProperty("userId")
    private Long userId;
    
    @JsonProperty("accountType")
    private String accountType;
    
    // ... 其他业务字段
}
```

### 4. 通用DTO

**分页请求DTO**：
```java
public class PageRequestDTO {
    private Integer page = 1;
    private Integer size = 10;
    private String sortBy;
    private String sortDirection;
}
```

**查询条件DTO**：
```java
public class QueryConditionDTO {
    private Map<String, Object> filters;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
}
```

### 4. 分页响应DTO

**用途**：包装分页查询结果

**命名规范**：`PageResponseDTO<T>`

**示例**：
```java
@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class PageResponseDTO<T> {
    private List<T> records;
    private Long total;
    private Integer page;
    private Integer size;
    private Integer totalPages;
}
```

### 5. 统计数据DTO

**用途**：业务统计数据传输

**命名规范**：`XxxStatsDTO`

**示例**：
```java
@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class BusinessOverviewDTO {
    private Integer todayUsers;
    private Integer todayOrders;
    private BigDecimal todayAmount;
    private BigDecimal todayProfit;
}
```

## 🏗️ 层级使用规范

### Controller层

```java
@RestController
public class OrderController {
    
    // ✅ 使用RequestDTO接收请求参数
    @PostMapping
    public Result<OrderDTO> createOrder(@RequestBody @Valid OrderCreateRequestDTO request) {
        OrderDTO orderDTO = orderService.createOrder(request);
        return Result.success(orderDTO);
    }
    
    // ✅ 分页查询返回PageResponseDTO
    @PostMapping("/list")
    public Result<PageResponseDTO<OrderDTO>> getOrderList(
            @RequestBody @Valid PageRequestDTO pageRequest) {
        PageResponseDTO<OrderDTO> result = orderService.getOrderList(pageRequest);
        return Result.success(result);
    }
    
    // ✅ 统计数据返回统计DTO
    @GetMapping("/stats")
    public Result<BusinessOverviewDTO> getStats() {
        BusinessOverviewDTO statsDTO = statsService.getBusinessOverview();
        return Result.success(statsDTO);
    }
}
```

### Service层
```java
@Service
public class OrderService {
    
    // ✅ 正确：Service层之间使用DTO传输
    public OrderDTO createOrder(OrderCreateRequestDTO request) {
        // 业务逻辑处理
        Order order = // ... 创建订单
        return orderConverter.toDTO(order);
    }
    
    // ✅ 正确：组装展示数据返回VO
    public BusinessOverviewVO getBusinessOverview() {
        // 统计业务数据
        return BusinessOverviewVO.builder()
            .todayUsers(userCount)
            .todayOrders(orderCount)
            .build();
    }
}
```

### RPC层
```java
@RestController
@RequestMapping("/rpc")
public class OrderRpcController {
    
    // ✅ 正确：RPC调用使用DTO传输数据
    @GetMapping("/order/{id}")
    public Result<OrderDTO> getOrder(@PathVariable Long id) {
        OrderDTO order = orderService.getOrderById(id);
        return Result.success(order);
    }
    
    // ❌ 错误：RPC不应使用VO
    // public Result<OrderDetailVO> getOrderDetail() { ... }
}
```

## 🚨 常见问题与禁止事项

### ❌ 禁止的用法

1. **混用命名规范**：
```java
// ❌ 错误：Response类没有DTO后缀
public class BtseTransferResponse

// ✅ 正确：统一使用DTO后缀
public class BtseTransferResponseDTO
```

2. **DTO包含业务逻辑**：
```java
// ❌ 错误：DTO中包含业务方法
public class OrderDTO {
    private BigDecimal amount;
    
    // 错误：业务逻辑应该在Service层
    public boolean isValidAmount() { ... }
}

// ✅ 正确：DTO只包含数据字段
public class OrderDTO {
    private BigDecimal amount;
    // 只有getter/setter，没有业务逻辑
}
```

3. **不一致的字段映射**：
```java
// ❌ 错误：同一个实体的不同DTO使用不同的字段名
public class OrderDTO {
    @JsonProperty("orderId")  
    private Long id;
}

public class OrderDetailDTO {
    @JsonProperty("id")       // 不一致！
    private Long id;
}
```

### ⚠️ 需要重构的问题

1. **现有VO类需要重命名**：
   - `PageResultVO` → `PageResponseDTO`
   - `BusinessOverviewVO` → `BusinessOverviewDTO`
   - `MarketStatsVO` → `MarketStatsDTO`
   - `OrderDetailVO` → `OrderDetailDTO`

2. **BTSE模块命名不统一**：
   - 缺少DTO后缀的类需要重命名
   - 例如：`BtseTransferRequest` → `BtseTransferRequestDTO`

## 📝 JSON注解规范

所有DTO都必须包含以下注解：

### 必需注解
```java
@JsonInclude(JsonInclude.Include.NON_NULL)  // 排除null字段
public class XxxDTO {
    
    @JsonProperty("fieldName")  // 统一字段命名
    private Type field;
}
```

### 字段命名规范
- ID字段：使用具体业务含义，如`orderId`、`userId`、`symbolId`
- 时间字段：使用统一格式，如`createTime`、`updateTime`
- 金额字段：使用明确含义，如`orderAmount`、`frozenBalance`

## 🔧 实现建议

### 1. Converter模式
```java
@Component
public class OrderConverter {
    
    public OrderDTO toDTO(Order order) {
        return OrderDTO.builder()
            .id(order.getId())
            .userId(order.getUserId())
            // ... 字段映射
            .build();
    }
    
    public Order toEntity(OrderDTO dto) {
        // 反向转换
    }
}
```

### 2. 验证注解
```java
public class OrderCreateRequestDTO {
    
    @NotBlank(message = "账户类型不能为空")
    @Pattern(regexp = "DEMO|REAL", message = "账户类型必须为DEMO或REAL")
    private String accountType;
    
    @NotNull(message = "交易对ID不能为空")
    @Min(value = 1, message = "交易对ID必须大于0")
    private Long symbolId;
}
```

## 🎯 迁移指南

### 重构优先级

**高优先级**（立即重构）：
1. 重命名现有VO类为DTO：
   - `PageResultVO` → `PageResponseDTO`
   - `OrderDetailVO` → `OrderDetailDTO`
   - `BusinessOverviewVO` → `BusinessOverviewDTO`
   - `MarketStatsVO` → `MarketStatsDTO`

**中优先级**（近期重构）：
2. 统一BTSE模块命名规范
3. 完善缺失的ResponseDTO类
4. 更新所有Controller返回类型

**低优先级**（逐步优化）：
5. 完善JSON注解规范
6. 优化字段命名一致性

### 检查清单

在新增或修改DTO时，请检查：

- [ ] 命名是否符合规范（RequestDTO/ResponseDTO/DTO）
- [ ] 用途是否单一明确（数据传输）
- [ ] 是否添加了必需的JSON注解
- [ ] 字段命名是否统一规范
- [ ] 验证注解是否完整
- [ ] 是否有完整的JavaDoc注释
- [ ] 是否不包含任何业务逻辑

## 📚 参考示例

完整的示例文件可以参考：
- `OrderDTO.java` - 标准的实体传输DTO
- `OrderCreateRequestDTO.java` - 请求参数DTO
- `AccountDTO.java` - 带JSON注解的传输DTO  
- `PageResponseDTO.java` - 分页响应DTO
- `BusinessOverviewDTO.java` - 统计数据DTO

---

**最后更新时间**：2025-08-11
**版本**：v1.0
**维护人**：开发团队