# Binary Option 前端 API 对接方案

> 版本: 1.3.0
> 更新日期: 2025-12-15
> 状态: WebSocket全局初始化完成

---

## 一、项目概述

### 1.1 目标

将 `binary-option-fe` 前端项目对接到新的后端 API 系统，关闭现有 Mock 数据模式，实现真实数据交互。

### 1.2 当前状态

| 项目 | 状态 |
|------|------|
| 前端项目 | `binary-option-fe` (Vue 3 + TypeScript + Pinia) |
| Mock 模式 | ✅ 已关闭 (`USE_MOCK = false`) |
| API 前缀 | `/api/borc` |
| 后端 Gateway | `http://gateway-host:8080` |

### 1.3 主要变更点

1. **关闭 Mock 模式** - 修改 `USE_MOCK = false`
2. **更新类型定义** - 对齐后端 API 响应格式
3. **更新 WebSocket** - 对接真实行情推送
4. **调整业务逻辑** - 处理新的认证流程

---

## 二、API 对接清单

### 2.1 公开接口 (无需认证) - ✅ 已完成

| 后端 API | 前端方法 | 状态 | 说明 |
|----------|----------|------|------|
| `GET /api/borc/public/order/symbols` | `api.market.getSymbols()` | ✅ 完成 | 字段类型已对齐 |
| `GET /api/borc/public/order/symbols/hot` | `api.market.getHotSymbols()` | ✅ 完成 | 新增方法 |
| `GET /api/borc/public/order/durations` | `api.market.getDurations()` | ✅ 完成 | 新增方法，全局配置 |
| `GET /api/borc/public/order/round/current/{symbolId}` | `api.market.getCurrentRounds()` | ✅ 完成 | **仅在用户选择交易对时请求** |
| `POST /api/borc/public/order/market/history` | `api.market.getHistoryData()` | ✅ 完成 | 响应格式已简化 |

> **重要架构说明**：
> - `/public/order/durations` 返回全局周期配置，对所有交易对通用，应用初始化时请求一次
> - `/public/order/round/current/{symbolId}` **只在用户点击具体交易对时才请求**，用于获取下单所需的 roundId
> - 市场卡片列表页**不需要为每个 symbol 请求 round 信息**，赔率数据通过 WebSocket tick 推送

### 2.2 用户接口 (需要认证)

| 后端 API | 前端方法 | 当前状态 | 修改项 |
|----------|----------|----------|--------|
| `GET /api/borc/user/profile` | `api.user.getProfile()` | ✅ 已实现 | 字段对齐 |
| `PUT /api/borc/user/agreements` | `api.user.updateAgreements()` | ✅ 已实现 | 无变化 |

### 2.3 账户接口 (需要认证)

| 后端 API | 前端方法 | 当前状态 | 修改项 |
|----------|----------|----------|--------|
| `GET /api/borc/account/list` | 未实现 | ❌ 缺失 | 新增方法 |
| `GET /api/borc/account/balance/{accountType}` | `api.account.getBalance()` | ✅ 已实现 | 字段对齐 |
| `POST /api/borc/account/demo/claim-bonus` | `api.account.claimDemoBonus()` | ✅ 已实现 | 无变化 |

### 2.4 订单接口 (需要认证)

| 后端 API | 前端方法 | 当前状态 | 修改项 |
|----------|----------|----------|--------|
| `POST /api/borc/order` | `api.order.createOrder()` | ✅ 已实现 | 字段对齐 |
| `GET /api/borc/order/{orderId}` | `api.order.getOrderById()` | ✅ 已实现 | 字段对齐 |
| `GET /api/borc/order/list/active` | `api.order.getActiveOrders()` | ✅ 已实现 | 响应结构调整，自动刷新 |
| `GET /api/borc/order/list/history` | `api.order.getHistoryOrders()` | ✅ 已实现 | 时间参数改为毫秒时间戳 |

#### 历史订单时间参数

历史订单查询支持时间范围筛选，使用 **Unix 毫秒时间戳**：

```typescript
// 前端调用示例
await orderStore.loadHistoryOrders('DEMO', {
  page: 1,
  pageSize: 10,
  startTime: 1734192000000,  // 2025-12-15 00:00:00
  endTime: 1734278399999,    // 2025-12-15 23:59:59.999
})
```

| 参数 | 类型 | 说明 |
|------|------|------|
| startTime | number | 开始时间，Unix 毫秒时间戳 |
| endTime | number | 结束时间，Unix 毫秒时间戳 |

> **注意**: 前端默认选中当天日期，页面加载时会自动传递当天的时间范围给 API。

### 2.5 WebSocket 接口 - ✅ 已完成

