# SPORTS38 Seamless Wallet API Introduction

This document is designed to serve as an integration guide for any third-party system looking to integrate with the SPORTS38 platform. The document provides a detailed explanation of the API calls that facilitate communication between the systems.

## Contents

- [Document Revision](#document-revision)
- [Setup](#setup)
- [Request Sample](#request-sample)
- [Workflow](#workflow)
- [Performance and Timeout](#performance-and-timeout)
- [Error Code](#error-code)
- [Callback Request](#callback-request)
- [API Request](#api-request)
- [Model Explain](#model-explain)
- [Common Data Format](#common-data-format)
- [Locale Support](#locale-support)
- [Currency Support](#currency-support)

## Document Revision

| Date | Description | Version |
|------|-------------|---------|
| 2023-10-13 | Document creation. | v1.0.1 |
| 2024-05-24 | Update document detail. | v1.0.2 |
| 2024-05-31 | 1. Updated response body in callback [CB002] when action is PLACED. Renamed field: orderLegs is changed to legs. Removed fields: minStake, targetCurrency, homeRedCards, awayRedCards, periodName, periodId, homeScore. Added new field: stake, placedDate, totalOdds, status. Renamed fields within leg: competitionId is changed to leagueId, competitionName is changed to leagueName. Added new fields within legs: homeTeam, awayTeam, countryId, settledDate, legStatus, selection, countryName, eventStartDate. 2. Updated response [A003], [A004] to be consistent with [CB002]. 3. Modified the model of [CB002] actions ACCEPTED, CANCELLED, SETTLED, CASHED_OUT, RESETTLED to a single model to ensure consistency. Removed field: winRiskStake. Added new fields: settledStatus, settledAt | v1.0.3 |
| 2024-06-12 | 1. The transaction field in [CB002] is deprecated. 2. Replace the data in the transaction field with the order field to ensure that all callback actions in [CB002] use the same model. 3. Add the fields pnl, odds, settledStatus and settledAt to the Order model. | v1.0.4 |

Current version: v1.0.4

## Setup

Here are some essential data we need to sync up before API integration process:

- SPORTS38 will provide:
  - Partner Key: for identification check.
  - Secret key: to encrypt/decrypt data.
  - API domain: to receive your API calls.
  - Our public IP address: to whitelist in your system.

- Operator will provide:
  - Callback URLs: so SPORTS38 can callback when player logs in, places an order, or settles an order…
  - Your public IP address: to allow access to our API domain.

- Firstly, you are required to implement two APIs, namely [CB001] and [CB002], then provide both of them for configuration and domain whitelisting.

- All request bodies sent must be encoded by using the AES-256 algorithm (AES/CBC/PKCS7PADDING, iv: 16 zero bytes) with the secret key.

- You need to implement it in two requests, [CB001] and [CB002], to decode the body that we'll callback to you. You can refer to this link for testing encode and decode. [Test encode and decode here](#).

## Request Sample

For example, if you have:
- Partner key: partner_demo
- Secret key: b18932c774df450e87e7951edab4e4ed

If you want to call the API [A001] to login with this request body, you should follow these steps below:

1. You need to encode the JSON request body by using the AES-256 algorithm with the secret key b18932c774df450e87e7951edab4e4ed. The JSON after encoded will be: `JpK64ZaMN5azl+VnVJ1+8DcwxwRTlyuGP+dYmB/S3/LWn4GMgrlOmrwFSsRaban7aq3aE9yOjyXKqUnHU1wiFg==`
2. Include the header x-partner-key with the partner key in the request.
3. Finally, the sent request will be:

```bash
curl 'https://{{domain}}/api/v1/login' \
  --header 'Content-Type: application/json' \
  --header 'x-partner-key: partner_demo' \
  --data '{"data": "JpK64ZaMN5azl+VnVJ1+8DcwxwRTlyuGP+dYmB/S3/LWn4GMgrlOmrwFSsRaban7aq3aE9yOjyXKqUnHU1wiFg=="}'
```

## Workflow

### Player setting

### Bet placement

### Settlement

### Order status

## Performance and Timeout

- Timeout limit: 30 seconds.
- The server's interval limit permits a maximum of 100 requests per IP every 60 seconds. If this limit is exceeded, you will likely receive an HTTP response with status code 429 Too Many Requests.

## Error Code

| Key | Description |
|-----|-------------|
| UN_AUTHORIZATION | Authorization failed, invalid credentials. |
| SERVER_ERROR | Unexpected error. |
| INSUFFICIENT_FUNDS | The player does not have enough money to place the order. |
| INVALID_CURRENCY_CODE | Currency code does not support. |
| INVALID_ODDS_GROUP | Odds group does not support. |
| INVALID_PLAYER_ID | Invalid player id. |
| INVALID_DATE_FORMAT | Invalid date format. Use in api [A004]. |
| INVALID_PARTNER_KEY | Partner key does not exist. |
| INVALID_PLAYER_SETTING | User setting is invalid, used in API [CB001]. |

Below are some sample error codes that our system may return or you may return to indicate errors. For the field message and errorCode, you can return them arbitrarily, we only use them to track issues.

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
  "message": "Order does not exist.",
  "data": {},
  "success": false
}
```

## Callback Request

### [CB001] Callback player setting

#### Overview
- POST: {{ your_callback_domain }}/api/player/setting
- This API we call to your system to retrieve your player setting.
- The request section below only describes the request before encoding. All request must be encoded and sent in the request sample section.

#### Request
- Request body before encode:
```json
{
  "playerId": "demo_player"
}
```

#### Response
Refer to the PlayerSettingResponse section for an explanation.

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

### [CB002] Callback player transaction

#### Overview
- POST: {{ your_callback_domain }}/api/transaction
- This API we callback to your system when player places an order, order accepted, or player cash-out, or our platform settles, cancels, or resettles an order.
- The request section below only describes the request before encoding. All request must be encoded and sent in the request sample section.
- For the action type PLACED, if we receive a response with the success field set to false, we will send you a callback with the action type CANCELLED to indicate that the bet must be cancelled because it was not accepted.
- For the other action type (ACCEPTED, CANCELLED, SETTLED, CASHED_OUT, RESETTLED), if we receive a response with the success field set to false, we will continue to resend the callback to you up to 5 times, with each attempt spaced 1 minute apart.

#### Action: PLACED
- This action type is sent when player places an order.
- You must deduct the toRisk amount from the player's balance.

Callback request body:
Refer to the TransactionCallBackRequest section for an explanation.

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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": null,
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
        "liveScore": null,
        "legStatus": "PENDING_ACCEPTANCE"
      }
    ]
  }
}
```

#### Action: ACCEPTED
- This action type sent when the order has been accepted.
- You don't need to adjust the player's balance.
- When you receive the action: ACCEPTED, some of the following fields (odds, toWin) will have their values changed if the order is accepted with better odds. Other fields remain unchanged compared to when you received the PLACED request. Example for better odds case: Placing the order with toRisk: 100 USD, odds: 1.5 (Decimal), toWin: 15 USD, after that this order matched with better odds 1.6 (Decimal) so toRisk: 100 USD, odds: 1.6 (Decimal), toWin: 16 USD.

Callback request body:
Refer to the TransactionCallBackRequest section for an explanation.

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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": null,
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
        "liveScore": null,
        "legStatus": "ACCEPTED"
      }
    ]
  }
}
```

#### Action: CANCELLED
- This action type is sent when the order has been cancelled. You must add toRisk amount to the player's balance.

Callback request body:
Refer to the TransactionCallBackRequest section for an explanation.

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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": null,
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
        "liveScore": null,
        "legStatus": "CANCELLED"
      }
    ]
  }
}
```

#### Action: SETTLED
- This action type is sent when the order is settled. You must add the profit and loss (pnl) to the player's balance.

Callback request body:
Refer to the TransactionCallBackRequest section for an explanation.

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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
        "liveScore": null,
        "legStatus": "WON"
      }
    ]
  }
}
```

Different settlement statuses:

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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": 0.25,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "Match Handicap",
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
        "sportName": "Soccer",
        "betType": "SPREAD",
        "handicap": 0.25,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "Match Handicap",
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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
        "liveScore": null,
        "legStatus": "LOST"
      }
    ]
  }
}
```

#### Action: CASHED_OUT
- This status is sent when the player chooses to cash out the order, and it settles early before the match has final result. You must add the profit and loss (pnl) to the player's balance.

Callback request body:
Refer to the TransactionCallBackRequest section for an explanation.

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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
        "liveScore": null,
        "legStatus": "CASHED_OUT"
      }
    ]
  }
}
```

#### Action: RESETTLED
- When you receive the action RESETTLED, you must recalculate the change in pnl to update the player's balance.
- For the action RESETTLED, in some cases, you may receive multiple callbacks for the same orderId. In such cases, you must recalculate the adjusted pnl based on the most recent SETTLED or RESETTLED event you received, following the instructions below.
- For example, initially the player's balance is 1000. The player places an order. You receive a callback with the action PLACED with odds 1.5 (Decimal), toRisk: 100, toWin: 50. You deduct 100 toRisk from the player's balance. At this point, the player's balance is 900. Then you receive a callback action: SETTLED pnl: 150. You need to save this pnl (1). You add 150 to the player's balance. At this point, the player's balance is 1050. Then you receive a callback RESETTLED with pnl: 75 (2). You calculate the difference in pnl by taking (2) - (1) = 75 - 150 = -75. Then you add the pnl difference to the player's balance: 1050 - 75 = 975.

Callback request body:
Refer to the TransactionCallBackRequest section for an explanation.

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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
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
        "sportName": "Soccer",
        "betType": "MONEYLINE",
        "handicap": null,
        "leagueId": 2636,
        "leagueName": "UEFA - Super Cup",
        "eventId": 1592591618,
        "eventName": "Real Madrid vs Atalanta",
        "oddsFormat": "DECIMAL",
        "odds": 1.5230000,
        "eventStartDate": "2024-08-14T15:00:00-04:00",
        "live": false,
        "settledDate": "2024-06-13T00:03:58-04:00",
        "selection": "Real Madrid",
        "homeTeam": "Real Madrid",
        "awayTeam": "Atalanta",
        "countryId": 78729646,
        "countryName": "Europe",
        "marketId": 3696453,
        "marketName": "1X2 Match",
        "liveScore": null,
        "legStatus": "WON"
      }
    ]
  }
}
```

