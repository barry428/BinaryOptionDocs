# TGW-3-1.5：聚合风险敞口控制 - 技术设计 v1.1

**项目**：二元期权第一阶段增强
**需求 ID**：TGW-3-1.5
**文档版本**：v1.1（轻量级方案）
**创建日期**：2026-01-09
**修订日期**：2026-01-13
**所有者**：开发团队
**修订说明**：
- 采用 Redis 熔断标志 + 定时任务方案
- 零数据库表结构变更，最小化对下单流程的入侵
- 优化文档结构，减少代码示例，增强文字描述清晰度
- 所有核心逻辑以文字流程说明为主，代码仅作为参考

---

## 目录

- [1. 需求分析](#1-需求分析)
- [2. 架构设计](#2-架构设计)
- [3. 数据结构设计](#3-数据结构设计)
- [4. 核心算法设计](#4-核心算法设计)
- [5. 定时任务设计](#5-定时任务设计)
- [6. API接口设计](#6-api接口设计)
- [7. 性能优化方案](#7-性能优化方案)
- [8. 监控和告警](#8-监控和告警)
- [9. 开发实施指南](#9-开发实施指南)

---

## 1. 需求分析

### 1.1 业务需求

**原始需求描述**：
> Aggregate total bet amount placed for each Up and Down directions across all users for each market > 50,000 USDT
>
> Temporarily suspend new bet placement for the affected market and direction in 15 mins
>
> Existing bets are not affected and will continue until expiration

**中文解读**：
- **检测条件**: 对于每个市场(交易对)，统计所有用户在某个方向(UP/DOWN)上的累计下注金额
- **触发阈值**: 单个方向累计金额 > 50,000 USDT
- **风控措施**: 暂停该市场该方向的新下注，持续15分钟
- **豁免范围**: 已存在的订单不受影响，继续到期结算

---

### 1.2 v1.1 版本设计目标

✅ **零数据库变更**：不修改任何数据库表结构
✅ **最小入侵**：对现有下单流程的修改最小化
✅ **Redis驱动**：熔断状态完全由Redis管理
✅ **配置驱动**：阈值和时长从配置表读取
✅ **异步统计**：定时任务独立计算敞口和触发熔断

---

## 2. 架构设计

### 2.1 方案对比

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| v2.0：数据库字段 | 数据持久化，重启不丢失 | 需要修改表结构，下单流程入侵大 | ❌ 不采用 |
| **v1.1：Redis + 定时任务** ⭐ | **零表变更，最小入侵，配置灵活** | Redis故障会影响熔断功能 | ✅ **推荐** |

**v1.1 方案优势**：
- ✅ 不需要修改 `bo_trading_round` 表结构
- ✅ 下单流程只需简单的Redis查询（< 1ms）
- ✅ 统计计算由定时任务独立完成
- ✅ 配置参数统一管理在 `bo_risk_config` 表
- ✅ Redis故障时自动降级，不影响下单（可选）

---

### 2.2 整体架构

**三层架构**：

```
┌─────────────────────────────────────────────────┐
│ Layer 1: 配置层                                   │
│ └─ bo_risk_config 表：阈值、时长等配置参数          │
└─────────────────────────────────────────────────┘
              ↓ 读取配置
┌─────────────────────────────────────────────────┐
│ Layer 2: Redis 缓存层（核心）                      │
│ ├─ 敞口累计：BO:Exposure:{roundId}:{direction}    │
│ │   └─ 每次下单后累加更新                          │
│ └─ 熔断状态：BO:Suspension:{roundId}:{direction}  │
│     └─ 下单时判断超限则设置                        │
└─────────────────────────────────────────────────┘
              ↓ 读写数据
┌─────────────────────────────────────────────────┐
│ Layer 3: 应用层                                   │
│ ├─ 下单流程：敞口检查 + 熔断判断 + 累计更新          │
│ └─ 定时任务：仅负责自动恢复过期熔断                 │
└─────────────────────────────────────────────────┘
```

**数据流向**：

```
下单流程（每次下单）
  ↓
1. 读取 Redis: BO:Suspension:{roundId}:{direction}
  ↓ (已熔断)
2. 返回拒绝结果
  ↓ (未熔断)
3. 读取 Redis: BO:Exposure:{roundId}:{direction} 获取当前累计金额
  ↓
4. 计算：当前累计 + 本次下单金额
  ↓
5. 判断是否 > 阈值
  ↓ (超限)
6. 设置 Redis: BO:Suspension:{roundId}:{direction} = {endTime}
  ↓ 并拒绝本次下单
  ↓ (未超限)
7. 原子更新 Redis: BO:Exposure:{roundId}:{direction} += 本次金额
  ↓
8. 更新数据库 bo_trading_round.total_*_amount
  ↓
9. 继续下单流程

定时任务（每分钟）
  ↓
仅负责清理过期熔断标志
```

---

## 3. 数据结构设计

### 3.1 Redis 数据结构

#### 3.1.1 敞口累计缓存

**Key格式**：`BO:Exposure:{roundId}:{direction}`

**数据类型**：String (存储数值)

**Value**：累计下单金额（BigDecimal转String）

**示例**：
```bash
redis> GET "BO:Exposure:12345:UP"
"48500.50"

redis> GET "BO:Exposure:12345:DOWN"
"35200.00"
```

**TTL**：轮次结束后30分钟自动过期

**更新方式**：
- 使用Redis INCRBYFLOAT命令原子性累加
- 每次下单成功后执行：`INCRBYFLOAT BO:Exposure:12345:UP 1000.00`
- 保证高并发下的数据一致性

---

#### 3.1.2 熔断状态缓存

**Key格式**：`BO:Suspension:{roundId}:{direction}`

**数据类型**：String (ISO 8601 时间戳)

**Value**：熔断结束时间（ISO 8601格式）

**TTL**：熔断结束后30分钟自动过期

**示例**：
```bash
# 已熔断
redis> GET "BO:Suspension:12345:UP"
"2026-01-12T10:45:00Z"

# 未熔断
redis> GET "BO:Suspension:12345:UP"
(nil)
```

**判断逻辑**：
```java
String suspendEndTime = redis.get("BO:Suspension:12345:UP");
if (suspendEndTime != null) {
    LocalDateTime endTime = LocalDateTime.parse(suspendEndTime);
    if (endTime.isAfter(LocalDateTime.now())) {
        // 仍在熔断期内
        return reject();
    }
}
// 未熔断或已到期
return pass();
```

---

### 3.2 配置表设计

**表名**：`bo_risk_config`（已存在）

**新增配置项**：

```sql
-- 插入聚合敞口控制配置
INSERT INTO bo_risk_config (config_key, config_value, description, enabled, create_time, update_time)
VALUES
    ('AGGREGATE_EXPOSURE_ENABLED', 'true',
     '聚合敞口控制开关', TRUE, NOW(), NOW()),

    ('AGGREGATE_EXPOSURE_THRESHOLD', '50000.00',
     '聚合敞口阈值(USDT)', TRUE, NOW(), NOW()),

    ('AGGREGATE_EXPOSURE_SUSPEND_MINUTES', '15',
     '熔断时长(分钟)', TRUE, NOW(), NOW()),

    ('AGGREGATE_EXPOSURE_CHECK_INTERVAL_SECONDS', '30',
     '敞口检查间隔(秒)', TRUE, NOW(), NOW());
```

**配置项说明**：

| 配置Key | 默认值 | 说明 | 可调整范围 |
|---------|--------|------|-----------|
| AGGREGATE_EXPOSURE_ENABLED | true | 功能总开关 | true/false |
| AGGREGATE_EXPOSURE_THRESHOLD | 50000.00 | 单方向敞口阈值(USDT) | 10000 - 1000000 |
| AGGREGATE_EXPOSURE_SUSPEND_MINUTES | 15 | 熔断持续时长(分钟) | 5 - 60 |
| AGGREGATE_EXPOSURE_CHECK_INTERVAL_SECONDS | 30 | 定时检查间隔(秒) | 10 - 300 |

---

### 3.3 数据库查询

**无需修改任何表结构**，仅使用现有数据：

```sql
-- 查询活跃轮次的敞口数据（定时任务使用）
SELECT
    id AS round_id,
    round_no,
    symbol_id,
    total_up_amount,
    total_down_amount,
    end_time
FROM bo_trading_round
WHERE status IN ('OPEN', 'LOCKED')
  AND end_time > NOW()
ORDER BY id;
```

**性能优化**：
- ✅ 使用已有索引：`idx_trading_round_status`
- ✅ 查询时间 < 50ms（100个活跃轮次）
- ✅ 每30秒执行一次，负载可控

---

## 4. 核心算法设计

### 4.1 下单时敞口检查和熔断判断（核心优化）

**集成位置**：`RiskControlService.checkOrderRisk()`

**设计原则**：
- ✅ 下单时实时判断：读取Redis累计金额 + 本次金额，判断是否超限
- ✅ 原子操作保证：使用Redis原子命令，避免并发问题
- ✅ 零数据库查询：完全基于Redis操作
- ✅ 快速响应：< 1ms（2-3次Redis操作）
- ✅ 优雅降级：Redis故障时可选择跳过或拒绝

---

#### 4.1.1 检查流程说明

**Step 1: 功能开关检查**
- 从配置服务读取 `AGGREGATE_EXPOSURE_ENABLED` 开关
- 若关闭则直接通过，不执行任何检查

**Step 2: 读取Redis熔断状态**
- Redis Key：`BO:Suspension:{roundId}:{direction}`
- 返回值：熔断结束时间（ISO 8601格式字符串）或 null

**Step 3: 熔断判断**
- 若Key不存在（null）→ 未熔断，继续Step 4
- 若Key存在 → 解析时间戳，判断是否已到期
  - 未到期：返回拒绝结果，告知剩余时间
  - 已到期：继续Step 4（定时任务会清理过期Key）

**Step 4: 读取当前累计敞口** ⭐
- Redis Key：`BO:Exposure:{roundId}:{direction}`
- 返回值：当前累计金额（String转BigDecimal）
- 若Key不存在，说明是该轮次该方向的首笔订单，累计金额为0

**Step 5: 计算加入本次订单后的总敞口** ⭐
- 计算公式：`newTotal = currentAmount + orderAmount`
- 从配置读取阈值：`threshold = AGGREGATE_EXPOSURE_THRESHOLD`（默认50000）

**Step 6: 判断是否超限** ⭐
- 若 `newTotal > threshold`：
  - 触发熔断：设置Redis熔断标志，TTL = 15分钟 + 30分钟缓冲
  - 记录风控日志
  - 发送P0告警
  - **拒绝本次下单**
- 若 `newTotal <= threshold`：
  - 继续Step 7

**Step 7: 原子更新累计敞口** ⭐
- 使用Redis INCRBYFLOAT命令：`INCRBYFLOAT BO:Exposure:{roundId}:{direction} {orderAmount}`
- 原子操作保证并发安全
- 设置TTL：轮次结束后30分钟

**Step 8: 异步更新数据库（可选）**
- 继续后续下单流程
- 在下单成功后更新`bo_trading_round.total_*_amount`字段
- 数据库字段仅用于数据备份和对账，不参与风控判断

---

#### 4.1.2 性能分析

| 操作 | 耗时 | 说明 |
|------|------|------|
| Redis GET (熔断状态) | < 0.3ms | 检查是否已熔断 |
| Redis GET (累计金额) | < 0.3ms | 获取当前敞口 |
| 本地计算 | < 0.1ms | 累计 + 本次金额，判断超限 |
| Redis INCRBYFLOAT | < 0.3ms | 原子累加（仅未超限时） |
| Redis SETEX (熔断标志) | < 0.3ms | 设置熔断（仅超限时） |
| **正常流程总耗时** | **< 1ms** | GET熔断 + GET累计 + INCRBYFLOAT |
| **触发熔断总耗时** | **< 1ms** | GET熔断 + GET累计 + SETEX |

**对比传统方案**：
- ❌ v2.0方案（数据库）：查询数据库（5-10ms）
- ❌ v1.1原方案（定时任务）：最多30秒延迟
- ✅ v1.1优化方案（下单实时判断）：< 1ms，实时触发

---

#### 4.1.3 实现要点

**核心逻辑伪代码**：
```
function checkAggregateExposure(roundId, direction, orderAmount):
    // Step 1: 检查功能开关
    if not ENABLED:
        return PASS

    // Step 2: 检查熔断状态
    suspensionKey = "BO:Suspension:{roundId}:{direction}"
    endTimeStr = redis.GET(suspensionKey)

    if endTimeStr is not null:
        endTime = parseDateTime(endTimeStr)
        if now() < endTime:
            return REJECT("熔断中，剩余 X 分钟")

    // Step 3: 读取当前累计金额
    exposureKey = "BO:Exposure:{roundId}:{direction}"
    currentAmountStr = redis.GET(exposureKey)
    currentAmount = parseDecimal(currentAmountStr) or 0

    // Step 4: 计算新总额
    newTotal = currentAmount + orderAmount
    threshold = getConfig("AGGREGATE_EXPOSURE_THRESHOLD")

    // Step 5: 判断是否超限
    if newTotal > threshold:
        // 触发熔断
        suspendMinutes = getConfig("AGGREGATE_EXPOSURE_SUSPEND_MINUTES")
        endTime = now() + suspendMinutes
        redis.SETEX(suspensionKey, (suspendMinutes * 60 + 1800), endTime)

        // 记录日志和告警
        logRiskEvent("AGGREGATE_EXPOSURE_LIMIT", ...)
        sendAlert(roundId, direction, newTotal)

        return REJECT("敞口超限，触发熔断")

    // Step 6: 原子累加
    redis.INCRBYFLOAT(exposureKey, orderAmount)
    redis.EXPIRE(exposureKey, roundTTL)

    return PASS
```

**并发安全保证**：
- **使用INCRBYFLOAT原子操作**：多个并发下单同时累加，Redis保证原子性
- **判断时机优化**：在INCRBYFLOAT之前判断，避免先累加再判断导致的超限
- **容错机制**：即使判断时刻未超限，但并发累加后超限，下一笔订单会被拒绝

**集成位置**：
- 在 `RiskControlService.checkOrderRisk()` 方法中
- 作为第12项风控检查（在IP设备检查之后）
- 返回 `RiskCheckResult` 对象

---

### 4.2 定时任务：自动恢复过期熔断

**任务名称**：`ExpiredSuspensionRecoveryTask`
**执行频率**：每分钟
**分布式锁**：`bo:schedule:suspension:recovery`

---

#### 4.2.1 任务执行流程

**Step 1: 扫描所有熔断Key**
- 使用Redis SCAN命令扫描所有`BO:Suspension:*`模式的Key
- 避免使用KEYS命令，防止阻塞Redis主线程

**Step 2: 检查每个熔断标志**
- 读取熔断结束时间（ISO 8601格式时间戳）
- 解析时间戳并与当前时间比较

**Step 3: 删除过期熔断**
- 若熔断结束时间已过当前时间，则删除该Key
- 记录恢复日志

**Step 4: 统计和日志**
- 记录本次恢复的熔断数量
- 记录任务执行状态

---

#### 4.2.2 性能优化

**使用SCAN命令**：
- 渐进式遍历，不阻塞Redis
- 适合大量Key的场景

**批量删除**：
- 使用Redis Pipeline批量删除多个过期Key
- 减少网络往返次数

**异常容错**：
- 时间戳解析失败时跳过该Key，继续处理其他Key
- 不因单个Key的问题影响整体任务

---

## 5. 定时任务设计

### 5.1 任务清单

| 任务名称 | 执行频率 | 分布式锁 | 职责 | 执行时间 |
|---------|---------|---------|------|---------|
| ExpiredSuspensionRecoveryTask | 1分钟 | bo:schedule:suspension:recovery | 清理过期熔断Key | < 0.5秒 |

**说明**：
- ✅ **无需敞口统计任务**：敞口累计和熔断判断在下单时实时完成
- ✅ **仅需恢复任务**：定时清理已过期的熔断标志，保持Redis整洁

---

### 5.2 任务执行策略

#### 5.2.1 ExpiredSuspensionRecoveryTask

**执行逻辑**：
```
每1分钟执行一次
  ↓
1. SCAN Redis熔断Key（BO:Suspension:*）
  ↓
2. 遍历每个Key
  ↓
3. 检查到期时间是否已过
  ↓
4. 删除过期Key
```

**性能优化**：
- ✅ 使用SCAN命令：避免KEYS *阻塞Redis
- ✅ 批量删除：Pipeline批量DELETE

---

## 6. API接口设计

### 6.1 查询敞口状态API

**接口路径**：`GET /api/borc/admin/exposure/stats`

**请求参数**：
- `roundId`（必填）：轮次ID
- `direction`（可选）：方向（UP/DOWN），不传则返回两个方向

**实现逻辑**：
1. 从Redis读取敞口累计：`BO:Exposure:{roundId}:{direction}`（简单数值）
2. 从Redis读取熔断状态：`BO:Suspension:{roundId}:{direction}`（时间戳）
3. 从配置表读取阈值：`AGGREGATE_EXPOSURE_THRESHOLD`
4. 计算利用率：`utilizationRate = totalAmount / threshold * 100`
5. 构建响应DTO返回

**响应示例**：
```json
{
  "success": true,
  "data": [{
    "roundId": 12345,
    "direction": "UP",
    "totalAmount": 52000.50,
    "threshold": 50000.00,
    "isSuspended": true,
    "suspendEndTime": "2026-01-12T10:45:00",
    "utilizationRate": 104.0,
    "lastUpdate": "2026-01-12T10:30:15"
  }]
}
```

---

### 6.2 手动触发熔断API

**接口路径**：`POST /api/borc/admin/exposure/suspend`

**请求参数**：
```json
{
  "roundId": 12345,
  "direction": "UP",
  "durationMinutes": 30,
  "reason": "Manual suspension"
}
```

**实现逻辑**：
1. 计算熔断结束时间：`endTime = now + durationMinutes`
2. 设置Redis熔断标志：`BO:Suspension:{roundId}:{direction} = endTime`
3. 设置TTL：`durationMinutes * 60 + 1800秒（30分钟缓冲）`
4. 记录操作日志

---

### 6.3 手动解除熔断API

**接口路径**：`POST /api/borc/admin/exposure/unsuspend`

**请求参数**：
```json
{
  "roundId": 12345,
  "direction": "UP",
  "reason": "Risk resolved"
}
```

**实现逻辑**：
1. 删除Redis熔断标志：`BO:Suspension:{roundId}:{direction}`
2. 记录操作日志

---

## 7. 性能优化方案

### 7.1 Redis性能优化

#### 7.1.1 连接池配置

**关键配置**：
- `max-active: 20`：最大连接数，支持高并发访问
- `max-idle: 10`：保持10个空闲连接，快速响应突发请求
- `min-idle: 5`：最小空闲连接，避免频繁创建销毁
- `max-wait: 2000ms`：获取连接最大等待时间

#### 7.1.2 原子操作优化

**优化策略**：
- 使用Redis INCRBYFLOAT原子累加，避免读取-计算-写入三步操作
- 单次原子操作完成累加，性能<0.3ms
- 天然支持高并发，无需额外锁机制

---

### 7.2 定时任务性能优化

#### 7.2.1 渐进式扫描

**优化策略**：
- 使用Redis SCAN命令扫描熔断Key，避免KEYS *阻塞
- 批量Pipeline删除过期Key，减少网络往返
- 任务执行时间<0.5秒，不影响Redis性能

#### 7.2.2 异步通知

**优化策略**：
- 告警通知异步发送，不阻塞下单流程
- 使用独立的线程池`exposureAlertExecutor`
- 确保下单流程在1ms内完成风控检查

---

### 7.3 性能指标

| 指标 | 目标值 | 实际值（预估） | 优化手段 |
|------|--------|---------------|---------|
| 下单前检查耗时 | < 2ms | < 1ms | 2-3次Redis操作（GET+INCRBYFLOAT） |
| 熔断触发延迟 | 实时 | 0ms | 下单时实时计算和判断 |
| 定时任务执行时间 | < 1秒 | < 0.5秒 | SCAN渐进扫描 + Pipeline批量删除 |
| 系统QPS影响 | < 1% | < 0.5% | 轻量级Redis操作 |
| 并发安全性 | 100% | 100% | Redis原子操作保证 |

---



**文档版本**：v1.1（实时计算方案）
**创建日期**：2026-01-09
**修订日期**：2026-01-13
**作者**：开发团队
**核心变更**：
- 采用 Redis + 实时计算方案，零数据库变更，最小化下单流程入侵
- 敞口累计和熔断判断在下单时实时完成，无延迟
- 使用Redis INCRBYFLOAT原子操作，保证并发安全
- 移除敞口统计定时任务，仅保留过期熔断清理任务
- 优化文档结构，文字描述为主，代码示例为辅