| 功能 | 状态 | 说明 |
|------|------|------|
| 连接地址 | ✅ 完成 | `ws://gateway-host:8080/ws/borc` |
| 订阅格式 | ✅ 完成 | 数组格式 `{ subscribe: ["BTC-USDT"] }` |
| 批量订阅 | ✅ 完成 | `subscribe(string[])` 和 `subscribeAll()` |
| 全局初始化 | ✅ 完成 | App.vue 中自动连接并订阅所有交易对 |
| Tick 数据结构 | ✅ 完成 | 使用 `odds` 数组替代 `fixtures` |
| Mock 数据 | ✅ 完成 | Mock 模式已适配新格式 |

#### WebSocket 全局初始化

WebSocket 连接在应用启动时自动建立，并默认订阅所有交易对：

**App.vue 初始化代码**:
```typescript
import { useWebSocketStore } from '@/store'

const websocketStore = useWebSocketStore()

async function initWebSocket() {
  const wsUrl = import.meta.env.VITE_WS_BASE_URL
  const useMock = import.meta.env.VITE_USE_MOCK === 'true'

  if (!wsUrl) {
    console.warn('WebSocket URL not configured')
    return
  }

  await websocketStore.connect(wsUrl, useMock)
}

onMounted(() => {
  initWebSocket()
})

onUnmounted(() => {
  websocketStore.disconnect()
})
```

**连接流程**:
1. 应用启动时在 `App.vue` 的 `onMounted` 中调用 `initWebSocket()`
2. WebSocket 连接成功后自动调用 `subscribeAll()` 订阅所有交易对
3. 应用卸载时在 `onUnmounted` 中断开连接

**环境变量配置**:
```bash
# .env.development
VITE_WS_BASE_URL=ws://localhost:8083/ws/borc
VITE_USE_MOCK=false

# .env.production
VITE_WS_BASE_URL=wss://api.example.com/ws/borc
VITE_USE_MOCK=false
```

---

## 三、类型定义变更

### 3.1 交易对类型 (Symbol)

**当前前端定义** (`src/api/types.ts`):
```typescript
interface Symbol {
  symbolId: string
  symbol: string
  baseCurrency: string
  quoteCurrency: string
  enabled: boolean
  minOrderAmount: number
  maxOrderAmount: number
  sortOrder: number
  createTime: number
  updateTime: number
}
```

**后端 API 返回格式** (根据 API 文档):
```typescript
interface Symbol {
  symbolId: number           // 数字类型
  symbol: string             // 如 "BTC-USDT"
  baseCurrency: string
  quoteCurrency: string
  enabled: boolean
  minOrderAmount: number
  maxOrderAmount: number
  baseOdds: number           // 新增: 基础赔率
  feeRate: number            // 新增: 手续费率
  sortOrder: number
  // 无 createTime/updateTime
}
```

**变更说明**:
- `symbolId`: string → number
- 新增 `baseOdds`, `feeRate` 字段
- 移除 `createTime`, `updateTime`

---

### 3.2 交易周期配置 (Duration) - 新增

**后端 API 返回格式**:
```typescript
interface DurationConfig {
  id: string                 // 周期配置ID (字符串)
  durationMinutes: number    // 周期时长（分钟）
  durationName: string       // 显示名称 (如 "1分钟")
  lockSeconds: number        // 锁单时间（秒）
  baseOdds: number           // 基础赔率
  feeRate: number            // 手续费率
  sortOrder: number          // 排序
}
```

---

### 3.3 交易轮次类型 (TradingRound)

**当前前端定义**:
```typescript
interface TradingRound {
  symbolId: string
  durationMinutes: number
  roundNo: string
  openTime: number         // 时间戳
  closeTime: number
  lockTime: number
  status: 'OPEN' | 'LOCKED' | 'SETTLED'
  upAmount: number
  downAmount: number
  createTime: number
  updateTime: number
  roundId: string
}
```

**后端 API 返回格式** (根据 API 文档):
```typescript
interface TradingRound {
  roundId: number            // 数字类型
  durationMinutes: number
  roundNo: string
  startPrice: number         // 开盘价
  openTime: string           // ISO 日期时间字符串
  closeTime: string
  lockTime: string
  status: 'OPEN' | 'LOCKED' | 'SETTLED'
  // 无 symbolId, upAmount, downAmount, createTime, updateTime
}
```

**外层响应结构**:
```typescript
interface RoundResponse {
  symbolId: number
  symbol: string
  rounds: TradingRound[]
}
```

**变更说明**:
- `roundId`: string → number
- `openTime/closeTime/lockTime`: 时间戳 → ISO 日期字符串
- 新增 `startPrice`
- `symbolId` 移到外层
- 移除 `upAmount`, `downAmount`, `createTime`, `updateTime`

---

