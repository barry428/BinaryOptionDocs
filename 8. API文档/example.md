ℹ️  测试概述 (含Fixture集成):
ℹ️  1. OAuth认证 → 2. 领取DEMO资金 → 3. 获取当前轮次 → 4. DEMO下单(3个) → 5. BTSE转入 → 6. REAL下单(3个) → 7. BTSE转出 → 8. 轮次查询 → 9. 轮次结算 → 10. 历史订单查询


🔹 步骤1: 生成OAuth Mock数据
ℹ️  用户名: testuser_1755848172
ℹ️  Mock用户ID: 22624 (BTSE的Mock ID)
ℹ️  Token: oauth_token_1755848172
ℹ️  将OAuth token写入Redis (cluster)...
ℹ️  JSON大小:     1992 ->     1521 字节 (压缩后)
✅ ✅ OAuth Mock数据已写入Redis (cluster)
./simple-flow-test-oauth.sh: line 104: redis_cluster_ttl: command not found
ℹ️  Token过期时间: 秒

🔹 步骤2: 测试OAuth认证流程
ℹ️  使用OAuth token进行第一次请求（将触发自动注册）...
用户信息响应: {"code":200,"message":"success","data":{"userId":"211","externalId":"testuser_1755848172","nickname":"testuser_1755848172","email":"testuser_1755848172@oauth.auto","status":1,"riskAgreement":1,"amlAgreement":1,"createTime":1755848172573,"updateTime":1755848172573},"success":true,"error":false}
✅ ✅ OAuth认证成功，真实用户ID: 211
ℹ️  用户自动注册并关联到: testuser_1755848172

🔹 步骤3: 检查用户账户 (通过API)
✅ ✅ DEMO账户 | 余额: 0E-16 | 冻结: 0E-16
✅ ✅ REAL账户 | 余额: 0E-16 | 冻结: 0E-16

🔹 步骤4: 领取DEMO资金
领取响应: {"code":200,"message":"success","data":true,"success":true,"error":false}
✅ ✅ DEMO资金领取成功
ℹ️  DEMO账户余额: 10000.0000000000000000

🔹 步骤5: 获取当前交易轮次
当前轮次响应: {"code":200,"message":"success","data":{"symbolId":"1","symbol":"BTCUSDT","rounds":[{"symbolId":"1","durationMinutes":5,"roundNo":"S1_D5_202508221535","openTime":1755848100000,"closeTime":1755848400000,"lockTime":1755848370000,"status":"OPEN","upAmount":0,"downAmount":0,"createTime":1755848173015,"updateTime":1755848173015,"roundId":"359","startPrice":57480.82},{"symbolId":"1","durationMinutes":10,"roundNo":"S1_D10_202508221530","openTime":1755847800000,"closeTime":1755848400000,"lockTime":1755848370000,"status":"OPEN","upAmount":0,"downAmount":0,"createTime":1755848173015,"updateTime":1755848173015,"roundId":"360"},{"symbolId":"1","durationMinutes":15,"roundNo":"S1_D15_202508221530","openTime":1755847800000,"closeTime":1755848700000,"lockTime":1755848670000,"status":"OPEN","upAmount":0,"downAmount":0,"createTime":1755848173015,"updateTime":1755848173015,"roundId":"361","startPrice":51311.56}]},"success":true,"error":false}
✅ ✅ 获取5分钟轮次成功
ℹ️  轮次ID: 359
ℹ️  轮次编号: S1_D5_202508221535
ℹ️  轮次状态: OPEN
ℹ️  持续时间: 5 分钟
ℹ️  UP投注额: 0
ℹ️  DOWN投注额: 0
ℹ️  开盘时间: 1755848100000
ℹ️  收盘时间: 1755848400000
5分钟轮次详细信息:
{
  "symbolId": "1",
  "durationMinutes": 5,
  "roundNo": "S1_D5_202508221535",
  "openTime": 1755848100000,
  "closeTime": 1755848400000,
  "lockTime": 1755848370000,
  "status": "OPEN",
  "upAmount": 0,
  "downAmount": 0,
  "createTime": 1755848173015,
  "updateTime": 1755848173015,
  "roundId": "359",
  "startPrice": 57480.82
}
----------------------------------------
所有轮次详细信息:
{
  "code": 200,
  "message": "success",
  "data": {
    "symbolId": "1",
    "symbol": "BTCUSDT",
    "rounds": [
      {
        "symbolId": "1",
        "durationMinutes": 5,
        "roundNo": "S1_D5_202508221535",
        "openTime": 1755848100000,
        "closeTime": 1755848400000,
        "lockTime": 1755848370000,
        "status": "OPEN",
        "upAmount": 0,
        "downAmount": 0,
        "createTime": 1755848173015,
        "updateTime": 1755848173015,
        "roundId": "359",
        "startPrice": 57480.82
      },
      {
        "symbolId": "1",
        "durationMinutes": 10,
        "roundNo": "S1_D10_202508221530",
        "openTime": 1755847800000,
        "closeTime": 1755848400000,
        "lockTime": 1755848370000,
        "status": "OPEN",
        "upAmount": 0,
        "downAmount": 0,
        "createTime": 1755848173015,
        "updateTime": 1755848173015,
        "roundId": "360"
      },
      {
        "symbolId": "1",
        "durationMinutes": 15,
        "roundNo": "S1_D15_202508221530",
        "openTime": 1755847800000,
        "closeTime": 1755848700000,
        "lockTime": 1755848670000,
        "status": "OPEN",
        "upAmount": 0,
        "downAmount": 0,
        "createTime": 1755848173015,
        "updateTime": 1755848173015,
        "roundId": "361",
        "startPrice": 51311.56
      }
    ]
  },
  "success": true,
  "error": false
}
----------------------------------------