#### Response
Response body:
Refer to the TransactionCallBackResponse section for an explanation.

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

## API Request

### [A001] Login API

#### Overview
- POST: {{ our_api_domain }}/api/v1/login
- This API is used to retrieve the login URL for the SPORTS38 lobby.
- The request section below only describes the request before encoding. All request must be encoded and sent in the request sample section.

#### Request
Refer to the LoginRequest section for an explanation.

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

#### Response

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
  "message": "Invalid partner key",
  "data": "{}",
  "success": false
}
```

```json
{
  "errorCode": "INVALID_PLAYER_SETTING",
  "message": "Invalid player setting",
  "data": "{}",
  "success": false
}
```

### [A002] Logout API

#### Overview
- POST: {{ our_api_domain }}/api/v1/logout
- This API is used to expired the session of the currently login-in player.
- The request section below only describes the request before encoding. All request must be encoded and sent in the request sample section.

#### Request

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

#### Response

```json
{
  "errorCode": "",
  "message": "",
  "data": "{}",
  "success": true
}
```

### [A003] Get orders by IDs

#### Overview
- POST: {{ our_api_domain }}/api/v1/bets
- This API allows sending multiple order IDs to retrieve orders information.
- The request section below only describes the request before encoding. All request must be encoded and sent in the request sample section.
- The maximum number of order IDs per request is 100.

#### Request
Request Body:
```json
[10004616,10004617,10004618]
```

Example Curl:
```bash
curl '{{domain}}/api/v1/bets' \
  --header 'x-partner-key: partner_demo' \
  --header 'Content-Type: application/json' \
  --data '{"data": "FdIhq29ltAovaxF6wwJznQWklAu+Z3yKBTCTtHzkzLSVmdA7X+BNM4U7blB3PlgU"}'