### 3.4 WebSocket Tick 数据类型

**当前前端定义** (`src/types/websocket.ts`):
```typescript
interface TickData {
  type: 'tick'
  symbol: string
  price: number
  price24hMin: number
  price24hMax: number
  price24hChange: number
  fixtures: Fixture[]      // 期权合约数组
}

interface Fixture {
  expiration: string
  strike: number
  side: 'call' | 'put'
  itm: boolean
  price: number
}
```

**后端 API 推送格式** (根据 API 文档):
```typescript
interface TickData {
  type: 'tick'
  symbol: string
  price: number
  price24hMin: number
  price24hMax: number
  price24hChange: number   // 24小时价格变化百分比
  odds: OddsData[]         // 赔率数组
  timestamp: number        // 时间戳（毫秒）
}

interface OddsData {
  duration: number         // 时间区间（分钟）: 1, 3, 5, 15
  upOdds: number          // 看涨赔率
  downOdds: number        // 看跌赔率
}
```

**变更说明**:
- `fixtures` → `odds` (业务模型变化)
- 新增 `timestamp` 字段
- 去除期权相关字段 (`strike`, `expiration`, `itm`, `side`)
- `OddsData` 结构完全不同于 `Fixture`

---

### 3.5 订阅消息格式

**当前前端格式**:
```typescript
interface SubscribeMessage {
  subscribe: string        // 单个交易对
}
```

**后端要求格式** (根据 API 文档):
```typescript
interface SubscribeMessage {
  subscribe: string[]      // 数组格式
}

interface UnsubscribeMessage {
  unsubscribe: string[]    // 数组格式
}

// 示例
{ "subscribe": ["BTC-USDT", "ETH-USDT"] }
{ "subscribe": ["*"] }  // 订阅所有
{ "unsubscribe": ["BTC-USDT"] }
{ "unsubscribe": ["*"] }  // 取消所有
```

---

### 3.6 历史行情响应格式

**当前前端期望**:
```typescript
interface HistoryResponse {
  symbol: string
  expiration: string
  strike: number
  side: 'call' | 'put'
  history: any[]
}
```

**后端 API 返回格式** (根据 API 文档):
```typescript
interface HistoryResponse {
  symbol: string
  history: [number, number][]  // [时间戳(毫秒), 价格]
}
```

**变更说明**:
- 去除期权相关字段 (`expiration`, `strike`, `side`)
- `history` 简化为 `[timestamp, price]` 二元数组

---

### 3.7 用户信息类型

**当前前端定义** (`src/types/user.ts`):
```typescript
interface User {
  id: string
  username: string
  email: string
  firstName?: string
  lastName?: string
  avatar?: string
  role: 'admin' | 'user' | 'guest'
  status: 'ACTIVE' | 'INACTIVE' | 'SUSPENDED'
  createdAt: string
  updatedAt: string
  lastLoginAt?: string
  preferences?: UserPreferences
}
```

**后端 API 返回格式** (根据 API 文档):
```typescript
interface User {
  userId: number
  nickname: string
  status: number           // 1=正常
  isDemo: boolean
  riskAgreement: number    // 0=未同意, 1=已同意
  amlAgreement: number
  createTime: string       // ISO 日期时间
}
```

**变更说明**:
- 字段大幅简化
- `id` → `userId` (string → number)
- `username` → `nickname`
- 移除 `email`, `role`, `preferences` 等字段
- 新增 `isDemo`, `riskAgreement`, `amlAgreement`

---

### 3.8 账户信息类型

**后端 API 返回格式** (根据 API 文档):
```typescript
interface Account {
  accountId: number
  accountType: 'DEMO' | 'REAL'
  currency: string
  balance: number
  frozenBalance: number
  availableAmount: number
  totalProfit: number
  totalLoss: number
  winRate: number
  status: number
}
```

---

### 3.9 订单类型

**后端 API 创建订单响应** (根据 API 文档):
```typescript
interface OrderCreateResponse {
  orderId: number
  accountType: 'DEMO' | 'REAL'
  symbolName: string
  roundNo: string
  direction: 'UP' | 'DOWN'
  amount: number
  odds: number
  expectedProfit: number
  orderPrice: number
  status: 'ACTIVE'
  createTime: string
}
```

**订单详情响应**:
```typescript
interface OrderDetail {
  orderId: number
  accountType: 'DEMO' | 'REAL'
  symbolName: string
  direction: 'UP' | 'DOWN'
  amount: number
  odds: number
  orderPrice: number
  settlePrice: number | null
  status: 'PENDING' | 'ACTIVE' | 'WIN' | 'LOSE' | 'DRAW' | 'CANCELLED'
  profit: number | null
  fee: number | null
  settleTime: string | null
}
```

---