🔹 步骤6: DEMO下单 (3个订单)
ℹ️  订单金额: 10.00 (每个)
ℹ️  目标轮次: 359
ℹ️  创建第1个DEMO订单...
DEMO订单1响应: {"code":200,"message":"success","data":{"orderId":"277","userId":"211","accountType":"DEMO","symbolId":"1","roundId":"359","roundNo":"S1_D5_202508221535","direction":"UP","amount":10.00,"odds":1.72,"expectedProfit":7.20,"orderPrice":55652.78,"status":"ACTIVE","fee":0,"createTime":1755848175186,"updateTime":1755848175199},"success":true,"error":false}
✅ ✅ DEMO订单1创建成功，ID: 277 (方向: UP)
ℹ️  创建第2个DEMO订单...
DEMO订单2响应: {"code":200,"message":"success","data":{"orderId":"278","userId":"211","accountType":"DEMO","symbolId":"1","roundId":"359","roundNo":"S1_D5_202508221535","direction":"DOWN","amount":10.00,"odds":1.68,"expectedProfit":6.80,"orderPrice":59548.59,"status":"ACTIVE","fee":0,"createTime":1755848175953,"updateTime":1755848175961},"success":true,"error":false}
✅ ✅ DEMO订单2创建成功，ID: 278 (方向: DOWN)
ℹ️  创建第3个DEMO订单...
DEMO订单3响应: {"code":200,"message":"success","data":{"orderId":"279","userId":"211","accountType":"DEMO","symbolId":"1","roundId":"359","roundNo":"S1_D5_202508221535","direction":"UP","amount":10.00,"odds":1.69,"expectedProfit":6.90,"orderPrice":53306.43,"status":"ACTIVE","fee":0,"createTime":1755848177185,"updateTime":1755848177204},"success":true,"error":false}
✅ ✅ DEMO订单3创建成功，ID: 279 (方向: UP)
ℹ️  DEMO订单创建完成，共3个订单: 277 278 279

🔹 步骤7: BTSE转入测试
ℹ️  转入金额: 20.00
BTSE转入响应: {"code":200,"message":"success","data":{"transferId":"mock_transfer_18f5e109-47ad-4308-a7ed-47e96d7920b1","status":"SUCCESS","amount":20.00,"direction":"FROM_BTSE","createTime":1755848179419,"message":"充值成功"},"success":true,"error":false}
✅ ✅ BTSE转入成功，转账ID: mock_transfer_18f5e109-47ad-4308-a7ed-47e96d7920b1
ℹ️  REAL账户转入后余额: 20.0000000000000000

