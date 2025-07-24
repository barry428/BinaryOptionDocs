
# Binary Option - MVP

## 1. Version

| Version | Date            | Author        | Description                                    |
|---------|-----------------|---------------|------------------------------------------------|
| v0.1    | 2025年5月7日     | Danny Chen     | Draft                                          |
| v0.2    | 2025年6月25日    | Kunyuan Li     | Supplement the feature list and user flow; Supplement Demo Trading Integration |

## 2. Basic Information

- **Launch Platform**: BTSE  
- **Target Release**: —  
- **Document Status**: DRAFT  
- **Business Owner**: —  
- **Product Manager**: —  
- **Project Manager**: —  
- **Business Requirement Document**: [Link]  
- **Jira Ticket**: —  
- **Figma**: https://www.figma.com/design/NzWOl31hVKE8vmdfCMMyd8/Binary-Options?node-id=4-2&t=xnpx2oSC4IcWuFTE-1  
- **Figma 密码**: `bo888`  

## 3. Problems to Solve

（此部分原文未详细列出问题，可补充）

## 4. How Can We Address These Concerns?

（此部分原文未详细列出内容，可补充）

## 5. Success Metrics (Optional)

| Role            | Responsibility |
|-----------------|----------------|
| Product Designer | —              |
| Data Analyst     | —              |

### Success Criteria

| Key Metrics         | Data Specification | Data Report |
|---------------------|--------------------|-------------|
| 强制风险披露         | 用户首次使用前必须确认  | 高             |
| 每日投注限额          | 默认：$100,000/天，可配置 | 高             |

## 6. Feature Map / Scope

### 6.1 User Access & Onboarding Module

- 风险披露确认
- AML 同意协议
- 初始操作提示
- 强制设置投注限制

### 6.2 Trading Interface Module

| Feature              | Requirement                                      | Priority | Acceptance Criteria |
|----------------------|--------------------------------------------------|----------|----------------------|
| Asset Selection      | 多币种支持，MVP：BTC/USDT                       | 高       | 支持后续 ETH/USDT |
| Round Duration       | 时间轮次，MVP：5分钟                            | 高       | 支持未来15m/1h   |
| Real-time Chart      | 实时行情图，1秒更新                             | 高       | 支持6小时缩放历史数据 |
| Price Feed Source    | 多交易所加权平均价（BTSE、Binance、OKX、Coinbase） | 高       | 延迟 < 1s           |
| Round Status         | 实时状态显示，LIVE/NEXT 带倒计时                 | 高       | 明确视觉反馈         |
| Countdown Timer      | 锁单前红色警告 <30 秒                           | 高       | 自动禁用投注         |
| Demo/Live Toggle     | 真实与模拟切换，确认提示                        | 高       | 页面刷新与提示切换    |

### 6.3 Betting System Module

| Feature             | Description                               | Priority | Acceptance Criteria |
|---------------------|-------------------------------------------|----------|----------------------|
| Direction Selection | UP / DOWN                                | 高       | 清晰视觉按钮         |
| Bet Amount Rules    | 最小 $10，最大 $10,000                   | 高       | 配置化               |
| Amount Input        | 快捷按钮 + 手动输入                       | 高       | 25/50/75/100%        |
| Balance Validation  | 实时余额校验                              | 高       | 防止余额不足投注     |
| Bet Confirmation    | 显示预期收益和倍数，确认后下单              | 高       | 最终确认弹窗         |

### 6.4 Information Display Module

- 虚拟余额管理（模拟初始 $10,000，可重置）
- 奖池 Dashboard（当前总池、UP/DOWN 比例、奖励倍数）
- 实时余额显示（区分真实/模拟）
- 当前投注显示（金额、方向、收益）

### 6.5 Settlement System Module

| Feature              | Description                                     | Priority | Acceptance Criteria |
|----------------------|-------------------------------------------------|----------|----------------------|
| Price Locking        | 开始时锁定价格和时间戳                          | 高       | 精准记录              |
| Auto-Settlement      | 轮次结束后3秒内自动结算                         | 高       | 自动触发              |
| Settlement Logic     | 比较起始/结束价格，胜/负/平判断                   | 高       | 明确规则              |
| Payout Distribution  | 真实交易：中奖×97%；模拟：虚拟余额更新            | 高       | 即时到账/更新         |
| Result Display       | 胜负结果展示（✅❌⚖，附 “SIMULATED” 标签）       | 高       | 明确可视反馈          |

### 6.6 User Interface Components

- 主界面五区布局
  1. Header：资产/时间选择 + 模拟/真实切换
  2. 中部：K线图 + 当前价格
  3. 状态栏：倒计时 + 奖池
  4. 操作区：UP/DOWN + 金额输入
  5. Footer：当前投注 + 余额 + 模式标记
- 交易记录页：历史记录 / 公共结果 / PNL 统计
- 用户设置页：投注限制 / 风控偏好 / 虚拟账户管理

### 6.7 Risk Management Module

- 价格延迟监控（超 1 秒暂停轮次）
- 单轮最大投注额限制（$10,000）
- 年龄校验（18+）

### 6.8 Business Rules & Monetization

- 收费机制：仅对中奖用户收取 3% 手续费
- 模拟交易仅限虚拟账户，不计入真实财务系统

## 7. Requirements

### 7.1 Main User Flow

| 阶段     | 用户操作                          | 系统反馈                        |
|----------|-----------------------------------|---------------------------------|
| 准备     | 同意 AML，查看提示                 | 解锁功能，显示奖励倍数           |
| 投注     | 选择方向 + 输入金额（≥10） + 确认   | 显示预计收益，扣除账户余额        |
| 等待     | 观察实时价格变动                    | 实时更新，禁止修改/取消           |
| 结算     | 无需操作                           | 5 分钟后自动弹出结果提示         |

### 关键术语解释

- **AML**: 反洗钱条款
- **Reward Multiplier**: 奖励系数（如 1.8x）
- **Locked Price**: 轮次开始时的锁定价格
- **Settlement Price**: 轮次结束时的结算价格
- **PNL**: 盈亏统计

### 7.2 BTSE Web

（待补充）

## 8. Future Plan (Optional)

（待补充）

## 9. References

- [IQ Option 示例](https://iqoption.com/traderoom)  
- [Rollbit 示例](https://rollbit.com/trading/BTC)  
- [Figma 原型链接](https://www.figma.com/design/NzWOl31hVKE8vmdfCMMyd8/Binary-Options?node-id=4-2&t=xnpx2oSC4IcWuFTE-1)
