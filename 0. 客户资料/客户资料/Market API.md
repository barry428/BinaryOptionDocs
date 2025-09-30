/fixtures

“symbol”: <str>
“includeExpiredAfter”: <datetime>


{
     “symbol”: <str>,
     “price”: <float>,
     “open”: [
        {
            “expiration”: <datetime>,
            “side”: ”put” / “call”,
            “price”: <float>, // 当前价格 下单的时候 需要根据 side 来获取对应的价格
        },
        {
            “expiration”: <datetime>, // 要根据轮次的结算时间信息来对应
            “strike”: <float>,
            “side”: ”put” / “call”,
            “itm”: <bool>,
            “price”: <float>, // 赔率，下单的时候 需要根据 side 来获取对应的赔率, 直接使用即可，不需要转化了
            “openInterest”: <int>,
            “openInterestValue”: <float>,
        },
        …
    ],
    “closed”: [
        {
            “expiration”: <datetime>, // 结算时间，需要和订单的结算时间一致
            “side”: ”put” / “call”
        },
        {
            “expiration”: <datetime>,
            “strike”: <float>,
            “side”: ”put” / “call”,
            “itm”: <bool>,
            “price”: <float>,
            “priceUnderlying”: <float>, // 结算价格 (需要根据 side 来获取对应的结算价格)
            “openInterest”: <int>,
            “openInterestValue”: <float>,
        },
        …
    ]
}

/newbet

{
    “symbol”: <str>,
    “expiration”: <datetime>,
    “side”: ”put” / “call”,
    "priceUnderlying": <float>, // 下单价格
    “price”: <float>,  // 赔率
    “amount”: <float>,
    “tradeId”: <str>, // 订单id
    “exchangeId”: <str>,
    “userId”: <str>
}

{
    “status”: “ok” / “error”,
    “message”: “...”
}


/history

“symbol”: <str>
“limitAfter”: <datetime>


{
    “symbol”: <str>,
    “history”: [
        [<int>, <float>, <float>, <float>, <float>],
        [<int>, <float>, <float>, <float>, <float>],
        …
    ]
}
Request to get historical data of a symbol. The data is provided as an array of arrays to minimize its size in format [timestamp, open, high, low, close]
展示的话只需要使用close
