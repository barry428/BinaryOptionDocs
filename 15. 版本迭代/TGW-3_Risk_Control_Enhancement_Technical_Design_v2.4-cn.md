# TGW-3：二元期权风险控制增强 - 技术设计 v2.4

**项目**：二元期权第一阶段增强
**要求 ID**：TGW-3
**文档版本**：v2.3（黑名单枚举增强版）
**创建日期**：2025-12-26
**基于版本**：v2.2
**所有者**：开发团队

---



## 目录

- [1. 架构设计](#1-架构设计)
- [2. 黑名单枚举设计](#2-黑名单枚举设计) 
- [3. 每日损益优化方案](#3-每日损益优化方案)
- [4. 连胜周期设计方案](#4-连胜周期设计方案)
- [5. 统一风控统计表设计](#5-统一风控统计表设计)
- [6. 定时任务设计](#6-定时任务设计)

---

## 1. 架构设计

### 1.1 整体架构

**数据分层策略**：
```
Layer 1: 基础数据层
├─ bo_user_round：轮次聚合数据（已有）
└─ bo_option_order：订单明细数据（已有）

Layer 2: 统计数据层
└─ bo_user_risk_comprehensive_stats：风控统计表（新建）
    ├─ 每日损益：从 Layer 1 的 bo_user_round 查询
    ├─ 胜率统计：从 Layer 1 的 bo_option_order 查询
    └─ 连胜统计：从 Layer 1 的 bo_option_order 查询

Layer 3: 风控执行层
└─ bo_blacklist：黑名单表（增强）
    ├─ 记录触发的具体风控规则
    ├─ 记录触发时的阈值配置
    └─ 支持审计和规则分析
```

**计算流程**：
```
统一风控计算任务（每5分钟）
├─ Step 1: 查询 bo_user_round → 计算每日损益
├─ Step 2: 查询 bo_option_order → 同时计算胜率和连胜
├─ Step 3: 合并结果写入统计表
└─ Step 4: 检查是否触发风控规则 → 插入黑名单（携带规则枚举）
```

---

## 2. 黑名单枚举设计

### 2.1 设计目标

**核心需求**：
- 精确标记触发了哪条风控规则
- 区分自动风控和人工添加
- 支持同一用户多次触发不同规则
- 便于审计、统计和规则优化

**设计原则**：
- 枚举值语义清晰，易于理解
- 支持扩展新的风控规则
- 向后兼容现有黑名单数据

---

### 2.2 风控规则类型枚举

#### 2.2.1 枚举定义

**枚举类**：`RiskRuleType`

```java
    DAILY_PROFIT_LIMIT("daily_profit_limit", "每日利润超限", "24小时内净利润超过配置阈值"),
    CONSECUTIVE_WIN_LIMIT("consecutive_win_limit", "连胜次数超限", "在统计周期内连续盈利次数超过阈值"),
    HIGH_WINRATE_LIMIT("high_winrate_limit", "胜率超限", "在样本范围内胜率超过配置阈值"),

```



---

### 2.3 黑名单表结构增强

#### 2.3.1 新增字段

**表名**：`bo_blacklist`

**新增字段**：

| 字段名 | 类型 | 必填 | 说明 | 索引 |
|--------|------|------|------|------|
| `source_type` | VARCHAR(32) | 是 | 黑名单来源类型：`auto`/`manual` | 组合索引 |
| `risk_rule_type` | VARCHAR(64) | 否 | 触发的风控规则类型（枚举code） | 组合索引 |
| `rule_config_snapshot` | TEXT | 否 | 触发时的规则配置快照（JSON） | - |

**字段说明**：

1. **source_type**：
   - 标记黑名单是自动触发还是人工添加
   - 取值：`auto`（自动风控）或 `manual`（人工添加）
   - 必填字段

2. **risk_rule_type**：
   - 标记具体触发的风控规则
   - 取值：RiskRuleType枚举的code值
   - 自动风控时必填，人工添加时可选
   - 示例：`daily_profit_limit`、`consecutive_win_limit`、`high_winrate_limit`

3. **rule_config_snapshot**：
   - JSON格式存储触发时的规则配置
   - 用于审计和事后分析
   - 可选字段
   - 示例：
     ```json
     {
       "ruleType": "daily_profit_limit",
       "threshold": 10000.0,
       "actualValue": 15230.5,
       "period": "24h",
       "triggeredAt": "2025-12-26T10:30:00Z"
     }
     ```

#### 2.3.2 现有字段调整

**字段**：`type`（现有字段）

**调整方案**：
- **保留用途**：向后兼容，继续使用
- **建议值**：与 `source_type` 保持同步（`auto`/`admin`）
- **迁移策略**：逐步迁移到 `source_type` + `risk_rule_type` 组合


---

## 3. 每日损益优化方案

### 3.1 方案细节

#### 基于 bo_user_round 聚合（推荐）⭐

**核心思路**：
- 利用已有的轮次聚合数据（bo_user_round 表）
- 该表已包含每个轮次的 net_profit、total_orders 等字段
- 只需按用户聚合最近24小时的轮次数据即可

**查询逻辑**：
1. 筛选条件：`last_settle_time >= NOW() - 24小时`
2. 按用户、账户类型分组
3. 聚合 net_profit（净损益）、total_orders（订单数）等字段

**优点**：
- ✅ 数据量小：轮次表远小于订单表（1000行 vs 10万行）
- ✅ 查询速度快：索引友好，响应时间 < 50ms
- ✅ 数据准确：直接使用结算后的聚合数据
- ✅ 符合业务逻辑：按轮次结算是业务标准流程

**缺点**：
- ⚠️ 依赖轮次表数据完整性（需确保轮次结算逻辑正确）


---

## 4. 连胜周期设计方案

### 4.1 需求分析

**核心问题**：如何定义"一个月连胜纪录"？

**选项1**：自然月（如 2025-12-01 至 2025-12-31）
**选项2**：滑动30天（如 2025-11-25 至 2025-12-25）

**关键差异**：
- 自然月：有固定起止时间，每月1号重置
- 滑动30天：窗口持续滚动，无固定重置时间

---

### 4.2 方案A：滑动30天连胜统计

**设计思路**：
- 以当前时间为基准，统计最近30天连胜
- 窗口持续滚动，不受月份限制
- 连胜不会因月份切换而中断

**实现要点**：
1. 查询最近30天的订单（`settle_time >= NOW() - 30天`）
2. 按时间排序，使用窗口函数标记连胜分组
3. 每次非WIN订单作为分组标记，重新计数
4. 计算当前连胜和最大连胜

**适用场景**：
- ✅ 实时风控监控
- ✅ 需要持续跟踪用户状态
- ✅ 与24小时损益滚动窗口逻辑一致
- ✅ 适合大多数风控场景（**推荐**）

**优缺点**：

| 优点 | 缺点 |
|------|------|
| 实时性强，随时触发 | 查询范围动态变化 |
| 连续性好，无断点 | 缓存策略稍复杂 |
| 符合风控本质 | 需定期清理历史数据 |

---

### 4.4 方案B：短路查询（7+30天）

**设计思路**：
- 先查最近7天：大多数连胜发生在近期
- 短路判断：如果7天内连胜达标，直接触发，无需查30天
- 按需扩展：只有必要时才查询更早的数据


**优缺点**：

| 优点 | 缺点 |
|------|------|
| 减少50%查询（短路优化） | 7天内未命中需要二次查询订单表 |

---



## 5. 统一风控统计表设计

### 5.1 表结构设计

**表名**：`bo_user_risk_comprehensive_stats`

**设计原则**：
- 单表存储所有风控统计数据
- 按用户、账户类型、日期唯一
- 支持历史数据查询（按月分区）

**核心字段分组**：

#### 5.1.1 每日损益字段（来源：bo_user_round）
- `daily_net_profit`：24小时净损益
- `daily_profit_threshold`：每日损益阈值（配置）

#### 5.1.2 连胜统计字段（来源：bo_option_order）
- `current_streak`：当前连胜次数
- `streak_start_time`：当前连胜起始时间
- `streak_period_days`：连胜周期（默认30天）
- `streak_threshold`：连胜阈值（默认8次）

#### 5.1.3 胜率统计字段（来源：bo_option_order）
- `winrate_win_count`：盈利订单数
- `winrate_lose_count`：亏损订单数
- `winrate_draw_count`：平局订单数
- `winrate_percentage`：当前胜率（%）
- `winrate_threshold`：胜率阈值（默认70%）
- `winrate_sample_min/max`：样本量范围（10-100）
- `winrate_min_amount`：最低金额过滤（10 USDT）

#### 5.1.4 辅助字段
- `last_processed_order_id`：最后处理的订单ID（增量扫描标记）
- `last_scan_time`：最后扫描时间
- `last_calculate_time`：最后计算时间

### 5.2 索引设计

**主键和唯一约束**：
- 主键：`id`
- 唯一键：`(user_id, account_type, stat_date)`

**业务查询索引**：
1. `idx_daily_profit`：查询高盈利用户
   - 字段：`(user_id, account_type, daily_net_profit DESC, stat_date DESC)`

2. `idx_streak`：查询高连胜用户
   - 字段：`(user_id, account_type, current_streak DESC, stat_date DESC)`

3. `idx_winrate`：查询高胜率用户
   - 字段：`(user_id, account_type, winrate_percentage DESC, stat_date DESC)`

4. `idx_scan`：支持增量扫描
   - 字段：`(last_scan_time, last_processed_order_id)`

### 5.3 分区策略（可选）

**按月分区**：
- 保留最近12个月数据
- 自动清理历史分区
- 提升查询和维护性能

---

## 6. 定时任务设计

### 6.1 统一风控计算任务

**任务名称**：`UnifiedRiskCalculationTask`
**执行频率**：每5分钟
**分布式锁**：`bo:schedule:risk:unified-calculation`

**执行流程**：

```
Step 1: 获取活跃用户列表
├─ 查询最近24小时有新订单的用户
└─ 批量处理（每批1000用户）

Step 2: 批量计算风控统计
├─ 2.1 查询 bo_user_round → 计算每日损益
│   └─ 筛选最近24小时已结算的轮次
├─ 2.2 查询 bo_option_order → 计算胜率和连胜
│   ├─ 筛选最近30天订单（限制100单/用户）
│   ├─ 单次遍历：同时统计胜率和连胜
│   └─ 记录最后处理的订单ID
└─ 2.3 合并结果

Step 3: 保存统计数据
├─ INSERT ON DUPLICATE KEY UPDATE（MySQL）
└─ INSERT ON CONFLICT DO UPDATE（PostgreSQL）

Step 4: 检查风控规则并插入黑名单 ⭐ 增强
├─ 4.1 每日利润限额检查
│   ├─ 判断：daily_net_profit > daily_profit_threshold
│   ├─ 触发：调用 insertAutoRiskBlacklist()
│   ├─ 规则类型：RiskRuleType.DAILY_PROFIT_LIMIT
│   └─ 记录快照：threshold、actualValue、period="24h"
│
├─ 4.2 连胜限制检查
│   ├─ 判断：current_streak > streak_threshold
│   ├─ 触发：调用 insertAutoRiskBlacklist()
│   ├─ 规则类型：RiskRuleType.CONSECUTIVE_WIN_LIMIT
│   └─ 记录快照：threshold、actualValue、period="30d"
│
└─ 4.3 高胜率检查
    ├─ 判断：winrate_percentage > winrate_threshold
    ├─ 触发：调用 insertAutoRiskBlacklist()
    ├─ 规则类型：RiskRuleType.HIGH_WINRATE_LIMIT
    └─ 记录快照：threshold、actualValue、sampleSize、period="30d"
```

**性能优化要点**：
1. 限制查询范围：最多100单/用户
2. 使用批处理：每批1000用户
3. 增量处理：记录 `last_processed_order_id`
4. 索引优化：覆盖索引，避免回表


---
