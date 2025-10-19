# AOP 安全验证架构

## 概述
通过 AOP 切面实现统一的输入安全验证，自动对所有 Controller 的请求 DTO 进行安全检查，避免代码重复和遗漏。

## 架构优势

### 替代方案对比
- **原方案**: 每个 Service 方法手动调用 `validateAndSanitizeInput()`
- **新方案**: AOP 切面自动拦截所有 Controller 请求进行验证

### 优势
1. **自动化**: 无需手动添加验证调用
2. **统一性**: 所有接口使用相同的验证逻辑
3. **可维护性**: 安全规则集中管理
4. **不易遗漏**: 新接口自动获得安全保护

## 实现组件

### 1. 核心切面类
**位置**: `option-common-utils/src/main/java/com/binaryoption/commonutils/validation/SecurityValidationAspect.java`

**功能**:
- 拦截所有 `@PostMapping`, `@PutMapping`, `@RequestMapping` 方法
- 自动识别 RequestDTO 类型（以 `RequestDTO`, `CreateDTO`, `UpdateDTO` 结尾）
- 根据字段类型执行相应的安全验证

### 2. 验证工具类
**InputSecurityValidator**: SQL注入、XSS攻击、输入长度验证
**NumericSecurityValidator**: 数值溢出、ID字段验证

### 3. 验证规则

#### 字符串字段验证
- **SQL注入检查**: `accountType`, `direction`, `status`, `symbol` 等枚举字段
- **XSS攻击检查**: `userAgent`, `deviceId`, `description`, `remark` 等用户输入字段
- **长度限制**: 根据字段名自动应用合适的长度限制

#### 数值字段验证
- **ID字段**: 必须为正数，范围检查
- **普通数值**: 溢出检查，精度检查
- **BigDecimal**: 范围和精度限制

## 配置要求

### 服务启用要求
每个使用安全验证的服务需要：

1. **引入依赖**: 包含 `option-common-utils` 模块
2. **启用AOP**: 主类添加 `@EnableAspectJAutoProxy`
3. **组件扫描**: `@ComponentScan` 包含 `com.binaryoption.commonutils`

### 当前已配置服务
- ✅ `option-order-service`
- ✅ `option-common-service`
- ✅ `option-market-service` (通过ComponentScan)

## 国际化支持

### 错误消息配置
在各服务的 `messages.properties` 中添加：
```properties
# Security validation messages
input.contains.sql.injection=Field {0} contains potential SQL injection
input.contains.xss.attack=Field {0} contains potential XSS attack
input.too.long=Field {0} exceeds maximum length of {1} characters
input.numeric.overflow=Field {0} contains numeric overflow
input.decimal.overflow=Field {0} contains decimal overflow
input.decimal.precision.too.high=Field {0} decimal precision is too high
input.id.must.positive=Field {0} must be a positive number
input.validation.error=Input security validation failed
```

## 测试验证

### 测试接口
**位置**: `SecurityTestController` (order-service)

**测试用例**:
1. **正常请求**: 验证切面不影响正常功能
2. **SQL注入**: 测试恶意SQL语句检测
3. **XSS攻击**: 测试恶意脚本检测
4. **数值溢出**: 测试边界值攻击

### 测试方法
```bash
# 测试正常请求
curl -X POST http://localhost:8082/api/test/security/order \
  -H "Content-Type: application/json" \
  -d '{"accountType":"DEMO","direction":"UP","symbolId":1,"amount":10.00}'

# 测试SQL注入检测
curl -X POST http://localhost:8082/api/test/security/sql-injection \
  -H "Content-Type: application/json" \
  -d '{"accountType":"DEMO; DROP TABLE users;","direction":"UP"}'

# 测试XSS攻击检测
curl -X POST http://localhost:8082/api/test/security/xss-attack \
  -H "Content-Type: application/json" \
  -d '{"userAgent":"<script>alert(1)</script>","deviceId":"normal"}'
```

## 扩展指导

### 新增验证规则
在 `SecurityValidationAspect.java` 中扩展：
1. 修改 `validateStringField()` 添加新的字符串验证
2. 修改 `getMaxLengthForField()` 调整长度限制
3. 添加新的字段类型验证方法

### 新增DTO支持
切面自动识别以下模式的类：
- `*RequestDTO`
- `*CreateDTO`
- `*UpdateDTO`

### 性能考虑
- 反射操作已优化，仅对必要字段执行
- 验证逻辑轻量级，对性能影响最小
- 可通过日志监控验证耗时

## 安全威胁防护

### 防护范围
1. **SQL注入**: 防止恶意SQL语句执行
2. **XSS攻击**: 防止恶意脚本注入
3. **数值溢出**: 防止边界值攻击
4. **长度攻击**: 防止缓冲区溢出
5. **精度攻击**: 防止高精度数值攻击

### 安全级别
- **阻断级**: SQL注入、XSS攻击、数值溢出
- **记录级**: 可疑边界值、异常模式
- **通过级**: 正常业务数据

## 维护指导

### 日志监控
- `DEBUG`: 正常验证通过
- `WARN`: 检测到安全威胁
- `ERROR`: 验证过程异常

### 定期检查
1. 监控安全威胁检测日志
2. 更新威胁特征库
3. 调整验证规则严格度
4. 性能影响评估