### 3.10 活跃订单/历史订单响应结构

**后端 API 返回格式** (根据 API 文档):
```typescript
interface ActiveOrdersResponse {
  rounds: RoundWithOrders[]
  totalRounds: number
  totalOrders: number
}

interface HistoryOrdersResponse {
  rounds: RoundWithOrders[]
  total: number
  page: number
  pageSize: number
  totalPages: number
  hasNext: boolean
  hasPrevious: boolean
}

interface RoundWithOrders {
  roundId: number
  roundNo: string
  symbol: string
  durationMinutes: number
  startTime: string
  endTime: string
  startPrice: number
  endPrice: number | null
  status: string
  settleTime: string | null
  orders: OrderInRound[]
  userStats: UserStats
}

interface OrderInRound {
  orderId: number
  direction: 'UP' | 'DOWN'
  amount: number
  odds: number
  expectedProfit: number
  status: string
  profit?: number
  fee?: number
}

interface UserStats {
  totalOrders: number
  totalAmount: number
  totalProfit: number
  totalLoss: number
  netProfit: number
  winCount?: number
  loseCount?: number
  winRate?: number
}
```

---

## 四、具体修改方案

### 4.1 第一阶段: 基础配置

#### 4.1.1 关闭 Mock 模式

**文件**: `src/api/http.ts`

```typescript
// 修改前
const USE_MOCK = true

// 修改后
const USE_MOCK = false
```

#### 4.1.2 环境变量配置

**文件**: `.env.development`
```
VITE_API_BASE_URL=http://localhost:8080
VITE_API_PREFIX=/api/borc
VITE_WS_BASE_URL=ws://localhost:8080/ws/borc
```

**文件**: `.env.production`
```
VITE_API_BASE_URL=https://api.example.com
VITE_API_PREFIX=/api/borc
VITE_WS_BASE_URL=wss://api.example.com/ws/borc
```

---

### 4.2 第二阶段: 类型定义更新

#### 4.2.1 更新 API 类型

**文件**: `src/api/types.ts`

```typescript
// 交易对类型
export interface Symbol {
  symbolId: number           // 改: string → number
  symbol: string
  baseCurrency: string
  quoteCurrency: string
  enabled: boolean
  minOrderAmount: number
  maxOrderAmount: number
  baseOdds: number           // 新增
  feeRate: number            // 新增
  sortOrder: number
}

// 交易周期配置 (新增)
export interface DurationConfig {
  id: string
  durationMinutes: number
  durationName: string
  lockSeconds: number
  baseOdds: number
  feeRate: number
  sortOrder: number
}

// 交易轮次类型
export interface TradingRound {
  roundId: number            // 改: string → number
  durationMinutes: number
  roundNo: string
  startPrice: number
  openTime: string           // 改: number → string (ISO)
  closeTime: string
  lockTime: string
  status: 'OPEN' | 'LOCKED' | 'SETTLED'
}

// 轮次响应包装
export interface RoundResponse {
  symbolId: number
  symbol: string
  rounds: TradingRound[]
}

// 历史行情响应
export interface HistoryResponse {
  symbol: string
  history: [number, number][]  // [timestamp, price]
}
```

#### 4.2.2 更新 WebSocket 类型

**文件**: `src/types/websocket.ts`

```typescript
// 订阅消息 (改为数组格式)
export interface SubscribeMessage {
  subscribe: string[]
}

export interface UnsubscribeMessage {
  unsubscribe: string[]
}

// 赔率数据 (新增，替代 Fixture)
export interface OddsData {
  duration: number         // 1, 3, 5, 15
  upOdds: number
  downOdds: number
}

// 行情数据 (修改)
export interface TickData {
  type: 'tick'
  symbol: string
  price: number
  price24hMin: number
  price24hMax: number
  price24hChange: number
  odds: OddsData[]           // 改: fixtures → odds
  timestamp: number          // 新增
}

// 删除 Fixture 接口
```

#### 4.2.3 更新用户类型

**文件**: `src/types/user.ts`

```typescript
export interface User {
  userId: number
  nickname: string
  status: number
  isDemo: boolean
  riskAgreement: number
  amlAgreement: number
  createTime: string
}

// 删除 LoginCredentials, RegisterData, AuthResponse 等不再需要的类型
```

---

### 4.3 第三阶段: API 方法更新

#### 4.3.1 新增 API 方法

**文件**: `src/api/http.ts`

```typescript
export const api = {
  market: {
    // ... 现有方法

    // 新增: 获取热门交易对
    async getHotSymbols(limit: number = 10) {
      return httpClient.get(`${API_PREFIX}/public/order/symbols/hot`, { limit })
    },

    // 新增: 获取交易周期配置
    async getDurations() {
      return httpClient.get(`${API_PREFIX}/public/order/durations`)
    },
  },

  account: {
    // ... 现有方法

    // 新增: 获取账户列表
    async getAccountList() {
      return httpClient.get(`${API_PREFIX}/account/list`, undefined, true)
    },
  },
}
```