```

#### Response
Refer to the ListOrdersResponse section for an explanation.

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
            "sportName": "Soccer",
            "betType": "MONEYLINE",
            "handicap": null,
            "leagueId": 2102,
            "leagueName": "Iceland - Premier League",
            "eventId": 1592092637,
            "eventName": "Valur Reykjavik vs Stjarnan",
            "oddsFormat": "DECIMAL",
            "odds": 1.859,
            "eventStartDate": "2024-05-30T14:00:00-04:00",
            "live": false,
            "settledDate": null,
            "selection": "Valur Reykjavik",
            "homeTeam": "Valur Reykjavik",
            "awayTeam": "Stjarnan",
            "countryId": 78729586,
            "countryName": "Iceland",
            "marketId": 3570283,
            "marketName": "1X2 Match",
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

### [A004] Get orders by time range

#### Overview
- POST: {{ our_api_domain }}/api/v1/bets/period
- This API is used to get orders based on the placement time. Start date can be up to 30 days in the past.
- The request section below only describes the request before encoding. All request must be encoded and sent in the request sample section.

#### Request
Request body:
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

Refer to the OrderByTimeRangeRequest section for an explanation.

Example Curl:
```bash
curl '{{domain}}/api/v1/bets/period' \
  --header 'x-partner-key: partner_demo' \
  --header 'Content-Type: application/json' \
  --data '{"data":"JpK64ZaMN5azl+VnVJ1+8NBXHiCG9BQGn3n1WXXIOSuzTQ6/74naNObVVwhyO4bAaqeakSHy8Nvty2lS1ETEKIL2vcct0+o2EpQLSHzvnLBiAPfSktANN1oSjMbB+tA/FN8ZLg3bIbmtGF8prup/hQu1U9N+jq/UFd8En5LVSNYfcOb8tHTC04c3jJHsOuXRya+3OP13I8HbnSda0WToR6cw+buIy4mIEioD4mcgM/PIYRIKLiRcmi5X6oJ9tykQ"}'