🔹 步骤8: REAL下单测试 (3个订单)
ℹ️  订单金额: 5.00 (每个)
ℹ️  创建第1个REAL订单...
REAL订单1响应: {"code":200,"message":"success","data":{"orderId":"280","userId":"211","accountType":"REAL","symbolId":"1","roundId":"359","roundNo":"S1_D5_202508221535","direction":"DOWN","amount":5.00,"odds":1.81,"expectedProfit":4.05,"orderPrice":52088.97,"status":"ACTIVE","fee":0,"createTime":1755848179794,"updateTime":1755848182889},"success":true,"error":false}
✅ ✅ REAL订单1创建成功，ID: 280 (方向: DOWN)
ℹ️  💡 使用本地账户余额下单成功
ℹ️  创建第2个REAL订单...
REAL订单2响应: {"code":200,"message":"success","data":{"orderId":"281","userId":"211","accountType":"REAL","symbolId":"1","roundId":"359","roundNo":"S1_D5_202508221535","direction":"UP","amount":5.00,"odds":1.74,"expectedProfit":3.70,"orderPrice":50359.79,"status":"ACTIVE","fee":0,"createTime":1755848184589,"updateTime":1755848185687},"success":true,"error":false}
✅ ✅ REAL订单2创建成功，ID: 281 (方向: UP)
ℹ️  💡 使用本地账户余额下单成功
ℹ️  创建第3个REAL订单...
REAL订单3响应: {"code":200,"message":"success","data":{"orderId":"282","userId":"211","accountType":"REAL","symbolId":"1","roundId":"359","roundNo":"S1_D5_202508221535","direction":"DOWN","amount":5.00,"odds":1.68,"expectedProfit":3.40,"orderPrice":58046.32,"status":"ACTIVE","fee":0,"createTime":1755848187341,"updateTime":1755848188642},"success":true,"error":false}
✅ ✅ REAL订单3创建成功，ID: 282 (方向: DOWN)
ℹ️  💡 使用本地账户余额下单成功
ℹ️  REAL订单创建完成，共3个订单: 280 281 282

🔹 步骤9: BTSE转出测试
ℹ️  当前 REAL账户余额: 20.0000000000000000
ℹ️  转出金额（全部余额）: 20.00
BTSE转出响应: {"code":200,"message":"success","data":{"transferId":"mock_transfer_56dfc45f-1eb3-4714-8869-4c7f25972830","status":"SUCCESS","amount":20.00,"direction":"TO_BTSE","createTime":1755848190385,"message":"提现成功"},"success":true,"error":false}
✅ ✅ BTSE转出成功，转账ID: mock_transfer_56dfc45f-1eb3-4714-8869-4c7f25972830
ℹ️  REAL账户转出后余额: 0E-16

🔹 步骤10: 查询转账历史
✅ ✅ 获取转账历史成功，共 9 条记录
ℹ️  转账历史记录:
BTSE_OUT | 0E-16 | TO_BTSE | 1755848190380
FREEZE_OUT | -20.0000000000000000 | null | 1755848189761
FREEZE_OUT | -5.0000000000000000 | null | 1755848188637
BTSE_IN | 5.0000000000000000 | FROM_BTSE | 1755848188624
FREEZE_OUT | -5.0000000000000000 | null | 1755848185682