#### 4.3.2 调整历史行情请求

```typescript
// 修改前
async getHistoryData(params: {
  symbol: string
  expiration: string
  strike: number
  side: 'call' | 'put'
  limitAfter: string
})

// 修改后
async getHistoryData(params: {
  symbol: string
  limitAfter?: string  // 可选，默认 300
})
```

---

### 4.4 第四阶段: WebSocket 更新

#### 4.4.1 更新订阅方法

**文件**: `src/websocket/MarketWebSocket.ts`

```typescript
// 订阅 (改为数组格式)
subscribe(symbols: string | string[], config?: Partial<SubscriptionConfig>): void {
  const symbolArray = Array.isArray(symbols) ? symbols : [symbols]

  symbolArray.forEach(symbol => {
    this.subscriptions.set(symbol, {
      symbol,
      debounceDelay: this.debounceDelay,
      ...config,
    })
  })

  if (!this.mockMode && this.ws?.readyState === WebSocket.OPEN) {
    const message: SubscribeMessage = { subscribe: symbolArray }
    this.send(message)
  }
}

// 订阅所有
subscribeAll(): void {
  this.subscriptions.set('*', { symbol: '*', debounceDelay: this.debounceDelay })
  if (!this.mockMode && this.ws?.readyState === WebSocket.OPEN) {
    this.send({ subscribe: ['*'] })
  }
}

// 取消订阅
unsubscribe(symbols: string | string[]): void {
  const symbolArray = Array.isArray(symbols) ? symbols : [symbols]
  symbolArray.forEach(s => this.subscriptions.delete(s))

  if (!this.mockMode && this.ws?.readyState === WebSocket.OPEN) {
    this.send({ unsubscribe: symbolArray })
  }
}

// 取消订阅所有
unsubscribeAll(): void {
  this.subscriptions.clear()
  if (!this.mockMode && this.ws?.readyState === WebSocket.OPEN) {
    this.send({ unsubscribe: ['*'] })
  }
}
```

#### 4.4.2 更新数据处理逻辑

**文件**: `src/composables/useTrading.ts`

```typescript
// 修改前: 使用 fixtures
const upMultiplier = computed(() => {
  const marketData = websocketStore.getMarketData(activeSymbol.value.symbol)
  if (!marketData?.fixtures) return 0
  const callFixture = marketData.fixtures.find((f) => f.side === 'call')
  if (callFixture?.price) {
    return parseFloat(FinancialMath.calculatePayout(callFixture.price, 2))
  }
  return 0
})

// 修改后: 使用 odds
const upMultiplier = computed(() => {
  const marketData = websocketStore.getMarketData(activeSymbol.value.symbol)
  if (!marketData?.odds) return 0

  // 根据当前选择的周期获取赔率
  const currentDuration = marketStore.selectedDuration || 1
  const oddsData = marketData.odds.find(o => o.duration === currentDuration)
  return oddsData?.upOdds || 0
})

const downMultiplier = computed(() => {
  const marketData = websocketStore.getMarketData(activeSymbol.value.symbol)
  if (!marketData?.odds) return 0

  const currentDuration = marketStore.selectedDuration || 1
  const oddsData = marketData.odds.find(o => o.duration === currentDuration)
  return oddsData?.downOdds || 0
})
```

---

### 4.5 第五阶段: Store 更新

#### 4.5.1 Market Store 调整

**文件**: `src/store/market.ts`

```typescript
// 类型调整: symbolId 为 number
const getSymbolById = (symbolId: number) =>
  symbolsAllList.value.find((symbol: Symbol) => symbol.symbolId === symbolId) || {}

// 新增: 选中的交易周期
const selectedDuration = ref<number>(1)

// 新增: 交易周期列表
const durations = ref<DurationConfig[]>([])

// 新增: 加载周期配置
const loadDurations = async () => {
  const response = await api.market.getDurations()
  if (response.success && response.data) {
    durations.value = response.data
  }
}
```

#### 4.5.2 User Store 调整

**文件**: `src/store/user.ts`

```typescript
import type { User } from '@/types/user'

// 调整 User 类型使用
const user = ref<User | null>(null)

// getProfile 返回新格式
const getProfile = async () => {
  const response = await api.user.getProfile()
  if (response.success && response.data) {
    setUser(response.data)  // { userId, nickname, status, isDemo, ... }
    return response.data
  }
}
```

---

## 五、时间格式处理

后端返回 ISO 日期字符串格式，前端需要统一处理：