```

#### Response
Refer to the ListOrderResponse section for an explanation.

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

## Model Explain

### LoginRequest
The model used in [A001]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| locale | String | Refer to section LOCALE SUPPORT. default: en-US |
| currencyCode | String | (required*) Refer to section CURRENCY SUPPORT. |
| device | ENUM | - MOBILE - DESKTOP default: DESKTOP |
| playerId | String | (required*) Up to 45 characters, including letters, numbers, and special characters. |
| theme | String | This value only available upon partner request. |
| view | ENUM | - ASIAN - EURO default: ASIAN |
| timeZone | String | default: +00:00 |

### LoginResponse
The model used in [A001]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| url | String | The url allows player to access the main page of Sports38 |

### TransactionCallBackRequest
The model used in [CB002]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| action | String | Indicate the type of this callback. |
| order | Order | Order information. |
| transaction | String | The value of this field is converted from the order field to a JSON string. Since the version 1.0.4, this field has been deprecated. Please switch to using the order field. |

### TransactionCallBackResponse
The model used in [CB002]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| orderId | Long | Order identification. You return the orderId value that we sent to you in order.orderId. |
| positionTaken | Decimal | This value is only required for the action type PLACED, and when partner requests this feature. The value range is depended on the business agreement. Indicate how much position taking you want to take on this order. 0 is 0 percentage, 1 is 100 percentages. |
| adjustedBalance | Money | Used to track the amount value that you changed in the player's balance after we callback to you. -10 mean 10 dollars has been deducted successfully from player's wallet. |

### Order
The model used in [CB002], [A003], [A004]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| orderType | ENUM | - STRAIGHT - SPECIAL - PARLAY Parlay order has more than 1 leg. Straight and special orders have 1 leg. |
| oddsFormat | ENUM | - AMERICAN - DECIMAL - HONGKONG - MALAY - INDONESIAN INDONESIAN odds only support players with the currency IDR. When a player places a bet on a market type of MONEYLINE and selects odds formats such as HONGKONG, MALAY, or INDONESIAN, the odds format will always be DECIMAL. This is because MONEYLINE only supports DECIMAL and AMERICAN odds formats. |
| status | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - CASHED_OUT - SETTLED Order's status. |
| orderId | Long | Order identification. |
| stake | Money | The amount of money the player inputs. |
| toWin | Money | The maximum amount that order can win. |
| legs | List<Leg> | |
| placedDate | DateTime | Order placed date. |
| totalOdds | Odds | - STRAIGHT: totalOdds is the same as the leg odds. - SPECIAL: totalOdds is the same as the leg odds. - PARLAY: totalOdds is the parlay odds calculated based on all legs' odds. If the selected odds are in Decimal format totalOdds = odds 1 * odds 2 * ... * odds n. For example, if a player selects odds 1 as 1.892 (Decimal) and odds 2 as 2.070 (Decimal), the odds of the parlay bet = 1.892 * 2.070 = 3.916 (Decimal). If the selected odds are not in Decimal format, totalOdds = (odds 1 converted to Decimal * odds 2 converted to Decimal * ... * odds n converted to Decimal), then convert from Decimal to the selected odds type. For example, if a player selects odds 1 as 0.892 (HongKong) and odds 2 as 1.070 (HongKong), the odds of the parlay bet = 1.892 (converted to Decimal) * 2.070 (converted to Decimal) = 3.916 (Decimal) = 2.916 (HongKong). Selected odds are the odds chosen by the user at the time of placing the bet. |
| playerId | String | Player identification. |
| toRisk | Money | The maximum amount that order can lose. |
| pnl | Money | The win/loss amount of the order include toRisk. For example, if a player bets with toRisk 100 and wins 50, the pnl (Profit and Loss) is 150. |
| odds | Odds | The betting odds of the order. |
| settledStatus | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - WON - LOST - HALF_WON_HALF_PUSHED - HALF_LOST_HALF_PUSHED - REFUNDED - CASHED_OUT WON: The order is settled as WON. HALF_WON_HALF_PUSH: The order is settled as half won half pushed. Only for Asian handicap. HALF_LOST_HALF_PUSH: The order is settled as half lost half pushed. Only for Asian handicap. LOST: The order is settled as lose. REFUNDED: When an event is cancelled or when the order is settled as push. CASHED_OUT: Cash out allow player to sell their bets before the official result of the match is determined. |
| settledAt | DateTime | Order's settlement date. It will be null when the order not settled yet. |

### Leg
The model used in [CB002], [A003], [A004]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| sportId | Long | Sport identification. |
| sportName | String | Sport's name. |
| betType | String | The value determines the type of bet. For example, when a player bets on the market 1x2, the betType will be MONEYLINE, and for Asian handicap, it will be SPREAD. |
| handicap | Decimal | The handicap will be null when the leg does not support handicap, for example, in a MONEYLINE (1x2) leg. |
| leagueId | Long | League identification. |
| leagueName | String | League's name. |
| eventId | Long | Event identification. |
| eventName | String | Event's name. |
| oddsFormat | ENUM | - AMERICAN - DECIMAL - HONGKONG - MALAY - INDONESIAN INDONESIAN odds only support players with the currency IDR. When a player places a bet on a market type of MONEYLINE and selects odds formats such as HONGKONG, MALAY, or INDONESIAN, the odds format will always be DECIMAL. This is because MONEYLINE only supports DECIMAL and AMERICAN odds formats. |
| odds | Odds | The betting odds of the leg. |
| eventStartDate | DateTime | Event start date |
| live | Boolean | The value determines whether the match is live or pre-game. |
| settledDate | DateTime | Leg's settlement date. It will bet null when the leg not settled yet. |
| selection | String | The player's choice. |
| homeTeam | String | Home team's name |
| awayTeam | String | Away team's name |
| countryId | Long | Country identification. |
| countryName | String | Country's name. |
| marketId | Long | Market identification. |
| marketName | String | Market's name. |
| liveScore | String | This value is only supported when the field "live" is true; otherwise, it will be null. This field only support for sportId 29, sportName Soccer. Example: 1-1 |
| legStatus | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - WON - LOST - HALF_WON_HALF_PUSHED - HALF_LOST_HALF_PUSHED - REFUNDED - CASHED_OUT Leg's status |
| legId | UUID | An order with two or more legs is called a parlay order. |

### OrdersByTimeRangeRequest
The model used in [A004]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| playerId | String | (required*) Player identification. |
| offset | Long | Start from 0. Starting record of the result. Default value is 0. |
| limit | Long | Max is 1000. Default value is 100. |
| fromDate | DateTime | (required*) Start date of the request period. Start date can be up to 30 days in the past. The expected format is ISO8601. This field will filter order base on the placement date. |
| toDate | DateTime | (required*) End date of the request period. Expected format is ISO8601. This field will filter order base on the placement date. |
| orderStatus | ENUM | - PENDING_ACCEPTANCE - ACCEPTED - CANCELLED - CASHED_OUT - SETTLED Type of order statues to return. It is an additional filter. If empty, it will return all current statuses. |

### ListOrdersResponse
The model used in [A003], [A004]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| orders | List<Order> | |
| totalRecord | Long | Total records. |

### PlayerSettingResponse
The model used in [CB001]

| Field Name | Data Type | Description |
|------------|-----------|-------------|
| playerId | String | Player identification. |
| oddsGroup | ENUM | - A - B - C - D - E Odds group just control how attractive the odds is. A type will give player the best odds, E will give player the worst odds. |

## Common Data Format

All api support JSON format only.

| Data Type | Description |
|-----------|-------------|
| DateTime | All date follows the format: yyyy-MM-dd'T'HH:mm:ssXXX (ISO8601). E.g: 2024-06-03T11:30:00-04:00 |
| Money | All monetary amounts are displayed 7 decimal places. Sample 12.0511234. |
| Boolean | Boolean logic value. |
| String | String value. |
| Long | Long value. |
| Integer | Integer value. |
| Decimal | Decimal value. There is a 2-digit decimal number. |
| Odds | Decimal value. There is a 3-digit decimal number. |

## Locale Support

| Key | Description |
|-----|-------------|
| en-US | English. |
| ko-KR | Korean. |

## Currency Support

> **Note**: The Indonesian odds format is only supported when the player's currency is IDR.

| Currency Code | Currency Name | Unit |
|---------------|---------------|------|
| AED | United Arab Emirates Dirham | 1 |
| AMD | Armenian Dram | 1 |
| ARS | Argentina Pesos | 1 |
| AUD | Australia Dollars | 1 |
| AZN | Azerbaijan New Manat | 1 |
| BDT | Bangladeshi Taka | 1 |
| BGN | Bulgaria Lev | 1 |
| BRL | Brazilian Real | 1 |
| CAD | Canada Dollars | 1 |
| CLP | Chilean Peso | 1 |
| CNY | China Yuan Renmimbi | 1 |
| COP | Colombian Peso | 1 |
| CRC | Costa Rican Colon | 1 |
| CSK | Czech Republic Koruna | 1 |
| DKK | Denmark Kroner | 1 |
| ETB | Ethiopian Birr | 1 |
| EUR | Euro | 1 |
| GBP | United Kingdom Pounds | 1 |
| GEL | Georgian Lari | 1 |
| GSH | Ghanaian Cedi | 1 |
| HKD | Hong Kong Dollars | 1 |
| IDR | Indonesia Rupiah | 1000 |
| ILS | Israeli New Shekel | 1 |
| INR | Indian Rupee | 1 |
| JIN | JIN Coin Crypto Currency | 1 |
| JPY | Japan Yen | 1 |
| KES | Kenya Shilling | 1 |
| KGS | Kyrgyzstani som | 1 |
| KHR | Cambodia Riel | 1000 |
| KRW | South Korean Won | 1 |
| KZT | Kazakhstani Tenge | 1 |
| LAK | Lao KIP | 1000 |
| MBT | milliBitcoin | 1 |
| MDL | Moldovan Leu | 1 |
| MGA | Malagasy ariary | 1000 |
| MMK | Myanmar Kyat | 1000 |
| MXP | Mexico Pesos | 1 |
| MYR | Malaysia Ringgit | 1 |
| NGN | Nigerian Naira | 1 |
| NOK | Norway Kroner | 1 |
| NPR | Nepalese Rupee | 1 |
| NZD | New Zealand Dollars | 1 |
| PEN | Peruvian Soles | 1 |
| PHP | Philippines Pesos | 1 |
| PKR | Pakistan Rupee | 1 |
| PLZ | Poland Zloty | 1 |
| RON | Romanian Leu | 1 |
| RUB | Russian Rouble | 1 |
| SEK | Sweden Krona | 1 |
| SGD | Singapore Dollars | 1 |
| SSP | South Sudanese Pound | 1 |
| THB | Thailand Baht | 1 |
| TJS | Tajikistani Somoni | 1 |
| TRY | Turkish Lira | 1 |
| TWD | Taiwan Dollars | 1 |
| UAH | Ukrainian Hryvnia | 1 |
| UDC | USDC Crypto Currency | 1 |
| UDT | USDT Crypto Currency | 1 |
| UGX | Ugandan Shilling | 1000 |
| USD | United States Dollars | 1 |
| UYU | Uruguayan Peso | 1 |
| UZS | Uzbekistani Som | 1 |
| VES | Venezuelan Bolivar | 1 |
| VND | Vietnam Dong | 1000 |
| VP | Virtual Point | 1 |
| YEN | Japanese Yen | 1 |
| ZAR | South African Rand | 1 |