🔹 步骤11: 检查BTSE转账日志 (通过API)
ℹ️  ℹ️  通过API查询用户的BTSE转账日志 (最近10条记录)
✅ ✅ 获取BTSE转账日志成功，共 5 条记录
ℹ️  BTSE转账日志记录:
ID | 用户ID | 方向 | 金额 | 状态 | 转账ID | 创建时间
==================================================================
501 | 211 | IN | 20.0000000000000000 | SUCCESS | mock_transfer_18f5e109-47ad-4308-a7ed-47e96d7920b1 | 1755848178609
502 | 211 | IN | 5.0000000000000000 | SUCCESS | mock_transfer_4711a922-a40c-45de-962c-742fc1f08b7d | 1755848180703
503 | 211 | IN | 5.0000000000000000 | SUCCESS | mock_transfer_3ef9f5d6-011e-436a-bbfa-3576f68fde9e | 1755848185124
504 | 211 | IN | 5.0000000000000000 | SUCCESS | mock_transfer_cbcff0d5-16a3-4f13-a2cb-be3a7b484c72 | 1755848187826
505 | 211 | OUT | 20.0000000000000000 | SUCCESS | mock_transfer_56dfc45f-1eb3-4714-8869-4c7f25972830 | 1755848189759

=========================================
测试结果总结
=========================================
用户信息:
  用户名: testuser_1755848172
  Mock用户ID: 22624 (BTSE Mock ID)
  真实用户ID: 211 (数据库ID)
  Token已保存到: data/last_token.json

订单信息:
  DEMO订单IDs: 277 278 279
  REAL订单IDs: 280 281 282

ℹ️  最终账户状态 (通过API):
类型 | 余额 | 冻结
DEMO | 9970.0000000000000000 | 30.0000000000000000
REAL | 0E-16 | 15.0000000000000000
ℹ️  ℹ️  注意：由于现在所有订单操作都是本地数据库事务，不再需要PENDING订单补偿机制

🔹 步骤12: 检查最终订单状态
ℹ️  检查所有DEMO订单最终状态...
ℹ️  检查所有REAL订单最终状态...

🔹 步骤13: 按轮次ID查询订单
ℹ️  使用轮次ID: 359
ℹ️  查询DEMO账户在轮次 359 的订单...
DEMO轮次 359 订单查询结果:
{
  "code": 200,
  "message": "success",
  "data": {
    "roundInfo": {
      "roundId": "359",
      "roundNo": "S1_D5_202508221535",
      "symbolId": "1",
      "symbol": "BTCUSDT",
      "durationMinutes": 5,
      "startPrice": 57480.8200000000000000,
      "openTime": 1755848100000,
      "closeTime": 1755848400000,
      "settleTime": 1755848186717,
      "roundStatus": "OPEN"
    },
    "userSummary": {
      "totalOrders": 3,
      "totalAmount": 30.0000000000000000,
      "totalProfit": 0,
      "totalLoss": 0,
      "netProfit": 0
    },
    "orders": [
      {
        "orderId": "279",
        "userId": "211",
        "accountType": "DEMO",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "UP",
        "amount": 10.0000000000000000,
        "odds": 1.6900,
        "expectedProfit": 6.9000000000000000,
        "orderPrice": 53306.4300000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848176525,
        "updateTime": 1755848176525
      },
      {
        "orderId": "278",
        "userId": "211",
        "accountType": "DEMO",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "DOWN",
        "amount": 10.0000000000000000,
        "odds": 1.6800,
        "expectedProfit": 6.8000000000000000,
        "orderPrice": 59548.5900000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848175796,
        "updateTime": 1755848175796
      },
      {
        "orderId": "277",
        "userId": "211",
        "accountType": "DEMO",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "UP",
        "amount": 10.0000000000000000,
        "odds": 1.7200,
        "expectedProfit": 7.2000000000000000,
        "orderPrice": 55652.7800000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848174949,
        "updateTime": 1755848174949
      }
    ]
  },
  "success": true,
  "error": false
}
----------------------------------------
✅ ✅ DEMO轮次 359: 3 个订单
ℹ️  DEMO用户汇总: {
  "totalOrders": 3,
  "totalAmount": 30.0000000000000000,
  "totalProfit": 0,
  "totalLoss": 0,
  "netProfit": 0
}
ℹ️  查询REAL账户在轮次 359 的订单...
REAL轮次 359 订单查询结果:
{
  "code": 200,
  "message": "success",
  "data": {
    "roundInfo": {
      "roundId": "359",
      "roundNo": "S1_D5_202508221535",
      "symbolId": "1",
      "symbol": "BTCUSDT",
      "durationMinutes": 5,
      "startPrice": 57480.8200000000000000,
      "openTime": 1755848100000,
      "closeTime": 1755848400000,
      "settleTime": 1755848186717,
      "roundStatus": "OPEN"
    },
    "userSummary": {
      "totalOrders": 3,
      "totalAmount": 15.0000000000000000,
      "totalProfit": 0,
      "totalLoss": 0,
      "netProfit": 0
    },
    "orders": [
      {
        "orderId": "282",
        "userId": "211",
        "accountType": "REAL",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "DOWN",
        "amount": 5.0000000000000000,
        "odds": 1.6800,
        "expectedProfit": 3.4000000000000000,
        "orderPrice": 58046.3200000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848186717,
        "updateTime": 1755848186717
      },
      {
        "orderId": "281",
        "userId": "211",
        "accountType": "REAL",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "UP",
        "amount": 5.0000000000000000,
        "odds": 1.7400,
        "expectedProfit": 3.7000000000000000,
        "orderPrice": 50359.7900000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848183957,
        "updateTime": 1755848183957
      },
      {
        "orderId": "280",
        "userId": "211",
        "accountType": "REAL",
        "symbolId": "1",
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "direction": "DOWN",
        "amount": 5.0000000000000000,
        "odds": 1.8100,
        "expectedProfit": 4.0500000000000000,
        "orderPrice": 52088.9700000000000000,
        "status": "ACTIVE",
        "fee": 0E-16,
        "createTime": 1755848179499,
        "updateTime": 1755848179499
      }
    ]
  },
  "success": true,
  "error": false
}
----------------------------------------
✅ ✅ REAL轮次 359: 3 个订单
ℹ️  REAL用户汇总: {
  "totalOrders": 3,
  "totalAmount": 15.0000000000000000,
  "totalProfit": 0,
  "totalLoss": 0,
  "netProfit": 0
}