```typescript
// src/utils/timeUtils.ts

// ISO 字符串转时间戳
export function isoToTimestamp(isoString: string): number {
  return new Date(isoString).getTime()
}

// ISO 字符串转 Date 对象
export function isoToDate(isoString: string): Date {
  return new Date(isoString)
}

// 计算剩余时间（秒）
export function getRemainingSeconds(closeTimeIso: string): number {
  const closeTime = new Date(closeTimeIso).getTime()
  const now = Date.now()
  return Math.max(0, Math.floor((closeTime - now) / 1000))
}

// 判断是否已锁定
export function isLocked(lockTimeIso: string): boolean {
  return Date.now() >= new Date(lockTimeIso).getTime()
}
```

---

## 六、文件修改清单

### 6.1 已完成修改 (公开API + WebSocket + Market页面)

```
binary-option-fe/
├── src/
│   ├── api/
│   │   ├── http.ts                  # ✅ 关闭Mock, 新增 getHotSymbols/getDurations
│   │   └── types.ts                 # ✅ Symbol/TradingRound 类型, 新增 DurationConfig
│   │
│   ├── types/
│   │   ├── websocket.ts             # ✅ fixtures→odds, 数组订阅格式, 移除废弃Fixture
│   │   └── market.ts                # ✅ MarketPayout 添加 locked 字段
│   │
│   ├── store/
│   │   ├── market.ts                # ✅ symbolId:number, durations/selectedDuration
│   │   ├── websocket.ts             # ✅ getFixtures→getOdds
│   │   └── README.md                # ✅ 更新文档
│   │
│   ├── websocket/
│   │   └── MarketWebSocket.ts       # ✅ 数组订阅, subscribeAll, odds Mock数据
│   │
│   ├── composables/
│   │   ├── useTrading.ts            # ✅ odds 赔率计算
│   │   ├── useMarketCardData.ts     # ✅ odds 赔率, 移除不必要的round请求
│   │   └── useMarketListData.ts     # ✅ 新增, Market列表数据管理, lockSeconds锁定计算
│   │
│   ├── components/
│   │   ├── trading/
│   │   │   ├── TradingForm.vue      # ✅ odds 赔率显示
│   │   │   └── ExpirationOptions.vue # ✅ odds 数据适配
│   │   │
│   │   └── market/
│   │       └── MarketList.vue       # ✅ 替换mock数据为真实API
│   │
│   └── utils/
│       └── timeUtils.ts             # ✅ 新增 ISO 时间处理工具
```

### 6.2 已完成修改 (订单API对接)

```
binary-option-fe/
├── src/
│   ├── api/
│   │   └── http.ts                  # ✅ 历史订单时间参数改为毫秒时间戳
│   │
│   ├── store/
│   │   ├── order.ts                 # ✅ 活跃/历史订单结构，时间参数类型
│   │   └── market.ts                # ✅ selectedDuration 持久化到 localStorage
│   │
│   ├── components/
│   │   ├── trading/
│   │   │   └── TradingPanel.vue         # ✅ 下单成功后自动刷新活跃订单
│   │   │
│   │   ├── orders/
│   │   │   ├── ActiveOrders.vue         # ✅ API对接，自动刷新（每分钟第1秒）
│   │   │   └── HistoryOrderTable.vue    # ✅ 日期范围筛选，动态tabs，展开/折叠
│   │   │
│   │   └── ui/
│   │       └── CalendarDropdown.vue     # ✅ 新增 change 事件
```

### 6.3 已完成修改 (WebSocket全局初始化)

```
binary-option-fe/
├── src/
│   ├── App.vue                      # ✅ WebSocket全局初始化，onMounted连接，onUnmounted断开
│   │
│   ├── store/
│   │   └── websocket.ts             # ✅ 新增 subscribeAll/unsubscribeAll 方法
│   │
│   └── websocket/
│       └── MarketWebSocket.ts       # ✅ 连接成功后自动订阅所有交易对
```

### 6.4 待完成修改

```
binary-option-fe/
├── src/
│   ├── api/
│   │   └── http.ts                  # [待修改] 新增 getAccountList
│   │
│   ├── types/
│   │   └── user.ts                  # [待修改] 简化 User 类型
│   │
│   ├── store/
│   │   ├── account.ts               # [待修改] 账户信息类型
│   │   └── user.ts                  # [待修改] User 类型
│   │
│   ├── components/
│   │   ├── trading/
│   │   │   ├── TradingPanelCore.vue     # [待检查] 核心交易逻辑
│   │   │   ├── CountdownTimer.vue       # [待检查] ISO 时间格式
│   │   │   └── ChartIQ.vue              # [待检查] 历史数据格式
│   │   │
│   │   └── account/
│   │       └── AutoTraderBalance.vue    # [待检查] 账户余额
│   │
│   └── views/
│       ├── HistoryOrder.vue         # [待检查] 分页结构
│       └── pc/
│           └── HistoryOrder.vue     # [待检查] 分页结构
```

