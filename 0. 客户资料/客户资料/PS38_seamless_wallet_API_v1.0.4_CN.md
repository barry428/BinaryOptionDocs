# SPORTS38 无缝钱包 API 介绍

本文档旨在作为任何希望与 SPORTS38 平台集成的第三方系统的集成指南。文档详细解释了促进系统间通信的 API 调用。

## 目录

- [文档修订](#文档修订)
- [设置](#设置)
- [请求示例](#请求示例)
- [工作流程](#工作流程)
- [性能和超时](#性能和超时)
- [错误代码](#错误代码)
- [回调请求](#回调请求)
- [API 请求](#api-请求)
- [模型说明](#模型说明)
- [通用数据格式](#通用数据格式)
- [本地化支持](#本地化支持)
- [货币支持](#货币支持)

## 文档修订

| 日期 | 描述 | 版本 |
|------|-------------|---------|
| 2023-10-13 | 文档创建。 | v1.0.1 |
| 2024-05-24 | 更新文档详细信息。 | v1.0.2 |
| 2024-05-31 | 1. 更新回调 [CB002] 中当操作为 PLACED 时的响应体。重命名字段：orderLegs 更改为 legs。删除字段：minStake, targetCurrency, homeRedCards, awayRedCards, periodName, periodId, homeScore。添加新字段：stake, placedDate, totalOdds, status。重命名字段内的 leg：competitionId 更改为 leagueId，competitionName 更改为 leagueName。添加新字段到 legs 中：homeTeam, awayTeam, countryId, settledDate, legStatus, selection, countryName, eventStartDate。 2. 更新响应 [A003], [A004] 以与 [CB002] 保持一致。 3. 修改 [CB002] 操作 ACCEPTED, CANCELLED, SETTLED, CASHED_OUT, RESETTLED 的模型为单个模型以确保一致性。删除字段：winRiskStake。添加新字段：settledStatus, settledAt | v1.0.3 |
| 2024-06-12 | 1. [CB002] 中的 transaction 字段已弃用。 2. 用 order 字段替换 transaction 字段中的数据，以确保 [CB002] 中的所有回调操作使用相同的模型。 3. 将字段 pnl, odds, settledStatus 和 settledAt 添加到 Order 模型中。 | v1.0.4 |

当前版本：v1.0.4

## 设置

在 API 集成过程之前，我们需要同步一些基本数据：

- SPORTS38 将提供：
  - 合作伙伴密钥：用于身份验证检查。
  - 秘密密钥：用于加密/解密数据。
  - API 域：用于接收您的 API 调用。
  - 我们的公共 IP 地址：用于在您的系统中列入白名单。

- 操作员将提供：
  - 回调 URL：以便 SPORTS38 可以在玩家登录、下注或结算时回调。
  - 您的公共 IP 地址：用于允许访问我们的 API 域。

- 首先，您需要实现两个 API，即 [CB001] 和 [CB002]，然后将它们提供用于配置和域白名单。

- 所有发送的请求体必须使用 AES-256 算法（AES/CBC/PKCS7PADDING，iv: 16 个零字节）进行编码。

- 您需要在两个请求中实现它，[CB001] 和 [CB002]，以解码我们将回调给您的内容。您可以参考此链接进行编码和解码测试。[在此测试编码和解码](#)。

## 请求示例

例如，如果您有：
- 合作伙伴密钥：partner_demo
- 秘密密钥：b18932c774df450e87e7951edab4e4ed

如果您想使用此请求体调用 API [A001] 登录，您应该按照以下步骤操作：

1. 您需要使用 AES-256 算法和秘密密钥 b18932c774df450e87e7951edab4e4ed 对 JSON 请求体进行编码。编码后的 JSON 将是：`JpK64ZaMN5azl+VnVJ1+8DcwxwRTlyuGP+dYmB/S3/LWn4GMgrlOmrwFSsRaban7aq3aE9yOjyXKqUnHU1wiFg==`
2. 在请求中包含带有合作伙伴密钥的 x-partner-key 标头。
3. 最后，发送的请求将是：

```bash
curl 'https://{{domain}}/api/v1/login' \
  --header 'Content-Type: application/json' \
  --header 'x-partner-key: partner_demo' \
  --data '{"data": "JpK64ZaMN5azl+VnVJ1+8DcwxwRTlyuGP+dYmB/S3/LWn4GMgrlOmrwFSsRaban7aq3aE9yOjyXKqUnHU1wiFg=="}'
```

## 工作流程

### 玩家设置

### 下注

### 结算

### 订单状态

## 性能和超时

- 超时限制：30 秒。
- 服务器的间隔限制允许每 60 秒每个 IP 最多 100 个请求。如果超过此限制，您可能会收到状态代码为 429 的 HTTP 响应（请求过多）。

## 错误代码

| 键 | 描述 |
|-----|-------------|
| UN_AUTHORIZATION | 授权失败，凭据无效。 |
| SERVER_ERROR | 意外错误。 |
| INSUFFICIENT_FUNDS | 玩家没有足够的资金下注。 |
| INVALID_CURRENCY_CODE | 不支持的货币代码。 |
| INVALID_ODDS_GROUP | 不支持的赔率组。 |
| INVALID_PLAYER_ID | 无效的玩家 ID。 |
| INVALID_DATE_FORMAT | 无效的日期格式。在 API [A004] 中使用。 |
| INVALID_PARTNER_KEY | 合作伙伴密钥不存在。 |
| INVALID_PLAYER_SETTING | 用户设置无效，在 API [CB001] 中使用。 |

以下是我们系统可能返回或您可能返回以指示错误的一些错误代码示例。对于 message 和 errorCode 字段，您可以随意返回，我们仅使用它们来跟踪问题。

```json
{
  "errorCode": "UN_AUTHORIZATION",
  "message": "",
  "data": {},
  "success": false
}
```

```json
{
  "errorCode": "SERVER_ERROR",
  "message": "订单不存在。",
  "data": {},
  "success": false
}
```

## 回调请求

### [CB001] 回调玩家设置

#### 概述
- POST: {{ your_callback_domain }}/api/player/setting
- 此 API 我们调用您的系统以检索您的玩家设置。
- 下面的请求部分仅描述编码前的请求。所有请求都必须在请求示例部分中进行编码和发送。

#### 请求
- 编码前的请求体：
```json
{
  "playerId": "demo_player"
}
```

#### 响应
有关详细信息，请参阅 PlayerSettingResponse 部分。

```json
{
  "errorCode": "",
  "message": "",
  "data": {
    "playerId": "demo_player",
    "oddsGroup": "A"
  },
  "success": true
}
```

### [CB002] 回调玩家交易

#### 概述
- POST: {{ your_callback_domain }}/api/transaction
- 当玩家下注、订单被接受、玩家兑现或我们的平台结算、取消或重新结算订单时，此 API 我们回调到您的系统。
- 下面的请求部分仅描述编码前的请求。所有请求都必须在请求示例部分中进行编码和发送。
- 对于操作类型 PLACED，如果我们收到 success 字段设置为 false 的响应，我们将向您发送带有操作类型 CANCELLED 的回调，以表明必须取消该投注，因为它未被接受。
- 对于其他操作类型（ACCEPTED, CANCELLED, SETTLED, CASHED_OUT, RESETTLED），如果我们收到 success 字段设置为 false 的响应，我们将继续向您重新发送回调最多 5 次，每次尝试间隔 1 分钟。

#### 操作：PLACED
- 当玩家下注时发送此操作类型。
- 您必须从玩家余额中扣除 toRisk 金额。

回调请求体：
有关详细信息，请参阅 TransactionCallBackRequest 部分。

```json
{
  "action": "PLACED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "PENDING_ACCEPTANCE",
    "totalOdds": 1.5230000,
    "toWin": 52.300000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 0,
    "settledStatus": null,
    "settledAt": null,
    "odds": 1.5230000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": null,
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "PENDING_ACCEPTANCE"
      }
    ]
  }
}
```

#### 操作：ACCEPTED
- 当订单被接受时发送此操作类型。
- 您无需调整玩家余额。
- 当您收到操作：ACCEPTED 时，如果订单以更好的赔率被接受，以下某些字段（odds, toWin）的值将发生变化。其他字段与您收到 PLACED 请求时保持不变。更好的赔率示例：下注时赔率：100 美元，odds：1.5（小数），toWin：15 美元，之后此订单以更好赔率 1.6（小数）匹配，所以 toRisk：100 美元，odds：1.6（小数），toWin：16 美元。

回调请求体：
有关详细信息，请参阅 TransactionCallBackRequest 部分。

```json
{
  "action": "ACCEPTED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "ACCEPTED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 0,
    "settledStatus": null,
    "settledAt": null,
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": null,
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "ACCEPTED"
      }
    ]
  }
}
```

#### 操作：CANCELLED
- 当订单被取消时发送此操作类型。您必须将 toRisk 金额加回玩家余额。

回调请求体：
有关详细信息，请参阅 TransactionCallBackRequest 部分。

```json
{
  "action": "CANCELLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "CANCELLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 100.0000000,
    "settledStatus": null,
    "settledAt": null,
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": null,
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "CANCELLED"
      }
    ]
  }
}
```

#### 操作：SETTLED
- 当订单结算时发送此操作类型。您必须将收益和亏损（pnl）加到玩家余额中。

回调请求体：
有关详细信息，请参阅 TransactionCallBackRequest 部分。

```json
{
  "action": "SETTLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 160.0000000,
    "settledStatus": "WON",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "WON"
      }
    ]
  }
}
```

不同结算状态：

```json
{
  "action": "SETTLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 130.0000000,
    "settledStatus": "HALF_WON_HALF_PUSHED",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": 0.25,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "盘口",
        "liveScore": null,
        "legStatus": "HALF_WON_HALF_PUSHED"
      }
    ]
  }
}
```

```json
{
  "action": "SETTLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 50.0000000,
    "settledStatus": "HALF_LOST_HALF_PUSHED",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "SPREAD",
        "handicap": 0.25,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "盘口",
        "liveScore": null,
        "legStatus": "HALF_LOST_HALF_PUSHED"
      }
    ]
  }
}
```

```json
{
  "action": "SETTLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 100.0000000,
    "settledStatus": "REFUNDED",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "REFUNDED"
      }
    ]
  }
}
```

```json
{
  "action": "SETTLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 0.0000000,
    "settledStatus": "LOST",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "LOST"
      }
    ]
  }
}
```

#### 操作：CASHED_OUT
- 当玩家选择兑现订单，并在比赛最终结果之前提前结算时发送此状态。您必须将收益和亏损（pnl）加到玩家余额中。

回调请求体：
有关详细信息，请参阅 TransactionCallBackRequest 部分。

```json
{
  "action": "CASHED_OUT",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 150.0000000,
    "settledStatus": "CASHED_OUT",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "CASHED_OUT"
      }
    ]
  }
}
```

#### 操作：RESETTLED
- 当您收到操作 RESETTLED 时，您必须重新计算 pnl 的变化以更新玩家余额。
- 对于操作 RESETTLED，在某些情况下，您可能会收到同一订单 ID 的多个回调。在这种情况下，您必须根据收到的最新 SETTLED 或 RESETTLED 事件重新计算调整后的 pnl，遵循以下说明。
- 例如，最初玩家余额为 1000。玩家下注。您收到带有操作 PLACED 的回调，赔率 1.5（小数），toRisk：100，toWin：50。您从玩家余额中扣除 100 toRisk。此时，玩家余额为 900。然后您收到回调操作：SETTLED pnl：150。您需要保存此 pnl（1）。您将 150 加到玩家余额。此时，玩家余额为 1050。然后您收到回调 RESETTLED，pnl：75（2）。您计算 pnl 的差值，通过（2）-（1）= 75 - 150 = -75。然后将 pnl 差值加到玩家余额：1050 - 75 = 975。

回调请求体：
有关详细信息，请参阅 TransactionCallBackRequest 部分。

```json
{
  "action": "RESETTLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 0.0000000,
    "settledStatus": "LOST",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "LOST"
      }
    ]
  }
}
```

```json
{
  "action": "RESETTLED",
  "order": {
    "orderId": 10005211,
    "orderType": "STRAIGHT",
    "playerId": "demo_player",
    "placedDate": "2024-06-12T00:03:58-04:00",
    "status": "SETTLED",
    "totalOdds": 1.6000000,
    "toWin": 60.0000000,
    "toRisk": 100.0000000,
    "stake": 100.0000000,
    "oddsFormat": "DECIMAL",
    "pnl": 160.0000000,
    "settledStatus": "WON",
    "settledAt": "2024-06-13T00:03:58-04:00",
    "odds": 1.6000000,
    "legs": [
      {
        "legId": "10f13772-aed2-48ad-90e9-30d507523da5",
        "sportId": 29,
        "sportName": "足球",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "欧洲超级杯",
        "eventId": 1592591618,
        "eventName": "皇家马德里 vs 亚特兰大",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "皇家马德里",
        "homeTeam": "皇家马德里",
        "awayTeam": "亚特兰大",
        "countryId": 78729646,
        "countryName": "欧洲",
        "marketId": 3696453,
        "marketName": "1X2 比赛",
        "liveScore": null,
        "legStatus": "WON"
      }
    ]
  }
}
```

#### 响应
响应体：
有关详细信息，请参阅 TransactionCallBackResponse 部分。

```json
{
  "errorCode": "",
  "message": "",
  "data": {
    "orderId": 10004835,
    "adjustedBalance": 0,
    "positionTaken": null
  },
  "success": true
}
```

## API 请求

### [A001] 登录 API

#### 概述
- POST: {{ our_api_domain }}/api/v1/login
- 此 API 用于检索 SPORTS38 大厅的登录 URL。
- 下面的请求部分仅描述编码前的请求。所有请求都必须在请求示例部分中进行编码和发送。

#### 请求
有关详细信息，请参阅 LoginRequest 部分。

```json
{
  "locale": "en-US",
  "currencyCode": "HKD",
  "device": "DESKTOP",
  "playerId": "demo_player",
  "theme": "",
  "view": "",
  "timeZone": ""
}
```

```bash
curl '{{domain}}/api/v1/login' \
  --header 'x-partner-key: partner_demo' \
  --header 'Content-Type: application/json' \
  --data '{"data":"Q0fVW1y1eQSHbWZ0ZK+Q9mIkqNeRY+bWRkbv4V28OUwyFcZtT6Cha3EEdWj9O0npT66sEzWosfdkze1ZfSC3ZRf30wJ2MYgl9Ejd9Aoq/xfBZLiC0AS1Zymv3O1XhF9QsYeJotPnB6BhtoWdWRKEX/Zc8UoV2zASwNmWjuTS6ufWjhkFYgcqDm1gKszIQrBfRw4MlJgvcCsZntGg06CIIw=="}'
```

#### 响应

```json
{
  "errorCode": "",
  "message": "",
  "data": {
    "url": "https://prostg.beatus88.com/proteus-ui/#/iframe?token=JMdqkSjEKzQRR5ZuEsx2P5eiHXSJYaMOxGPHCWDYLouRtMHLUXIXtWwkzeotAL2IT1mRfPrqhbnAQl0svRLT1p8abogyEeD92K69Mhw5MLo%3D&device=DESKTOP&theme=default&locale=en-US"
  },
  "success": true
}
```

```json
{
  "errorCode": "INVALID_PARTNER_KEY",
  "message": "无效的合作伙伴密钥",
  "data": "{}",
  "success": false
}
```

```json
{
  "errorCode": "INVALID_PLAYER_SETTING",
  "message": "无效的玩家设置",
  "data": "{}",
  "success": false
}
```

### [A002] 登出 API

#### 概述
- POST: {{ our_api_domain }}/api/v1/logout
- 此 API 用于过期当前登录玩家的会话。
- 下面的请求部分仅描述编码前的请求。所有请求都必须在请求示例部分中进行编码和发送。

#### 请求

```json
{
  "playerId": "demo_player"
}
```

```bash
curl '{{domain}}/api/v1/logout' \
  --header 'x-partner-key: partner_demo' \
  --header 'Content-Type: application/json' \
  --data '{"data": "RaYgjAQeJqSP8u5Y7VnB5DaTo4IfCbUmny1L+YQH2vc="}'
```

#### 响应

```json
{
  "errorCode": "",
  "message": "",
  "data": "{}",
  "success": true
}
```

### [A003] 按 ID 获取订单

#### 概述
- POST: {{ our_api_domain }}/api/v1/bets
- 此 API 允许发送多个订单 ID 以检索订单信息。
- 下面的请求部分仅描述编码前的请求。所有请求都必须在请求示例部分中进行编码和发送。
- 每个请求的最大订单 ID 数为 100。

#### 请求
请求体：
```json
[10004616,10004617,10004618]
```

示例 Curl：
```bash
curl '{{domain}}/api/v1/bets' \
  --header 'x-partner-key: partner_demo' \
  --header 'Content-Type: application/json' \
  --data '{"data": "FdIhq29ltAovaxF6wwJznQWklAu+Z3yKBTCTtHzkzLSVmdA7X+BNM4U7blB3PlgU"}'
```

#### 响应
有关详细信息，请参阅 ListOrdersResponse 部分。

```json
{
  "errorCode": "",
  "message": "",
  "data": {
    "orders": [
      {
        "orderId": 10004616,
        "orderType": "STRAIGHT",
        "placedDate": "2024-05-30T04:17:45-04:00",
        "status": "ACCEPTED",
        "totalOdds": 1.859,
        "toWin": 17.18,
        "toRisk": 20.0,
        "stake": 20.0,
        "oddsFormat": "DECIMAL",
        "pnl": 0,
        "settledStatus": null,
        "settledAt": null,
        "odds": 1.859,
        "legs": [
          {
            "sportId": 29,
            "sportName": "足球",
            "betType": "MONEYLINE",
            "handicap": null,
            "leagueId": 2102,
            "leagueName": "冰岛 - 超级联赛",
            "eventId": 1592092637,
            "eventName": "瓦鲁尔雷克雅未克 vs 斯塔尔南",
            "oddsFormat": "DECIMAL",
            "odds": 1.859,
            "eventStartDate": "2024-05-30T14:00:00-04:00",
            "live": false,
            "settledDate": null,
            "selection": "瓦鲁尔雷克雅未克",
            "homeTeam": "瓦鲁尔雷克雅未克",
            "awayTeam": "斯塔尔南",
            "countryId": 78729586,
            "countryName": "冰岛",
            "marketId": 3570283,
            "marketName": "1X2 比赛",
            "liveScore": null,
            "legStatus": "ACCEPTED",
            "legId": "ab8d466e-05dc-4ab3-8274-25db065c6ab7"
          }
        ],
        "playerId": "demo_player"
      },
      {...},
      {...}
    ],
    "totalRecord": 3
  },
  "success": true
}
```

### [A004] 按时间范围获取订单

#### 概述
- POST: {{ our_api_domain }}/api/v1/bets/period
- 此 API 用于根据下注时间获取订单。开始日期最多可追溯 30 天。
- 下面的请求部分仅描述编码前的请求。所有请求都必须在请求示例部分中进行编码和发送。

#### 请求
请求体：
```json
{
  "playerId": "demo_player",
  "orderStatus": "ACCEPTED",
  "limit": 10,
  "offset": 0,
  "fromDate": "2024-05-30T00:00:00-04:00",
  "toDate": "2024-06-01T06:00:00-04:00"
}
```

有关详细信息，请参阅 OrderByTimeRangeRequest 部分。

示例 Curl：
```bash
curl '{{domain}}/api/v1/bets/period' \
  --header 'x-partner-key: partner_demo' \
  --header 'Content-Type: application/json' \
  --data '{"data":"JpK64ZaMN5azl+VnVJ1+8NBXHiCG9BQGn3n1WXXIOSuzTQ6/74naNObVVwhyO4bAaqeakSHy8Nvty2lS1ETEKIL2vcct0+o2EpQLSHzvnLBiAPfSktANN1oSjMbB+tA/FN8ZLg3bIbmtGF8prup/hQu1U9N+jq/UFd8En5LVSNYfcOb8tHTC04c3jJHsOuXRya+3OP13I8HbnSda0WToR6cw+buIy4mIEioD4mcgM/PIYRIKLiRcmi5X6oJ9tykQ"}'
```

#### 响应
有关详细信息，请参阅 ListOrderResponse 部分。

```json
{
  "errorCode": "",
  "message": "",
  "data": {
    "orders": [
      {
        "orderId": 10004851,
        "orderType": "STRAIGHT",
        "placedDate": "2024-05-30T04:17:45-04:00",
        "status": "ACCEPTED",
        "totalOdds": 1.859,
        "toWin": 17.18,
        "toRisk": 20.0,
        "stake": 20.0,
        "oddsFormat": "DECIMAL",
        "pnl": 0,
        "settledStatus": null,
        "settledAt": null,
        "odds": 1.859,
        "legs": [
          {...}
        ],
        "playerId": "demo_player"
      },
      {...},
      {...}
    ],
    "totalRecord": 3
  },
  "success": true
}
```

## 模型说明

### LoginRequest
在 [A001] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| locale | String | 请参阅 LOCALE SUPPORT 部分。默认值：en-US |
| currencyCode | String | （必需*）请参阅 CURRENCY SUPPORT 部分。 |
| device | ENUM | - MOBILE - DESKTOP 默认值：DESKTOP |
| playerId | String | （必需*）最多 45 个字符，包括字母、数字和特殊字符。 |
| theme | String | 此值仅在合作伙伴请求时可用。 |
| view | ENUM | - ASIAN - EURO 默认值：ASIAN |
| timeZone | String | 默认值：+00:00 |

### LoginResponse
在 [A001] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| url | String | 允许玩家访问 Sports38 主页的 URL |

### TransactionCallBackRequest
在 [CB002] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| action | String | 指明此回调的类型。 |
| order | Order | 订单信息。 |
| transaction | String | 此字段的值是从 order 字段转换而来的 JSON 字符串。自版本 1.0.4 起，此字段已弃用。请切换到使用 order 字段。 |

### TransactionCallBackResponse
在 [CB002] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| orderId | Long | 订单标识。您返回我们在 order.orderId 中发送给您的 orderId 值。 |
| positionTaken | Decimal | 此值仅在操作类型为 PLACED 且合作伙伴请求此功能时需要。值范围取决于业务协议。表示您在此订单上想要承担的头寸。0 是 0 百分比，1 是 100 百分比。 |
| adjustedBalance | Money | 用于跟踪回调到您后您在玩家余额中更改的金额值。-10 表示从玩家钱包中成功扣除 10 美元。 |

### Order
在 [CB002], [A003], [A004] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| orderType | ENUM | - STRAIGHT - SPECIAL - PARLAY 过关订单有超过 1 条腿。直通和特殊订单有 1 条腿。 |
| oddsFormat | ENUM | - AMERICAN - DECIMAL - HONGKONG - MALAY - INDONESIAN 仅当玩家货币为 IDR 时支持印尼赔率。当玩家在 MONEYLINE 市场类型下注并选择 HONGKONG, MALAY 或 INDONESIAN 赔率格式时，赔率格式将始终为 DECIMAL。这是因为 MONEYLINE 仅支持 DECIMAL 和 AMERICAN 赔率格式。 |
| status | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - CASHED_OUT - SETTLED 订单状态。 |
| orderId | Long | 订单标识。 |
| stake | Money | 玩家输入的金额。 |
| toWin | Money | 订单可能赢得的最大金额。 |
| legs | List<Leg> | |
| placedDate | DateTime | 订单下注日期。 |
| totalOdds | Odds | - STRAIGHT: totalOdds 与腿赔率相同。 - SPECIAL: totalOdds 与腿赔率相同。 - PARLAY: totalOdds 是基于所有腿赔率计算的过关赔率。如果所选赔率以小数格式表示，totalOdds = 赔率1 * 赔率2 * ... * 赔率n。例如，如果玩家选择赔率1为 1.892（小数）和赔率2为 2.070（小数），则过关投注的赔率 = 1.892 * 2.070 = 3.916（小数）。如果所选赔率不是小数格式，totalOdds =（赔率1转换为小数 * 赔率2转换为小数 * ... * 赔率n转换为小数），然后从小数转换为所选的赔率类型。例如，如果玩家选择赔率1为 0.892（香港）和赔率2为 1.070（香港），则过关投注的赔率 = 1.892（转换为小数）* 2.070（转换为小数）= 3.916（小数）= 2.916（香港）。所选赔率是用户在下注时选择的赔率。 |
| playerId | String | 玩家标识。 |
| toRisk | Money | 订单可能损失的最大金额。 |
| pnl | Money | 包括 toRisk 的订单盈亏金额。例如，如果玩家以 toRisk 100 下注并赢得 50，盈亏（收益和亏损）为 150。 |
| odds | Odds | 订单的投注赔率。 |
| settledStatus | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - WON - LOST - HALF_WON_HALF_PUSHED - HALF_LOST_HALF_PUSHED - REFUNDED - CASHED_OUT WON: 订单结算为赢。 HALF_WON_HALF_PUSH: 订单结算为半赢半推。仅适用于亚洲盘口。 HALF_LOST_HALF_PUSH: 订单结算为半输半推。仅适用于亚洲盘口。 LOST: 订单结算为输。 REFUNDED: 当事件被取消或订单结算为推时。 CASHED_OUT: 允许玩家在比赛官方结果确定之前出售他们的投注。 |
| settledAt | DateTime | 订单结算日期。订单未结算时为 null。 |

### Leg
在 [CB002], [A003], [A004] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| sportId | Long | 体育标识。 |
| sportName | String | 体育名称。 |
| betType | String | 此值决定投注类型。例如，当玩家在 1x2 市场下注时，betType 将是 MONEYLINE，对于亚洲盘口，它将是 SPREAD。 |
| handicap | Decimal | 当腿不支持让分时，该让分将为 null，例如在 MONEYLINE（1x2）腿中。 |
| leagueId | Long | 联赛标识。 |
| leagueName | String | 联赛名称。 |
| eventId | Long | 事件标识。 |
| eventName | String | 事件名称。 |
| oddsFormat | ENUM | - AMERICAN - DECIMAL - HONGKONG - MALAY - INDONESIAN 仅当玩家货币为 IDR 时支持印尼赔率。当玩家在 MONEYLINE 市场类型下注并选择 HONGKONG, MALAY 或 INDONESIAN 赔率格式时，赔率格式将始终为 DECIMAL。这是因为 MONEYLINE 仅支持 DECIMAL 和 AMERICAN 赔率格式。 |
| odds | Odds | 腿的投注赔率。 |
| eventStartDate | DateTime | 事件开始日期 |
| live | Boolean | 此值决定比赛是现场还是赛前。 |
| settledDate | DateTime | 腿的结算日期。腿未结算时为 null。 |
| selection | String | 玩家的选择。 |
| homeTeam | String | 主队名称 |
| awayTeam | String | 客队名称 |
| countryId | Long | 国家标识。 |
| countryName | String | 国家名称。 |
| marketId | Long | 市场标识。 |
| marketName | String | 市场名称。 |
| liveScore | String | 仅当字段 "live" 为 true 时才支持此值；否则，它将为 null。此字段仅支持 sportId 29, sportName 足球。示例：1-1 |
| legStatus | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - WON - LOST - HALF_WON_HALF_PUSHED - HALF_LOST_HALF_PUSHED - REFUNDED - CASHED_OUT 腿的状态 |
| legId | UUID | 有两个或更多腿的订单称为过关订单。 |

### OrdersByTimeRangeRequest
在 [A004] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| playerId | String | （必需*）玩家标识。 |
| offset | Long | 从 0 开始。结果的起始记录。默认值为 0。 |
| limit | Long | 最大值为 1000。默认值为 100。 |
| fromDate | DateTime | （必需*）请求期间的开始日期。开始日期最多可追溯 30 天。预期格式为 ISO8601。此字段将根据下注日期筛选订单。 |
| toDate | DateTime | （必需*）请求期间的结束日期。预期格式为 ISO8601。此字段将根据下注日期筛选订单。 |
| orderStatus | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - CASHED_OUT - SETTLED 要返回的订单状态类型。这是一个额外的筛选器。如果为空，将返回所有当前状态。 |

### ListOrdersResponse
在 [A003], [A004] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| orders | List<Order> | |
| totalRecord | Long | 总记录数。 |

### PlayerSettingResponse
在 [CB001] 中使用的模型

| 字段名称 | 数据类型 | 描述 |
|------------|-----------|-------------|
| playerId | String | 玩家标识。 |
| oddsGroup | ENUM | - A - B - C - D - E 赔率组仅控制赔率的吸引力。A 类型将为玩家提供最佳赔率，E 将为玩家提供最差赔率。 |

## 通用数据格式

所有 API 仅支持 JSON 格式。

| 数据类型 | 描述 |
|-----------|-------------|
| DateTime | 所有日期遵循格式：yyyy-MM-dd'T'HH:mm:ssXXX（ISO8601）。例如：2024-06-03T11:30:00-04:00 |
| Money | 所有金额显示 7 位小数。示例 12.0511234。 |
| Boolean | 布尔逻辑值。 |
| String | 字符串值。 |
| Long | 长整数值。 |
| Integer | 整数值。 |
| Decimal | 小数值。有 2 位小数。 |
| Odds | 小数值。有 3 位小数。 |

## 本地化支持

| 键 | 描述 |
|-----|-------------|
| en-US | 英语。 |
| ko-KR | 韩语。 |

## 货币支持

> **注意**：仅当玩家货币为 IDR 时支持印尼赔率格式。

| 货币代码 | 货币名称 | 单位 |
|---------------|---------------|------|
| AED | 阿联酋迪拉姆 | 1 |
| AMD | 亚美尼亚德拉姆 | 1 |
| ARS | 阿根廷比索 | 1 |
| AUD | 澳元 | 1 |
| AZN | 阿塞拜疆新马纳特 | 1 |
| BDT | 孟加拉塔卡 | 1 |
| BGN | 保加利亚列弗 | 1 |
| BRL | 巴西雷亚尔 | 1 |
| CAD | 加元 | 1 |
| CLP | 智利比索 | 1 |
| CNY | 人民币 | 1 |
| COP | 哥伦比亚比索 | 1 |
| CRC | 哥斯达黎加科朗 | 1 |
| CSK | 捷克共和国克朗 | 1 |
| DKK | 丹麦克朗 | 1 |
| ETB | 埃塞俄比亚比尔 | 1 |
| EUR | 欧元 | 1 |
| GBP | 英镑 | 1 |
| GEL | 格鲁吉亚拉里 | 1 |
| GSH | 加纳塞地 | 1 |
| HKD | 港元 | 1 |
| IDR | 印尼卢比 | 1000 |
| ILS | 以色列新谢克尔 | 1 |
| INR | 印度卢比 | 1 |
| JIN | JIN 币加密货币 | 1 |
| JPY | 日元 | 1 |
| KES | 肯尼亚先令 | 1 |
| KGS | 吉尔吉斯斯坦索姆 | 1 |
| KHR | 柬埔寨瑞尔 | 1000 |
| KRW | 韩元 | 1 |
| KZT | 哈萨克斯坦坚戈 | 1 |
| LAK | 老挝基普 | 1000 |
| MBT | 毫比特币 | 1 |
| MDL | 摩尔多瓦列伊 | 1 |
| MGA | 马达加斯加阿里亚里 | 1000 |
| MMK | 缅甸元 | 1000 |
| MXP | 墨西哥比索 | 1 |
| MYR | 马来西亚林吉特 | 1 |
| NGN | 尼日利亚奈拉 | 1 |
| NOK | 挪威克朗 | 1 |
| NPR | 尼泊尔卢比 | 1 |
| NZD | 新西兰元 | 1 |
| PEN | 秘鲁索尔 | 1 |
| PHP | 菲律宾比索 | 1 |
| PKR | 巴基斯坦卢比 | 1 |
| PLZ | 波兰兹罗提 | 1 |
| RON | 罗马尼亚列伊 | 1 |
| RUB | 俄罗斯卢布 | 1 |
| SEK | 瑞典克朗 | 1 |
| SGD | 新元 | 1 |
| SSP | 南苏丹镑 | 1 |
| THB | 泰铢 | 1 |
| TJS | 塔吉克斯坦索莫尼 | 1 |
| TRY | 土耳其里拉 | 1 |
| TWD | 台币 | 1 |
| UAH | 乌克兰格里夫纳 | 1 |
| UDC | USDC 加密货币 | 1 |
| UDT | USDT 加密货币 | 1 |
| UGX | 乌干达先令 | 1000 |
| USD | 美元 | 1 |
| UYU | 乌拉圭比索 | 1 |
| UZS | 乌兹别克斯坦苏姆 | 1 |
| VES | 委内瑞拉玻利瓦尔 | 1 |
| VND | 越南盾 | 1000 |
| VP | 虚拟点数 | 1 |
| YEN | 日元 | 1 |
| ZAR | 南非兰特 | 1 |