🔹 步骤14: 用户BTSE转账日志验证 (通过API)
ℹ️  ℹ️  再次检查用户的BTSE转账日志 (验证所有操作的完整性)
✅ ✅ 最终BTSE转账日志统计：共 5 条记录
ℹ️  详细BTSE转账记录:
ID | 用户ID | 方向 | 金额 | 状态 | 时间
=================================================
501 | 211 | IN | 20.0000000000000000 | SUCCESS | 1755848178609
502 | 211 | IN | 5.0000000000000000 | SUCCESS | 1755848180703
503 | 211 | IN | 5.0000000000000000 | SUCCESS | 1755848185124
504 | 211 | IN | 5.0000000000000000 | SUCCESS | 1755848187826
505 | 211 | OUT | 20.0000000000000000 | SUCCESS | 1755848189759
ℹ️  状态统计: 成功        5 条 | 失败        0 条 | 待处理        0 条

🔹 步骤15: 轮次结算
ℹ️  开始结算轮次: 359
轮次结算响应:
{
  "code": 200,
  "message": "success",
  "data": null,
  "success": true,
  "error": false
}
----------------------------------------
✅ ✅ 轮次 359 结算成功
ℹ️  📊 本轮次结算订单数: 0

🔹 步骤16: 查询历史订单（按轮次聚合）
ℹ️  查询DEMO账户历史订单（按轮次聚合）...
DEMO历史订单查询结果（按轮次聚合）:
{
  "code": 200,
  "message": "success",
  "data": {
    "records": [
      {
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "symbolId": "1",
        "symbol": "BTCUSDT",
        "durationMinutes": 5,
        "startPrice": 57480.8200000000000000,
        "endPrice": 52387.0200000000000000,
        "openTime": 1755848100000,
        "closeTime": 1755848400000,
        "settleTime": 1755848190740,
        "roundStatus": "SETTLED",
        "totalOrders": 6,
        "totalAmount": 45.0000000000000000,
        "totalProfit": 13.6100000000000000,
        "totalLoss": 25.0000000000000000,
        "netProfit": -11.3900000000000000,
        "orders": [
          {
            "orderId": "282",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 5.0000000000000000,
            "odds": 1.6800,
            "expectedProfit": 3.4000000000000000,
            "orderPrice": 58046.3200000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 3.3300000000000000,
            "fee": 0.0700000000000000,
            "settleTime": 1755848192711,
            "createTime": 1755848186717,
            "updateTime": 1755848190740
          },
          {
            "orderId": "281",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 5.0000000000000000,
            "odds": 1.7400,
            "expectedProfit": 3.7000000000000000,
            "orderPrice": 50359.7900000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 3.6200000000000000,
            "fee": 0.0800000000000000,
            "settleTime": 1755848191762,
            "createTime": 1755848183957,
            "updateTime": 1755848190740
          },
          {
            "orderId": "280",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 5.0000000000000000,
            "odds": 1.8100,
            "expectedProfit": 4.0500000000000000,
            "orderPrice": 52088.9700000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -5.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191755,
            "createTime": 1755848179499,
            "updateTime": 1755848190740
          },
          {
            "orderId": "279",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 10.0000000000000000,
            "odds": 1.6900,
            "expectedProfit": 6.9000000000000000,
            "orderPrice": 53306.4300000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -10.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191745,
            "createTime": 1755848176525,
            "updateTime": 1755848190740
          },
          {
            "orderId": "278",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 10.0000000000000000,
            "odds": 1.6800,
            "expectedProfit": 6.8000000000000000,
            "orderPrice": 59548.5900000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 6.6600000000000000,
            "fee": 0.1400000000000000,
            "settleTime": 1755848191734,
            "createTime": 1755848175796,
            "updateTime": 1755848190740
          },
          {
            "orderId": "277",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 10.0000000000000000,
            "odds": 1.7200,
            "expectedProfit": 7.2000000000000000,
            "orderPrice": 55652.7800000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -10.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191713,
            "createTime": 1755848174949,
            "updateTime": 1755848190740
          }
        ]
      }
    ],
    "total": "1",
    "page": 1,
    "size": 10,
    "pages": 1,
    "hasNext": false,
    "hasPrevious": false
  },
  "success": true,
  "error": false
}
----------------------------------------
✅ ✅ DEMO历史订单查询成功
ℹ️  📊 总轮次数: ��当前页轮次数: 1
ℹ️  DEMO轮次概览:
轮次ID: 359 | 轮次号: S1_D5_202508221535 | 订单数: 6 | 净盈亏: -11.3900000000000000
ℹ️  查询REAL账户历史订单（按轮次聚合）...
REAL历史订单查询结果（按轮次聚合）:
{
  "code": 200,
  "message": "success",
  "data": {
    "records": [
      {
        "roundId": "359",
        "roundNo": "S1_D5_202508221535",
        "symbolId": "1",
        "symbol": "BTCUSDT",
        "durationMinutes": 5,
        "startPrice": 57480.8200000000000000,
        "endPrice": 52387.0200000000000000,
        "openTime": 1755848100000,
        "closeTime": 1755848400000,
        "settleTime": 1755848190740,
        "roundStatus": "SETTLED",
        "totalOrders": 6,
        "totalAmount": 45.0000000000000000,
        "totalProfit": 13.6100000000000000,
        "totalLoss": 25.0000000000000000,
        "netProfit": -11.3900000000000000,
        "orders": [
          {
            "orderId": "282",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 5.0000000000000000,
            "odds": 1.6800,
            "expectedProfit": 3.4000000000000000,
            "orderPrice": 58046.3200000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 3.3300000000000000,
            "fee": 0.0700000000000000,
            "settleTime": 1755848192711,
            "createTime": 1755848186717,
            "updateTime": 1755848190740
          },
          {
            "orderId": "281",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 5.0000000000000000,
            "odds": 1.7400,
            "expectedProfit": 3.7000000000000000,
            "orderPrice": 50359.7900000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 3.6200000000000000,
            "fee": 0.0800000000000000,
            "settleTime": 1755848191762,
            "createTime": 1755848183957,
            "updateTime": 1755848190740
          },
          {
            "orderId": "280",
            "userId": "211",
            "accountType": "REAL",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 5.0000000000000000,
            "odds": 1.8100,
            "expectedProfit": 4.0500000000000000,
            "orderPrice": 52088.9700000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -5.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191755,
            "createTime": 1755848179499,
            "updateTime": 1755848190740
          },
          {
            "orderId": "279",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 10.0000000000000000,
            "odds": 1.6900,
            "expectedProfit": 6.9000000000000000,
            "orderPrice": 53306.4300000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -10.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191745,
            "createTime": 1755848176525,
            "updateTime": 1755848190740
          },
          {
            "orderId": "278",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "DOWN",
            "amount": 10.0000000000000000,
            "odds": 1.6800,
            "expectedProfit": 6.8000000000000000,
            "orderPrice": 59548.5900000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "WIN",
            "profit": 6.6600000000000000,
            "fee": 0.1400000000000000,
            "settleTime": 1755848191734,
            "createTime": 1755848175796,
            "updateTime": 1755848190740
          },
          {
            "orderId": "277",
            "userId": "211",
            "accountType": "DEMO",
            "symbolId": "1",
            "roundId": "359",
            "roundNo": "S1_D5_202508221535",
            "direction": "UP",
            "amount": 10.0000000000000000,
            "odds": 1.7200,
            "expectedProfit": 7.2000000000000000,
            "orderPrice": 55652.7800000000000000,
            "settlePrice": 52387.0200000000000000,
            "status": "LOSE",
            "profit": -10.0000000000000000,
            "fee": 0E-16,
            "settleTime": 1755848191713,
            "createTime": 1755848174949,
            "updateTime": 1755848190740
          }
        ]
      }
    ],
    "total": "1",
    "page": 1,
    "size": 10,
    "pages": 1,
    "hasNext": false,
    "hasPrevious": false
  },
  "success": true,
  "error": false
}
----------------------------------------
✅ ✅ REAL历史订单查询成功
ℹ️  📊 总轮次数: ��当前页轮次数: 1
ℹ️  REAL轮次概览:
轮次ID: 359 | 轮次号: S1_D5_202508221535 | 订单数: 6 | 净盈亏: -11.3900000000000000
✅ 🎉 OAuth Mock数据完整业务流程测试完成！