### 6.5 收尾工作

```
binary-option-fe/
├── .env.development                 # [待检查] 确认环境变量
├── .env.production                  # [待检查] 确认环境变量
│
└── src/
    └── mock/                        # [最后删除] 全部对接完成后删除
        ├── index.ts
        ├── mockData.ts
        └── mockMarketListData.ts
```

### 6.6 修改进度

| 分类 | 已完成 | 待完成 | 总计 |
|------|--------|--------|------|
| 公开API | 5 | 0 | 5 |
| WebSocket | 7 | 0 | 7 |
| Market页面 | 3 | 0 | 3 |
| 订单API | 6 | 0 | 6 |
| 认证API | 0 | 4 | 4 |
| 组件适配 | 2 | 5 | 7 |
| **合计** | **23** | **9** | **32** |

---

## 七、测试计划

### 7.1 接口测试

| 测试项 | 预期结果 |
|--------|----------|
| 获取交易对列表 | 返回 Symbol 数组，字段完整 |
| 获取热门交易对 | 返回热门 Symbol 数组 |
| 获取周期配置 | 返回 DurationConfig 数组 |
| 获取当前轮次 | 返回指定交易对的活跃轮次 |
| 获取历史行情 | 返回 [timestamp, price] 数组 |
| 创建订单 | 返回订单详情 |
| 查询活跃订单 | 返回按轮次分组的订单列表 |

### 7.2 WebSocket 测试

| 测试项 | 预期结果 |
|--------|----------|
| 连接建立 | 成功连接 |
| 订阅单个交易对 | 收到 subscribed 确认 |
| 订阅多个交易对 | 收到 subscribed 确认，count 正确 |
| 订阅所有交易对 | 收到 all: true 确认 |
| 接收 Tick 数据 | 包含 price, odds 数组 |
| 心跳检测 | 发送 ping 收到 pong |

### 7.3 业务流程测试

| 场景 | 步骤 |
|------|------|
| 新用户首次访问 | 无 Token → 自动创建 Demo 用户 → 保存 X-Demo-Token |
| Demo 用户下单 | 选择交易对 → 选择周期 → 选择方向 → 输入金额 → 下单成功 |
| 查看活跃订单 | 按轮次分组展示 → 显示用户统计 |
| 查看历史订单 | 分页展示 → 显示盈亏统计 |

---

## 八、实施步骤

### 8.1 阶段一: 准备工作 - ✅ 已完成

- [x] 确认后端 API 可用性
- [x] 配置开发环境
- [x] 创建 feature 分支

### 8.2 阶段二: 公开API对接 - ✅ 已完成

- [x] 关闭 Mock 模式
- [x] 更新类型定义 (`src/api/types.ts`)
- [x] 新增 API 方法 (热门交易对、周期配置)
- [x] 更新 WebSocket 客户端 (数组格式订阅、odds 数据)
- [x] 添加时间处理工具函数
- [x] 更新 market store (周期配置、symbolId 类型)
- [x] 更新 websocket store (getOdds 方法)
- [x] 更新 useTrading composable (odds 赔率)
- [x] 更新 useMarketCardData composable (移除冗余round请求)
- [x] 更新 ExpirationOptions 组件 (odds 数据)
- [x] 更新 TradingForm 组件 (odds 赔率显示)

### 8.3 阶段三: 订单API对接 - ✅ 已完成

- [x] 更新 order store (活跃/历史订单结构)
- [x] 更新 http.ts (历史订单时间参数改为毫秒时间戳)
- [x] 更新 ActiveOrders 组件 (API对接，自动刷新)
- [x] 更新 HistoryOrderTable 组件 (日期范围筛选，动态tabs，展开/折叠)
- [x] 更新 TradingPanel 组件 (下单成功后自动刷新)
- [x] 更新 CalendarDropdown 组件 (新增 change 事件)
- [x] 更新 market store (selectedDuration 持久化)

### 8.4 阶段四: WebSocket全局初始化 - ✅ 已完成

- [x] 更新 websocket store (新增 subscribeAll/unsubscribeAll)
- [x] 更新 MarketWebSocket (连接成功后自动订阅所有交易对)
- [x] 更新 App.vue (全局初始化 WebSocket 连接)

### 8.5 阶段五: 认证API对接 - 待进行

- [ ] 新增 getAccountList API 方法
- [ ] 更新 User 类型定义
- [ ] 更新 user store
- [ ] 更新 account store

### 8.6 阶段六: 组件适配 - 待进行

