Base
Base URL：(pending)
Auth：Authorization: Bearer <OAuth service token>
Amount：DECIMAL(22,8)，in JSON String （avoid precision errors）


Environment
Dev: https://api.btse.dev/payment/wallet/v1/binaryOption/
Staging: https://api.btse.co/payment/wallet/v1/binaryOption/
Production: https://api.btse.com/payment/wallet/v1/binaryOption/
Create Order
PUT /ext-orders/create
Request

{
  "extRequestId": "unique-id-of-requests-from-caller",   // unique 
  "username": "abc@def",
  "currency": "USDT",
  "amount": "100.0",
  "bonusAmount": "0",   // 0 in phase1
  "extRefId": "external extra ref id"    //optional
}


Response

{
  "code": 1,
  "msg": "Success",
  "time": 1663235599835,
  "data": null,
  "success": true
}

Error
Http status 500

11000048
DB Exception


11000012
USER_WALLET_NOT_FOUND




Http status 400
	
11000013
Insufficient Balance in Wallet










Cancel order
PUT /ext-orders/cancel
Request

{
  "extRequestId": "unique-id-of-requests-from-caller",   // unique 
  "username": "abc@def",
  "currency": "USDT",
  "amount": "100.0",
  "bonusAmount": "0",   // 0.0 in phase1
  "extRefId": "external extra ref id"   //optional
}


Response

{
  "code": 1,
  "msg": "Success",
  "time": 1663235599835,
  "data": null,
  "success": true
}







Query request
GET /ext-orders/{extRequestId}
Case Order

{
  "code": 1,
  "msg": "Success",
  "time": 1663235599835,
  "data": {
       "extRequestId": "unique-id-of-requests-from-caller",   
       "username": "abc@def",
        "currency": "USDT",
        "amount": "100.0",
        "bonusAmount": "0",  
        "extRefId": "external extra ref id" 
   },
  "success": true
}








Case Settle

{
  "code": 1,
  "msg": "Success",
  "time": 1663235599835,
  "data": {
       "extRequestId": "unique-id-of-requests-from-caller",   
       "username": "abc@def",
        "currency": "USDT",
        "totalOrderAmount": "100.0",
        "pnlAmount": "0",  
        "extRefId": "external extra ref id" 
   },
  "success": true
}

Case Not Found

{
  "code": 1,
  "msg": "Success",
  "time": 1663235599835,
  "data": null,
  "success": true
}



Settle（profit/loss)
Settlement result for multiple orders
POST /ext-orders/settlement
Request

{
  "extRequestId": "unique-id-of-requests-from-caller",   // unique 
  "username": "abc@def",
  "currency": "USDT",
  "totalOrderAmount": "123.00",
  "totalOrderBonusAmount": "0.0",  // 0.0 in phase1
  "pnlAmount": "-100.0",                 // totalOrderAmount + pnl >=0
  "pnlBonusAmount": "0.0",                 // 0.0 in phase1
  "extRefId": "external extra ref id"  //optional
}



Response

{
  "code": 1,
  "msg": "Success",
  "time": 1663235599835,
  "data": { 
     "transactionRef":"2025090805844"
  },
  "success": true
}

Error
Http status 500

11000048
DB Exception


11000012
USER_WALLET_NOT_FOUND




Http status 400
	
11000013
Insufficient Balance in Wallet