ℹ️  💡 测试完成项目 (OAuth方式)：
ℹ️  ✅ OAuth Mock数据生成和自动注册
ℹ️  ✅ OAuth认证流程 (Gateway验证token → Common-service解析用户)
ℹ️  ✅ 账户状态检查 (通过API获取余额和冻结金额)
ℹ️  ✅ DEMO资金领取 (通过API)
ℹ️  ✅ 当前轮次获取 (通过PublicOrderController.getCurrentTradingRound)
ℹ️  ✅ DEMO账户下单 (通过API，3个订单，balance → frozen_balance)
ℹ️  ✅ BTSE转入测试 (从 BTSE 转入到 REAL 账户)
ℹ️  ✅ REAL账户下单 (通过API，3个订单，balance → frozen_balance)
ℹ️  ✅ 订单结算 (通过RPC API，盈亏计算)
ℹ️  ✅ BTSE转出测试 (从 REAL 账户转出到 BTSE)
ℹ️  ✅ 转账历史查询 (通过API获取转账记录)
ℹ️  ✅ 订单状态验证 (通过RPC API，ACTIVE/WIN/LOSE状态确认)
ℹ️  ✅ 按轮次查询订单 (通过API，DEMO/REAL账户按轮次聚合查询)
ℹ️  ✅ 轮次结算 (通过RPC API，基于Fixture自动获取结算价格)
ℹ️  ✅ 历史订单查询 (通过API，DEMO/REAL账户按轮次聚合的历史订单)
ℹ️  ✅ 最终账户状态 (通过API)
ℹ️  ✅ BTSE转账日志查询 (通过API获取BTSE内部转账记录)