- [ ] 更新倒计时组件 (ISO 时间格式)
- [ ] 更新 K 线图组件 (历史数据格式)

### 8.7 阶段七: 测试验证 - 待进行

- [x] 公开接口测试
- [x] WebSocket 连接测试
- [x] 订单接口测试
- [ ] 认证接口测试
- [ ] 完整业务流程测试

### 8.8 阶段八: 收尾工作 - 待进行

- [ ] 删除 Mock 文件 (`src/mock/`)
- [x] 更新文档
- [ ] 代码审查
- [ ] 合并主分支

---

## 九、待确认事项

| 序号 | 问题 | 状态 |
|------|------|------|
| 1 | WebSocket 生产环境地址确认 | 待确认 |
| 2 | Demo 用户操作限制（如最大下单金额） | 待确认 |
| 3 | 错误码国际化 key 对照表 | 待确认 |
| 4 | 是否需要支持断线重连的订阅恢复 | 待确认 |

---

## 十、附录

### 10.1 错误码参考

| code | 模块 | 说明 |
|------|------|------|
| 10001-10xxx | 用户模块 | 未认证、用户不存在等 |
| 20001-20xxx | 账户模块 | 账户不存在、余额不足等 |
| 30001-30xxx | 订单模块 | 订单不存在、轮次锁定等 |
| 40001-40xxx | 风控模块 | 风控拦截、限额等 |
| 50001-50xxx | 市场模块 | 品种不存在、数据不可用等 |
| 60001-60xxx | 外部服务 | BTSE 服务错误等 |
| 90001-90xxx | 系统模块 | 配置错误、内部错误等 |

### 10.2 Hot Symbols API 对接

热门交易对 API 已增强，支持按时间区间（duration）返回交易量分解数据。

#### API 端点

```
GET /api/borc/public/order/symbols/hot?limit=10
```

#### 响应格式

```typescript
interface HotSymbolResponse {
  items: HotSymbolItem[]
}

interface HotSymbolItem {
  symbolId: number           // 交易对ID
  symbol: string             // 交易对名称 (如 "BTC-USDT")
  totalVolume24h: number     // 24小时总交易量
  durationVolumes: DurationVolume[]  // 各时间区间交易量（按交易量降序）
}

interface DurationVolume {
  duration: number           // 时间区间（分钟）: 1, 3, 5, 15
  volume24h: number          // 该区间24小时交易量
}
```

#### 响应示例

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [
      {
        "symbolId": 1,
        "symbol": "BTC-USDT",
        "totalVolume24h": 15000.00,
        "durationVolumes": [
          { "duration": 5, "volume24h": 8000.00 },
          { "duration": 3, "volume24h": 4000.00 },
          { "duration": 1, "volume24h": 3000.00 }
        ]
      },
      {
        "symbolId": 2,
        "symbol": "ETH-USDT",
        "totalVolume24h": 12000.00,
        "durationVolumes": [
          { "duration": 5, "volume24h": 6000.00 },
          { "duration": 1, "volume24h": 4000.00 },
          { "duration": 3, "volume24h": 2000.00 }
        ]
      }
    ]
  },
  "success": true
}
```

#### 排序规则

1. **符号级别**：按 `totalVolume24h` 降序（交易量最大的交易对排前面）
2. **区间级别**：每个交易对的 `durationVolumes` 按 `volume24h` 降序排列
3. **无交易量时**：返回所有活跃交易对，`totalVolume24h` 为 0，`durationVolumes` 为空数组

#### 前端类型定义

**文件**: `src/api/types.ts`

```typescript
// 热门交易对响应
export interface HotSymbolResponse {
  items: HotSymbolItem[]
}

// 热门交易对项
export interface HotSymbolItem {
  symbolId: number
  symbol: string
  totalVolume24h: number
  durationVolumes: DurationVolume[]
}

// 时间区间交易量
export interface DurationVolume {
  duration: number
  volume24h: number
}
```

#### 前端 API 调用

**文件**: `src/api/http.ts`

```typescript
// 获取热门交易对（带时间区间交易量）
async getHotSymbols(limit: number = 10): Promise<ApiResponse<HotSymbolResponse>> {
  return httpClient.get(`${API_PREFIX}/public/order/symbols/hot`, { limit })
}
```

#### 使用场景

1. **Market List 页面**：展示热门交易对列表，显示各时间区间的交易量
2. **交易对选择器**：按热度排序交易对
3. **Dashboard**：展示热门交易统计

#### 缓存策略

- 后端每小时第5分钟更新缓存
- 缓存 TTL: 2小时
- 无交易数据时返回所有活跃交易对（交易量为0）

---

### 10.3 相关文档

- [后端 API 文档](../API文档/前端API文档.md)
