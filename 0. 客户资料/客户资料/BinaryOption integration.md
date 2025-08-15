# User auth

After login process, user would bring OAuth access token in the request header (Authorization)

![][image1]

Backend could verify the token through redis  
Redis Key: **OAuth:AccessToken:{accesstoken}**

Ex. OAuth:AccessToken:eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3NTUxNDExODksImV4cCI6MTc1NTIyNzY0OSwiaXNzIjoiYnRzZS5zdGFnaW5nIiwiYXVkIjoiY2xpZW50LnNlcnZpY2UiLCJ1c2VybmFtZSI6ImZlbGl4MDgiLCJjbGllbnRJZCI6ImJ0c2UiLCJyYW5kb20iOiIwLjQxMTc0MzUzNTk4ODYwNDM2IiwiZGV2aWNlVHlwZSI6Ind….

Value:

```json
{
    "tokenType": "bearer",
    "expireTime": 1755227649715,
    "username": "felix08",
    "metadata": {
        "id": 122831,
        "username": "felix08",
        "salt": "&bxRQoM^",
        "whitelabel": "btse",
        "firstname": "",
        "lastname": "",
        "email": "felix08@mailto.plus",
        "telephone": "",
        "language": 3,
        "status": 1,
        "tradeCurrency": "USD",
        "registerTime": 1708930860626,
        "twoFactorInfo": {
            "binded": true,
            "type": "google",
            "secret": "AAKIMB44DBK4NVIS",
            "url": "otpauth://totp/felix08?secret=AAKIMB44DBK4NVIS&issuer=staging.btse.co"
        },
        "capabilities": {
            "allowDeposit": true,
            "allowDepositCrypto": true,
            "allowWithdrawal": true,
            "allowWithdrawalCrypto": true,
            "allowTransfer": true,
            "allowConvert": true,
            "allowTrade": true,
            "allowExpressBuy": true,
            "allowExpressSell": true,
            "unifiedWallet": true,
            "allowSpotTrading": true,
            "allowOTC": true,
            "allowFuturesTrading": true,
            "allowSendWithdraw": true,
            "sendWithdrawApproval": false,
            "allowLottery": true,
            "allowC2C": true,
            "allowBTSEStaking": true
        },
        "kycInfo": {
            "kycLevel": 2,
            "kycV2Level": "L2M",
            "latestKycType": "P",
            "latestKycId": 33983,
            "validKycId": 31008
        },
        "kyc": true,
        "shareId": "8420040240",
        "channelUsername": "felixkol",
        "userAuthTypeEnum": "WEB_USER",
        "loginBySubAccount": false,
        "keepLogin": false,
        "notificationType": "EMAIL",
        "phoneNumber": "+886-916835499",
        "lastIp": "123.51.190.194",
        "lastLoginTime": 1755141189923,
        "expireTime": 86400
    },
    "clientId": "btse",
    "clientName": "btse",
    "whitelabel": "btse",
    "scopes": [
        "trusted"
    ],
    "grantType": "password",
    "refreshToken": "320cd321835a15b5e40542c8dcb09d4fe23d89be10c1f634feaa99575ca26edf",
    "refreshTokenExpiresIn": 691260,
    "idToken": null,
    "deviceType": "web",
    "deviceId": "_imogdc1696414518775",
    "extraMetadata": {
        "sourceEnum": "WEB"
    }
}

```

Verify flow:

1. Check toke existed in Redis  
2. Get  **`username`** from redis value. (Note: username might contain ‘@’ , ex ‘abc@{whitelabel})

# 

# 

# 

# Server to Server Auth

Preparation: apply a new OAuth config ( clientId, secretKey) for BinaryOption service

a. Request Service：發送請求的service. Ex. BinaryOption service  
b. Receive Service：接收請求的service. Ex. PaymentWallet service

Request Service：

1. 使用Client ID/Secret與scope搭配client\_credentials grant\_type呼叫oauth service API **(註1)**，取得access token / refresh token與對應TTL (scope不帶則會直接assign為當前該client可用的scope)  
2. 呼叫Receive Server時，需要將access token放置於Authorization Bearer token的位置，Receive Server會驗證該token的是否合法，正確即會回覆相關資訊  
3. access token直到expired前都可以重覆使用，請注意不要每次打request前都重新要一次token，避免空間浪費。若是access token expired可以使用refresh token取得access token **(註2)**，若是連refresh token都expired了就需要用client id/secret重新要token  
4. 在成功取得access token與refresh token時，API結果也會回傳這兩個token的TTL，建議參照這資料，如果發現當前access token已經expired但refresh token尚未expired，就可以直接refresh token。反之若連refresh token都expired了，就直接使用client id/secret取得新的token。  
5. 目前各個環境的Client ID和scope設定會相同，但Secret會依環境給予不同的資料 **(註3)**  
     
   

註1：為OAuth的Retreive Token API，grant type為client\_credentials，文件位置如下，Content type選擇application/json，Example選擇Client Credencials即為呼叫範例。若希望取token時能夠有多個scope權限，則使用空格分隔即可(ex. “wallet.read trade.read“)，另外scope不帶會直接assign當前該client可用的所有scope。  
[https://api.btse.co/oauth/openapi\#tag/Acquire-Token/paths/\~1oauth\~1token/post](https://api.btse.co/oauth/openapi#tag/Acquire-Token/paths/~1oauth~1token/post)

```json
{
 "client_id" : "{{CLIENT_ID}}",
 "client_secret" : "{{CLIENT_SECRET}}",
 "grant_type" : "client_credentials"
}
```

註2：為OAuth的Retreive Token API，grant type為refresh\_token文件位置如下，Content type選擇application/json，Example選擇Refresh Token即為呼叫範例。若希望新取得的token時能夠有多個scope權限，則使用空格分隔即可(ex. “wallet.read trade.read“)，另外scope不帶會直接assign成先前acquire token所指定的scope內容。

```json
{
 "client_id" : "{{CLIENT_ID}}",
 "client_secret" : "{{CLIENT_SECRET}}",
 "grant_type" : "refresh_token",
 "refresh_token": "{{REFRESH_TOKEN}}"
}
```

註3：各環境API URL如下  
Dev \- [https://api.btse.dev/oauth/token](https://api.btse.dev/oauth/token)  
Staging \- [https://api.btse.co/oauth/token](https://api.btse.co/oauth/token)  
Testnet \- [https://testapi.btse.io/oauth/token](https://testapi.btse.io/oauth/token)  
Production \- [https://api.btse.com/oauth/token](https://api.btse.com/oauth/token)

註4：以下為Redis資料範例  
Key  
OAuth:AccessToken:eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJjbGllbnQuc2VydmljZSIsInJhbmRvbSI6IjAuOTAwODA4ODk5MjcxMjg4NSIsImNsaWVudElkIjoiYWRtaW4iLCJpc3MiOiJidHNlLmRldiIsInNjb3BlcyI6WyJyZWFkIiwid3JpdGUiXSwiZXhwIjoxNjc4NzkxNDAxLCJpYXQiOjE2Nzg3MDQ5NDF9.cwvlWsVZQiKxJ50WSSiIXmxrYHQ20HpCyW6sQ0Q4kjQ  
Value

```json
{

   "accessToken": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJjbGllbnQuc2VydmljZSIsInJhbmRvbSI6IjAuOTAwODA4ODk5MjcxMjg4NSIsImNsaWVudElkIjoiYWRtaW4iLCJpc3MiOiJidHNlLmRldiIsInNjb3BlcyI6WyJyZWFkIiwid3JpdGUiXSwiZXhwIjoxNjc4NzkxNDAxLCJpYXQiOjE2Nzg3MDQ5NDF9.cwvlWsVZQiKxJ50WSSiIXmxrYHQ20HpCyW6sQ0Q4kjQ",

   "tokenType": "bearer",
   "expireTime": 1678791401849,
   "username": null,
   "metadata": null,
   "clientId": "admin",
   "scopes": [
       "read",
       "write"
   ],
   "grantType": "client_credentials",

   "refreshToken": "d06a99080e1f94c8de86b57ae866d1dc80f5f8aa36de9df8deb4ef0d16b2a308",
   "refreshTokenExpiresIn": 172800,
   "idToken": null,
   "deviceType": null,
   "deviceId": null,
   "extraMetadata": null
}
```

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAnAAAACwCAYAAACPZFM+AAA58klEQVR4Xu2d6bMVVZbF+U/qux/95IcmmogmuiKgtWkIgrDRIBBCSwQKZxwpShQxBBxxKhVFEBQEFWTSglLUQgmUoRmKSRRUZBaUQajsWqdcWevue/K++x7vwbuwfhE78px9hsybN2/muiczz+5R/Mqmr39h0hhjjDHGdGN6MGEBZ4wxxhjTGtQIOJvNZrPZbDZb97caAXfy1FmbzWaz2Ww2Wzc3CzibzWaz2Wy2FjMLOJvNZrPZbLYWMws4m81ms9lsthYzCzibzWaz2Wy2FrMeTFjA2Ww2m81ms7WGdVjA/eY3vyntv/+7X115V9rX33xb54NhWxrl22MvvfRKnc9ms9lsNputO1hDAffoo1PqjGUqjn4+8UvxX/91ZZk/cPBoXV8//Xy6zldle/buq/Np+9/dOKKuHBYFW8wfOfpTXZucYV1RwH2z57u6ejB8dixPnDxTV2az2Ww2m83WFdZQwOkoWxRDMX/ZZZeV/v/btDXlOTIHHwTRzJmzy3b//u+9yrYTHpyYlh9/srq4btjwYv+BI2U9iKmhQ69Lo270oc6hw8fqRGHcJubRHult23eVvjlz5hZTpj5evPfe0tIHEYr0V7v31vSF9A/7DxdjxtxSLFy0uPTNnDUnbQPS3363vxh7193F1r/trNkGm81ms9lsts62hgLuw48+SeKEpmXI/8d/9E6WBM4Ph0q/1sHy3/6tZ50vJ+C07QMTHkpLCLdbb7u9Zt2NRuCixX6R/uvqNXXtYr3/+Z/+Zfr+cePr6v7v/w6u8UFQap82m81ms9lsXWUNBRxMhVD0V6VXffzX0uAbOXJUXV0VcH/4wx/r2v7lL6vKEbbDR44nEci2jQRcLq/9rlj5UbF9x1fFtdcOKQZfc20Sc1qPbcf94Z+iDdtw++131n0mCkzakqXvp/br1v9f3XbZbDabzWazdaa1KeBgURhF38svv5puj9KPW5AQZSqMFix4t3hv8bLS98yzzxevzphZbN6yrfTNe2tBMfr3Y9LzZPQtXrK8mDhxUs06x49/IPUXnzvTbdJ8nz590y1d9otRPeSxbmwH60FUIo3RNO0L6WPHTxYr/yEq//M/f5t8KuBQfvDQj+m2LIScboPNZrPZbDZbZ1tTAq69lnuJAc+IYanCCKIoijAYhFX0xT6P/vhztm0ji8+nVb3N+t33B+p8GLWLz9yp8RayzWaz2Ww2W1dblwi4RqYCzmaz2Ww2m83WfjvvAs5ms9lsNpvNdm5mAWez2Ww2m83WYmYBZ7PZbDabzdZiZgFns9lsNpvN1mJWI+BsNpvNZrPZbN3fagScMcYYY4zp/ljAGWOMMca0GD2YsIAzxhhjjGkNLOCMMcYYY1oMCzhjjDHGmBbDAs4YY4wxpsXoMgE3efLktDx06FAxc+bMUNo2v/3tb9PyuuuuCyXGXFj27NlTfP/99zU+xPjNUeU3xhhjzoWmBdypU6fS8uTJk0lcjRo1KuVPnDhRvP766ym9YMGCJNiuvPLKVAdLCrjBgwcXQ4YMYXfF3LlzU53PPvusbLt79+5SuKHt2LFjy34OHz5cjB8/vmw/aNCgMm1MZwHB1a9fvzJ/+eWXFwMGDEj+vXv3Jt+unTuL/fv3l3UAypcuXZqW999/f/KhLfJYgjVr1qT8vHnzynbDhg0rLrvssmL+/Pmlj/zwww+pfs+ePUvf8uXLiyuuuKIYOXKk1DTGGHOp0ZSA27VrVymssNy+fXuZ//nnn4sXX3wxpWfPnl0cOHAgCbERI0akJQQchRrbvPXWWylNwYb+0Rbp1atXl+vBRbJPnz6pHn3g7bffLtauXZvSxnQWEEubN28ubrrpppSm75133knHPH1btmwpvvvuu381/LVe7969iyNHjpT1jh8/ntJYnjlzpqZPgOO7V69excaNG0ufAh+Offw2KOLg+/jjj4u77rqreOGFF0ILY4wxlwpNCThl3bp1SUg1EnDgzjvvTEsIuNdeey2lp0+fXvz444+p7Zw5c5IPI3kYYdO2QEfi1PfFF1+UZcZ0Nk8++WQxdOjQOrEF+vbtm5ZVAo78/e9/L2bMmFHnRxp/bDSPUWbYwIEDk3hUtC7AemFE+zbGGHNp0S4Bd/To0aywwsUH4BYpRRgugkCfgaOAQz3epkJ/GEloRsBhpELFozGdCQURBFhOwDHdloDbt29fOZKcE1n0XX311bUFAb11evDgweL06dPFkiVLSl+ub2OMMZcGTQk4vWVKAdW/f/+ynD4IOYow+nICTsvZb5WAe+SRR2oEG9ILFy4s88Z0FhBEv/zyS3omTQXcqlWrkoCKAg63RidMmFDWw58StFdhhTRGqd9///2aPgF/V2gDsQbhiEcDKNJQD7dkP/300/TcG30YqZs0aVIxZcqU5DPGGHPp0ZSA6y6okDSmK8AxplBsxdubVfBFBwVCj2zbtk1K/sk333wTXSV4YQLPzykQfMYYYy5tWkrA8U1YY84XOppmjDHGdBdaSsAZY4wxxhgLOGOMMcaYlsMCzhhjjDGmxehx8tTZAmYBZ4wxxhjTGljAGWOMMca0GBZwxhhjjDEtxnkVcC+99FJ0tUlH2hjTETAH3NatW4sdO3bEojSh7sMPP1wcPny4xn/ixIk0CbXOE4c+ohljjDGdSZcLuBjLtL10pI0xHYFzvmHiXURVYMQP+BHgHowePbqsh2D0gwYNSmkIOERwUBguzhhjjOlsmhZwnEQXguzee+8t+vTpk2aVh8B6+umny3q///3va2I8ohxtvvrqq5R+55130vLPf/5zKj927FgxfPjwYvDgwWUbtlu5cqUFnDlvxEl7L7/88ppl9COMFsJfkRjizQLOGGNMV9G0gHvsscfSkoLqwQcfLObOnVvjgxBD3Ef1xRE43HLSciwZKkh9gALRmPOBCjiEtxo3blyxYsWK4ssvv/xXpX+wYcOGYvny5SmNNrBXXnmlpg6wgDPGGNNVNC3gCAXVG2+8Uezbt6/GhyVEHA1EARfT0YcRjegz5nxAMYZboU899VTybdq0qU6czZgxo1i/fn2N7/vvv68bwbOAM8YY01U0JeAgqkaNGpXSjQTcq6++Wtx5553pIXD6cDt18eLFlcIMy0ceeSQ9CN6/f//St2jRotTWAs6cL6IAI/AfPHgwpbFkvWHDhtUEmo/tLeCMMcZ0FU0LuNtuuy2lKahw+xQPcasPDB06tCaPZ9yQxxt+OQF36NChYuDAgTUjdRR7CxYssIAz540owMiIESNSGZ59wxJ58Msvv6Q8LY7UWcAZY4zpKpoScMYYY4wxpvtgAWeMMcYY02JYwBljjDHGtBgWcMYYY4wxLYYFnDHGGGNMi9GDCQs4Y4wxxpjWwALOGGOMMabFsIAzxhhjjGkxzouA82S8plWomsy3Cq1/xRVXFG+++ea/CjuB9m5PZ4N4xMYYY7ofXSbgclEXjOnunItgOpe2Vdx8883RdV7pis9kjDHm3GlKwJ0+fTrFJQUQY7SdO3cmX58+fUrf0aNHa+rENgj6bUx3BYHsAcNjqYC56aabSt/mzZvLeoTpnA/9su2JEyeSD78H+hCWC/Ts2TPlMZK3cOHCFFaO/cA0PBd9MICwdczzc+TqjRs3rrj++utT+oMPPijrcd2wDRs2FKNHj65pZ4wxpvvQlIBTqkbWfv7552LXrl3F2LFj68o0fe2115ZpY7oTiO1LYUamTp1aphELlVDUqLhhLFT1ab29e/eW/j/96U9F7969U/rIkSPZ/nLCKVfv4MGDdb5NmzYlv/q2bt1a7Nixo1LA5dad2wZjjDEXnk4RcOprS8ANHjy4TBvTneBxumbNmiRcFi1aVHMLc/jw4WU6CpwJEybUlcU0+8XoGvrCM3OrV68uDfTt27esz7Zoh7qffvpp3XqVtnwY5Zs/f36NgFu2bFlZnlt3rk9jjDEXnqYEHG7jjBo1KqVxkbv33nuLadOmFVdeeWXpw8Whf//+NQKOFyULONMKUKyMGDGiPGbjrciYjktN6wjYc889V5bjVuWKFSvKMoxeT548OaVzIgrbE30DBgwojh8/ntIUYyh74403yjTEGW65njx5MvnGjBmTfqezZ88uPxf6Ibl1c2mMMaZ70ZSAU3hhw0VHOXToUE0exDrGdFf4/BjBM5/I448KmThxYvJpvZzQ+eqrr1J++fLlpR/PsyGtt2HxyAF8AwcOLH0UUdgejLwR1OvVq1fNejAqh7ze5uVzenoreNiwYcmnnwUji/DpLdScgMNtYV2nMcaY7kG7BZw+RG3MxQJE1JNPPhndNUDAVcGXfDoLFXXGGGNMpN0CzpiLkY0bN6a3rRvR6A3qw4cPR9c5ge0xxhhjqrCAM8YYY4xpMSzgjDHGGGNaDAs4Y4wxxpgWwwLOGGOMMabF6HHy1NkCZgFnjDHGGNMaWMAZY4wxxrQYXSLgNPKCMa1CbsLao0eP1uQbTSVijDHGnC86JODiRQ2cPXu2TFPAHThwoPQBhOSKoB39DMpNEPbHmPMFBZxGEHnttdfKNECkA+XMmTPFqVOnany549wYY4zpTJoScAj5o4HrcdFiHiF7+vTpUyxZsqSmDmIyzpgxo/ShzqpVq1L8VAo1lG3fvj0tYQsWLCgjPSC/bt26YtasWcUNN9yQfMZ0JRBwt956a5pEl2LuhRdeSDFHIdKwRBB6xiBFHfw23nrrrRTWCiBUFo7ve+65J5UZY4wxXUFTAk4ZNGhQElcvv/xyykOYRfQWqoo6GgUZyyD29u3bV1lf+zOmq9BbqL17907LRiNwQ4cOLdNsO2TIkJTesWNHWWaMMcZ0Nu0WcAC3mCiqbrzxxlBaLeAibQk4Y84nKuB4/DUScBiNI9oWAeKR14DyxhhjTGfSlIDjbU6AJUbdokjTkbJYBhYtWlTW4TNDjQTchAkTyvpPP/108hnTleQE3PLly4tJkyaVz3iiDp+RQ/rIkSPFhx9+WFx22WWlD7dY582bl4ScMcYY0xU0JeCMuZTByzT6Qg2fgZs4cWLx448/1r2ZClFnjDHGdCUWcMZ0EAg4Y4wx5kJgAWeMMcYY02JYwBljjDHGtBgWcMYYY4wxLYYFnDHGGGNMi2EBZ4wxxhjTYvRgwgLOGGOMMaY1sIAzppP54YcfoqtpOMdcR9C56i4mDh06FF3GGHPJ0y4Bh9npp0+fHt2dwnXXXRddxrQUDLPVq1evUNIYRG/YsmVLSiPWcEe4/PLL0/rXrFkTizoFjVLRDPg8sQ22sYpYV+nbt290NWTu3LnF+vXrizNnztT433zzzWL27NnFiy++WBw7dqymzBhjWo2mBRzCBeHioGGy5syZk8JqjRo1qvRNmzYt1Tl48GDpu/LKK4t+/frV5J999tnUlqAN/MZcSCAk9FiF6BgwYEDy7927N/k2bdpUHD16NPkeffTRsi4FnAqVq666qk6c6Dp27dqV8gzFpW0xUTDKnnnmmZTnenv37l307NmzrPftt98W27ZtS8KR4buuvfba1BYhvQj7O3z4cMrr59D+IvPnz091dNuQv//++1N62bJlqQ7AOWLhwoXp86AOxSy38Yorrig+//zzVDZmzJia/gBClyEdvwMu33777VR+4sSJsjyCUH2og++N3HPPPWl54MCBVOZJmI0xrU7TAo7CTUUXBRfinELgIUbk9ddfX9ZHSKFcXNRcPFSLN3Oheeyxx9ISobEoKLjU9BdffJGECBg4cGApvijgtC3DatFXtQ6OwNE3derUYvPmzSn9/PPPFxs3bkzrHTt2bPKtXLky+QBFEtrit7hhw4Y0AgUo/lDG/pBu1F8ObpemEb9YP8OKFSvKfByB023kKCHEr24TYNxj7B+MmGkZlhqHtgqcW9auXVvjY32U4c+jMca0Ou0ScO+9915x9913p4sETtC4VaHMmjWr2LlzZ42PAelp9Gk5sIAz3YEnn3yyGDp0aI1oILyVB+Hz5ZdfpjRiobJOTsDlyK0jCjiKQoIRJKxXn6/D7xBoP+obMWIEq9Zsy9VXX92wvxzaHmkIPxj9GNVDmv1FAce0+gBHwujHCBn3D0c3c21jP23R3vrGGNPdaUrA4WSMkyqJomvVqlXFJ598kv4d86KBkTpc3FSsLVmyJC3h4/MpsS9jLhS8yP/9739vKBogfHhrct26daW/kYDjIwVV64gC7pprrklLMnPmzLRejuiBRgKO5LYFtyIb9ZdD22uajBs3Lo2ycbtVwFHcAW2LcwD/BNKPEU2A/dNZAg4icdiwYdFtjDEtTVMCTkWY5nFrB+nBgweXZRMfeij59uzZU/o4+sbbH0hPmjSppl88VBzXY8z5BKIAI18QOCoaaLxtCuEDsUY//4xEAffqq6+WdfBMGsviOvQ5OS6ZpoEqwcVbgqgHH95GRRrPyrEtnzujH1T1xzaKbgeec2Weo5L6DB/3B8rhx+fTbVQjTLMN+mlGwN1yyy2lrwrUPX36dHQbY0xL05SA62ws1Ex3Zfv27TV5CgU+qwUofHbv3l36qjh79mx6UUCJ6wBVU4Doy0A5Pvroo/J5UmyrjqLhpYFIW/3hOTgVSgpG1Am2F6NkbXHy5MnUn24jwPNzVeT2TxVV26o0U8cYY1qNCyLgjGkVchf/OHJ1IeH2ff311w2n6WiW0aNHd/pUJLoPc/vzXGimv45OzWKMMd0ZCzhjjDHGmBbDAs4YY4wxpsWwgDPGGGOMaTEs4IwxxhhjWgwLOGOMMcaYFsMCzhhjjDGmxehx8tTZAnYpCriXXnopLbdu3ZomEjamGTREVUeIYbIimCcR02Ps37+/2LFjRyw+J9pad1dwIdZpjDEXO+0ScLiwdNWcSo1CaWG9TzzxRGmdhScUNheCRnOXIRboBx98kNLfffddGWIrR6N+quhIm2ap6rvKb4wxpuM0LeAQuBozr6voYYisnK9fv34pjxip9G3atKmu3c6dO2t8OXJ+7YMhuiAC6fvpp5/q6oH169fX+ebPn1/s3bu3mD17dl2Z9jFy5Mgynqu5+Ni1a1cSG7A77rgj+RD4nT4KEYbMGjJkSBkSqy2Ron1o3ejTvAq4RvUARrk0X4W248S/SA8fPryyrbZhHayP6zxx4kRdea6NMcaYzqNpAUdBgyD1hKNmCN/z4YcfJiF1/fXXl/UxW30UQlwytA59bY3ARWHFJWaNf/DBB0uhCDBKiNiT1113XfHDDz/U1Mdy8uTJNb4o4LTsvffeK2+1Dh061ALuIkaFRhQd+POCYO1ABRziAQMc/zNmzCjrR3J94ziF+AEUU4iowNumKuCefvrptETbN998s0wT3qZEiKsBAwaU/khuO7CkYG1Ez549y9ij2s+yZcvqfNxXFHfGGGM6l3YJOBpGonBhmTt3bk2dWbNmlSNqBPXx755Gn5YDFXC4MMJUDEbUN2bMmOLWW2+tEZcg1om+RgIOIy/gvvvuK+NU4iJtAXfxokLjueeeK9PffvttTZkKOKVKqOC26MqVK8u8Cic1/OGpEnBaLwZ5R3zT2FcVWvbwww+XvrZCg61YsSIZeeWVV+rWxTR+I8ePH6/zG2OM6TyaEnBTpkypCeato1RffvllEl86ooZRL62D2JG4iKnv3nvvLaZNm1YKNwimxYsXp3QE9VetWlUafQTiDIG24eN6Zs6cmUZEbrzxxnTxZH2IPKTXrl3blIAD8KEdzALu4gVCA8c5XmrJCROiAm7OnDkpjZHg6dOna7Ua9EF+9nfVVVeVfw4o8KoE3AMPPJCWaBsFHNA4qBxhzpH7XFi2JeAw+qaowGWZ9t23b9+0xOeL+88YY8y505SAU7Gkedw+Qnrw4MFl2cSHHkq+PXv2lD7kYXxWDelJkybV9Iu3QON6CNvT6CMYfQMbN25M/vHjx5dluO0J4cUHwwFEnfa1YMGCNMqCizF9KuAgTvHs3LZt24qlS5eWfnPxAbEBsfX666+n/DXXXJN8NKACLvfsWU6waB+xrvqqBBzrQCypgGM77Qe/A/oiWo+iEmkKOKTffvttbVLTBkYftgVLPDuo9araGGOM6TyaEnCdTZVQ665E8WguTiA0Tp8+XRw+fLgp0RFvoRKMrHUHmvkMkY60McYYc/65IALOmO4KRq84gtUWu3fvjq4Eb4teSPAMWkfmkMOjBcYYY7o/FnDGGGOMMS2GBZwxxhhjTIthAWeMMcYY02JYwBljjDHGtBgWcMYYY4wxLYYFnDHGGGNMi9GDiWYEHOZBw+Si55sbbrghuowxxhhjLlmaFnCY24phqJQzZ87U5MHRo0dr8ggEnkP9bQWzz8FA9cr+/ftr8mfPnq3JV5H7HLn5vBAxwly8VB2ruWPNGGOMuVA0LeDGjh2bLm4qpnIRCpjv169fyn/yySelb9OmTXXtdu7cWePLkfPHdWM5aNCgtGTg+s8++yxbT/sAiDPJOgirxTIYROvAgQOTL4bgMhcXmPyWoZ+GDRuWfMzTjDHGmO5A0wKOogVxRhHTFKNTiGdKkEdg++XLl6c8RuEo+BBnFNZIROkI3OOPP57s2WefrakTwTq0T46YNVpPzgcwAod1wod+p0yZUpZBwG3YsKH8LE888YRH4i5CVKAxnfMZY4wxF5p2CTgEhodRLKmAA1988UUp4EhOfOVEVHtuoWK97733Xk1Zrs8q34EDB+p8EKUYfUMawpPP3eHWGQTcmjVr6rbDXFxAoK1evTrZqlWrSp+WG2OMMd2BpgQcRqM2b95c5lX4YNQN4uvUqVOlD6JH60DYQTSp79577y2mTZtWCrerr766WLx4cUpHUB8XVNp9991XLFq0qK5PrQ8wUoY0jWVY11/+8pca34kTJ+rq9e/fPy15CxXpffv2JX/u+TjT2qhAmzp1ap3PAs4YY0x3oSkB14iffvopuoo9e/bU5CF2OOoFKJIw6qXEfCMOHTrUpoji82xABd7p06fLNInbTDGJuhCbJL4kYS4uevXqlYTap59+mvIWcMYYY7oj5yzgOgJfcDgfYIRv8ODB7Z7+BKOOEH0jR46MRcYYY4wxF5QLIuCMMcYYY0zHsYAzxhhjjGkxLOCMMcYYY1oMCzhjjDHGmBbDAs4YY4wxpsWwgDPGGGOMaTEs4IwxxhhjWox2CTjMizZ9+vToroFRC4BOntss7W0zefLktEQ7RGcwpqNgot7LLrssLWG5SaqNMcaY7kCPk6fOFrC2BByiHvTp06dNgaXlVXU1KkN7QZgu5c4776zJEwSkj7Qn0oO59NBICzhW7r777jKfi/px/Pjx6EowrNzJkydDyT9BFBFjjDHmXGhawGmMUDJixIi03Lp1a7Fs2bLixx9/TOW7d+8u637wwQdpqe1RjugICEiPtvDNmzevLAeoAxszZkzx2WefpfT1119ffPvttzV1sA24uML37rvvpgsv0tu2bSvrUXgiJiuWCFZvTIQC7syZM8WwYcOKI0eOlP4VK1YUt9xyS7F06dLSd/DgwTRid/PNN5e+xx9/vDh27FhKr127tvjkk09SHZZfddVVdWHbjDHGmPbSLgEHwYVRCd6qjAKO9bQN2LBhQymc7rjjjppyCjj1EQSN11uySKNc63AEjgLutttuK8s2btyY4qFCwE186KGy3ubNm8s6xhAIrC1bthRr1qxJoux3v/td6R87dmwypAH+NDz0j2MKefr0uMy14dIYY4w5V5oScLioPfnkk2WeFyouMerQjIBTH26j3nDDDZUCDiN36JdgxI5o/aFDh5Y+CLiPP/64eOWVV5LvxhtvTMHoLeBMM0SBxfzDDz9c4wcsmzt3bpnu27dvXbmS8xljjDEdoSkBh4DwiooxGEbGVMBFsRYFnNapEnBab/jw4cWqVavq2rLe9u3b0xICLrYFFnCmGSCwvvnmm2LHjh3FxIkTS8GFJUbl8OeAx5SWVQk4HNsnTpyoqWuMMcZ0Bk0JOGMudXD7P77I8PXXX9fkI6gfX7oxxhhjOgMLOGOMMcaYFsMCzhhjjDGmxbCAM8YYY4xpMSzgjDHGGGNaDAs4YzrIrl270pIT9Sr9+vWLrhK0mzp1avHVV1/FohquuOKKmjzmYXz++eeLw4cPlz5MmRMjPuDtV8CJiAEmF1ZYJ4eWYWJs5jGJNowg1Njf/va3lOY+aLbfHCiH6XarH4bJkxuBSZKxb7/77rvSF9f7+uuvF59//nmZx1vsANPF3HXXXaW/itjfrp070wst0Y/9g2mMCKZi0u1StC0idbz66qs1bTtK/N5J3FZ8r5j8PPq///77monPsV1vvfWW1Kh/uxrlnMqJsA7Wo9+ngqmj9LuP5XxpCMeA9sF6WGISboLvJR5LBN95LOME2+wTn11ptO05nnrqqbr9wLbxOOYsDm2ByfLbIm5bLh99OebPn1+3Xdpu3759xWOPPVYTWSnXL3w4lrF/df/l6ip79+5Ny/g94XhkVKXYH74jRMJp1Hcsi3nC7Va4TR999FExadKkmjLw5ZdfFlOmTEmTuEfw+9+/f390Z4m/qSos4IzpIBRYuR9bz549oyuBHzjqY5JgLKdNmxarlCAKCcH0JaiPKXuwpJDCiSRGFuH2vPDCC2mJ8nfeeUdq5LeZsOzs2bMpzTzmXNR2iE7B/DXXXJOWzfRbBdcF69WrV9bfaH9BGKMOt3Px4sXJjzRBunfv3mnJCclZfs899xQ33XRTWbcKCL033nijzKO9ThdDdLojlGEfYRnrsRwgBCDSiNiRq9deotgiEGJ6TGBdmO8T3ykji9CvaXwmxgsmgwYNqqmDch6vDCvH75PfDY1vdiONaXiw5JvbSH/66af/7Lj41zQ9TzzxRE0fMNbXPxjYDnzOHNqODBgwoKaMhmmFQNW250A5vm/uB/WrUZBxCqy2wLyTbaHrq8pHXwTnL+y/+F3H9OjRo+t8Efg2bdpUXH311eW6aVWgjMcVzmP6Jxn7DOc91lNDBB2eY6uIZTFPEKhAy3AMQzjiDzT8CGqg5TjWkMe0Z1i++OKLZRnyPH70vFCFTknVCAs4YwT8wK699toyzimjjYDLL7+8TAMVcPixYjl9+vTkwwkQJy34cFIhyCua5w8fYgBAaJC4brbLXaBZ1oyAQ79qWobPh1EI5nECgvEEpAIutgXYj5rXfjGnHvKPPvpoWX7rrbeWaW2nE3oTRFlBnTj3nsI8lxhN4GgboPBluQo4fh6IGcwNiDoaFQb5N998M30WXsixfOSRR2rqALTT+LeI4BHj6MZtJXr8AawDdSDwwIwZM2piPMdRWx4f+DwQKGjLUQSkMSfmS/84dleuXFm24TYgdCFHDCGcMRcn4XYA/e5V1KxevbquDideVzDyp39CeOFGW7YH8aKmZcznBBwEN0UYfhMYyUNdfLf3339/WV8FHIEAZT637do3PiP7jvuBx3Bum4EKOPSD/YF9j3L9M0MBhzoURADLIUOGpDQjyBD9M8lt0+3APkBef39V55u4jMCvbV977bXkw7lQ6+gxy/XrcQlUwOGz8o6FCjiA35bmKeBwjtCRMD1OdfuZzp0LccxhJB3nZg2JSPT4Ub/mIfiwH8jChQvTEncKAH6j3B/8rnQfYr24FuRiuVvAGfMruR+1+vAjVlTA8dYN6+OHyBGgmTNnJrGj5RHcili/fn1Kow5OSjxhoC1OSgr70RMDYVkzAo5AKFBUaFkUcPjXic+Gk6gKuNySnwefLZZRnCJN0csLCPYl67IOR800Pq2W4/ab+hT6OapFo5hjOQWc9oOLIm5bgw8//DAJJoJ6vGiqD+AiiZEi9TWCdXBMUcDjVm9sq3mmuZw1a1Y54kUo4HLtmI7roF8vIlV1ckslluEYgiChKVif9hHbdlTAsUyPZSzxm9A+cgIOcL1V24762M+8FRfbqy+WMU8Bp+Wa5q1MCrhcPWwnQvcBbt/IkSNZLf2+x48fXyPgEKuZ+wgiCL9p/JYQNzyHfg4YzgVxW3L5KgGHtH5Higo4gHIEBWhWwAEu8ScBbenDHxcNlahge3Syf5RrHU3jlij//ESBr9cL9pH7o4Qlvy/1AZ471adYwBnzK/iBxPilvIgtWbKk7lmz3C1UCpN4C5UjKayLmMBIM597jo4+CAf8i1fYrjMEHE7imtd0TsCxTiMBB2GDtD4DpHXwPB/AKA//xcJP44UYF5vPPvsspfGPFWX4PCqkAPYR+4/Qj+cSNSyabg+AgENav7so0OKIX3zWkX3ps3RV26WwDj4b0mqxXjxG41LJCTj9DM8++2x5YVPiunN9x/U2UwfHEEZfaQpugeOi/fLLL6c82+B3gG0+FwGHSCoo1z9a+E3on4UqAcffdNW2s28S26svljEPAYfziQpwlGF/oH/SSMAhegyP19z6mFYBF0d4Qe58Q7RfbitGxlRk4ZjjuRLCBL5GAq6KKOA4at8RAad3M2JZ3IaYxz7FKBzRchxvvM2vjxIAPlZCMGKPtnG99PGOjZYBPDvHuzORHkxYwJlLndwPBMyZM6cs0xO3jiIR3l6MAq5qNIZ5FQp8wFlFXVU7CjjdLpbxxAd4cQLoX/uLt920rErAYbSHt+RAXBI+R6dlWOJfPsC/YAo4jsDhhMhbkRAXHBnk7SnA7QDcX3Hdcb14KFvFSiyHgOMzP7wFFgUctxF1du/enerrg864MEGc6rbg5MvbbODpp59Ot1Vy3xmeQyN4Hi7G4dV+yYQJE9LtQJaxX+yvpUuXprS20/T7779feTsXI5Z8cQCCGd85y3ERjbeUkNeH7FGfZVzGUQqAh/2V2Abg99ToOGUeD5Brnhd2/C6xbq4LZfxTw+e4cgKOzzuB3LaD+Jxbbj/wj0xumwEEXBx5JhgN4u37ZgUcxMO4cePKP6C8na2GP08Q8Io+k6gwH5cE+1D9WPLREaSbEXDxZYUo4AD2Bb6nZgXc8uXLa85BIKZjPoJHHhStg32Y82seo6f6cg39+G3jeMWoHL43HDc4p2idtrbNAs6YX8FbVfiR0AjS8bkcWO6Wowq4XF8URBQKEIeEdSn+VMDxgVoaT4AUcDgBsIzPWOiJDxc/bc/bdOqD0UeqBBzIteGStyvxGfD8SqzTSMCxjqZ5C1VP/DQ+G8MXAHgrjredYl80fVge6DNw9PHEyjYAF0c+r8O63J/M54QX++H3mvvOcBHTugAXJ16I8R2wDUZxCfI8HrVfLaepEIoCDv/29c3Dqj6iv9k6uv0wFQy0+L2QtvL00fBZAI6Z+JINljoqDRFc9RIDjiuQ2/Zc30zH44Z+NV7Y9Rk41seS5xGMToJmBZz6I/jDEdvTiL5wE+tqmueVWK5+LKsEHMQX8jQlJ+AA9muzAg4g/de//rUmT/C9M6/boXWigONzkXzphmAbkOf5R7cJeR4PcRS/UZp90SIWcMa0Qe6HYy4N9ILYnWnrGG2rvL1gSgh9gLstOnv9xjTLxXzsWcAZ0wD8+PXtO3Np0QoCDsfoc889F901XMiLGEZj2to+Y7oCHPe5tzcvFizgjDHGGGNaDAs4Y4wxxpgWwwLOGGOMMabFsIAz5ldiTDzmo1/nBMrBKQT0jc0In0mKfce8wnh/mJSyEXiLL8YIJHjLEa+uaxzWqrqN0DdkAeZ+wjxtOqN+R/oFMU6ktuU8X/gczfbN8maeA+O8WLFP5PG2W86vS8L4kHE/AdbFG2a5SBoAb4Zye2P8VF0X3tBrJj5mJH43eAMb6Dxq8TMxmkTVfsc8V3y7GOA74tuTbRGnkGDfuf3XFvGz5cBzUbFM85jaQSfP1ggeQOOk8q3xqs+KCb3xPWM6i4jubxC3KQfeWNbtidvWqI9mYv1G2tqfsZzHEsDbn5hWh+cFvMGpUSowv+bkyZPLfLPHDH4fcb1A3/6OE0UrmNZF59cD8+bNq8lrv1XxVWM5Y0O3BX/bcX8Q+DCHYZzAPWIBZ8yvvP322+Ur4ziJ6OS7evHHBLaNHoxtJl4hwTQO+pp8owsWtyGGwmkE6nIKCswJ9oc//CGlcVHhA/rN9qVoG6Q5jQZekcfcS7FOe8CFLheSStOYcuRPf/pT6W9ER7aj6ntBgHSGscLJl1NyaNQCwHXm1p3zNULrYzsoBOhnfNKOgukzYoSLOFegTqWwbt26Mk1QF0ISc/ixHfZf3C9VoI1erNiHbkN7aet3gu+R4vfzzz8vjzm2wfboXGaKRjgguc+KdpxLD98T59IjcdqPuJ4Iy9EPj//YJuaVZmL9RnL95XwgHks8T/L4xD7ln0f4KGDZX3uOGYXtMRUQyf0m0D/rMn4xxaVOio7pXXSakDg1CcC2azk+F84JjFfdDLo/CP4EcR/g+GzUlwWcMQJ+LLhI648GaVzQ+e+OAg7zTKGMRijgOM2CzsD9xz/+Mfli/xpJAGFstF+GmtI26BMXWV6kaBH1YURQJ5QlqIN+eKGhL/Ybg1ED7AsGhSfxpKxoe56kuL9hDGHDthBqDByvJzOcnDHygPUrOv+ehs7JLbEuRlLghVovcKiXi/CAvI6QEc5jh9BbcV3Y7xR+WsZ9hzSNaBqfFxeVOJktyM3gjjnOMA8V3v7kHHowHDcK5jjjdgG25+ggR2zo5whDDLWk28qRj9zFGO2wn7g9JIa1Yjr6tB3ET26uNQKfzjPHmJtaF2md6zBCfyxXAZeLXwkg2DQCANAQTYACLjexrX42HfEjiDUMHnjggVLUQxBAjM6ePbvsC3cMOJGw/ob5dj3zMPz5YjqGBySc+Dj6q44lRQULyvE7YlQWoMcMozjAMGFubp1AfVHAsU0M50ewzRwtVwGHevoHgAIuzuGm5SrEcO5hCD6cY1iX9avaaRmJ5YoFnDECJ1LV4fX4o8uNwOmPLgo4LYt9AcQMRZ4XZwo4gFs5uTaaBtjuW265pcaH7YijgWiHE5v64aMxliLBxYn95tYPUZu7BQBQB6MENPq0HOhs8Dx5s4xLxJNF4Ps42WouFmNMxyUFMScr1TIVcPF7IQx39cwzz9T4tS+GIor9Rx8EHCInUKTiuIuhpJjWvAI/b8VCMPCCASDgmNYRAxLzvEDRH5e4fYd0o/3OUd4qAcdjDMc2Ao4DCLhcfEouczE7IX54u02FA4jHPvphXziOKKQoDHIh6SA02b9+PtCMgEObtqZPidPU6Hqq0gDfs0YAQdQFoNvANoySoD5NYxkjMEDYIHIJffwN8ziN25Pz4XcNH+5kHDt2LPmigIPpsaTHDH2oz0gUcYJsPE6iE4CrgGN7/ePHZQ4eA7mYsRRwzOMPmeZzQgznF04OD2IsXpBrx7JmsIAzRuDtqNyJED9olKmAy92maSTgeLKPbRjBAaiAA/qjx4jQmDFj6v7Jx/4mTZpU51NytwQAfLwdis+pI1y5f9e4Fctn1nAiWrt2bc32RtTHNJ4dQZoGMLqgo1wsy4lFPLuit3CJttUlwEUcedTHvmRZvMWk3wvBRQLHh/YHeMtG/UjD4r97LiHg4iiNlhP+sYhgnQj3FH2MHsAROBK3Lca8xC0gxJ7Vz4JnGzlCGYlRNgBHhqoEnD7vxhFIRkXAevU3xWXcR0DFj8bcBXFfIY/nrYh+nlgX4LiuEj5Aj5NGAi4Xa1SpEnAYFYqjywSj+FFwoh3ij+p2IjIDy0gMsK5LoH9WKD61nEQf8vFYUjCahnNOFHAEf4bwvesxo79l/kHRZyxB3I6cgNO0+nCugvClj/uU+ZyAg4hlaC5GZGC5CjGcu/BHBYIz9/uraqdlzWABZ8yvQJTxZIwTzv79+1Naf1A48SOfu+VBGgm4+AMmzQq46ItpwBGiSHwmpK1+YzzXqnqaxgkpjuIouXZcasxCpnkRQzq25e08CgbQrIBDGvFpeZJmKKtmBBz7wcikxjPFfscFWQWKrpsBvtUHAQNRzttIEJN89o71QE7AQVDHB74xUqEjizoCp8+1YeQptiWow8+AsFq6XrwAwyDmeFmGt4m0DtMdEXAA7dkHlzpKiWfwsF1VAk63RX30Y5s58scyBb+TGJgcF+K4jaRKwMVbs/iTgboYTcTvBMR1az6XxjKOQgGIBZRhVFPBb0NjzVb1SToi4HLHUhSTGDVtJOC4D9sj4HLblRNwfNYN4LyunxF+9kkBh5FDGPYbyvHssP7hxZJCmD79XLhlTT/PYxgtxait9hHbEfyu9eUm1s1hAWfMr8QfSvyxqR8CDkHJkaaRKOD44CxMg6Er7RVwOOHhX17uGTh99kP9vIBz9Ij/mLW+Psgd2zO+qfoAn6thP0TTOR/TuC2a61fT06ZNqwndhAs6yvmcDGmPgMs949OWgOMIEdG2beXjdmDZ7DNwOQGnbVjGJUYKIAxxEdbnAvWirKafk300ysdbqHxWEMbvQI97GI7XZgRcjE9JtC/QSMDFulhqPGEll4/t6ecxriN4Oqoe20FsqU9vVeZGcTWv7eJtRxqJAdtJ9OlvjX8atE57BBz9TNN4LOXiqapg4eMhGje1WQFHMaSG4yoKOBpv60c/n4EFcVRTY8ZGARdfJGI5TUc68TwcfBgR1T5y7SjA1QeBXIUFnDFdAG6BxGekjFFwcsZtnK4EF2G9EF6qYF/H22+XAvjc5sKhwhqjkHfccUdthXPEAs6YLoC3SIzJgds6fG6vK8Efidybx5cauDWNEcBLiao5Bs35B7f8+VxqZ9Lj5KmzBcwCzhhjjDGmNbCAM8YYY4xpMSzgjDHGGGNaDAs4YwJ48JtvY/EB1KqHgWfMmFG+LXT77beXftbnW1Hvvvtu3TQeVbA/WHwrEvDtMMTI1LowRkHQt7S2bNlSttVJL1mO8EckTvzbFmhP8OYj8rk5uxQ8m8N1E7yxpmDiXsJ6Wl9hX7nyRhOpxvrI45kx9cc6Oj8a7fHHHy99kZwPaHvC/ac+TXNevFwdTIuRm5Igh7YFmNYiRqCgcQLWHLlytuM0EmpVL2zkPjfeRuTs+QRz98X53pRG095EUKZvE3NqjrjN7KOtvhRMFM22Q4cOLf3aJ48Z+pWYz6FvT4I4wTVM3yjFdCK5ftXHdpzvsWrKjypYh/3Q9HtRv/oUfPeYogbwTd04wbjSqC+8eaxvkBLm45Lwe8v9pjCVDohtcqCOGkFoOvq++eabsi7XhTeEWc4pqzi9kGIBZ0xABRzRH58Cv4Z/4iv0rN9RAUfi1BygSpSwHqbHQJoXV21PAYeL40svvliW82LWUQGHOfOYjtsbQTnmEsO0JtwnjQQcyfULH6NmYOJVnXwVVO0rgJMoXzbBFAR6ESRI89V+TJjL/ZOb2LZq+yKYGZ7TDOB40aklGE80fg7O7ceQSiiPc5XlLjY5cttE8D1QzOEi2qguyqJYhy+2iWIjwvr6uTVmJUG+MwWclse51eL0MVV9YfqUqrq48CLNUE3068TV9PPiDKFF8dKIuD3x2MU6GPIKQJDENjg30YfpgyDkAX3NHk+NwITiDLuGfvkmMOZ35Hrin1T6ISSrJj5XtAxpviyA8IfYfgo4fYmAbbiMc/jRn9sH7RFwStzOmMZSBTP+jOtbrBZwxjRB1QicGojhe0CMAxoFnLZnPVoMIaN1lJwoiX0qGLnhJLI6Dx1ODoyHSChQuE0w/TcYYzJyXdhfDFEFMG8bwGvzbBvnWQJs30jAsQ6XSvTFCBXcVxBJiBlJdCRNxSdgLE/EDdU5qvT7fv3119PJlnPJAdbDZLq5kTpGLVAQx5QCVPcf+9J+dB48+nTJiw2EAy+ULAO5iaWJzkenYNZ/CG0YwxnpemEUKDg2OO+ZogIOYoftGn1uXKwoSgjWTwHHPmDcR1UCTuuqDwKeE0U3K+D0u+X8XoiJTHJTtug6c35Nc5kboUNoN4RmAjF2bBRwhHkIOHyXEDVaFusDzjuWG4HjEvsg/kGMfeFPh/5pjeU8VwKeb3OjZSD2Q2Oe4HwTz9061xrJtY13J0AzAo5LhHqbPHlyjY9gm3TEN/dnHm2wLvye8NYqzts6QbIFnDFNUCXgCE6eMYQWLh40wDIVcFo/16/6MLLBIOR6gQNRwGEdEAJE+4yogMMoHD9HHIFjH7j9yvTdd99dGfoHS94KADkxGqdWQRlO8qCjAg7b1AjdV2yvF1x+fhWmOHFikmP4OYoCdP04AWPbMWM7R+NQjs/x9ddfl/W0Tdx+iGf6MDGx7j/6VcDhlrkStytecPE5EL0At59yIkmpEnAYDeJ0FDi244UUo5K6HZxgWaGA46TCBNtb9bl5saJopqDSETj8AVGhVSXgcnndZtCMgKv6bvV4iutUXyzDMa63oGM5Rq8Qxgzf3Z49e2r2Pc5BOkpZJeC4Dgg4RhYA+NOS+670Vms8noAej43OkTESA0DYKgARrOdKoH1EwYTjPn63AL8fRD3A/GqYkidGBeGSAk4j1MSlprHPOVGvij9alYBjufoARFgcZdSJryGsAdL47BTn+DOq0Tws4IxpgrYEHEI44ZkjBN7WERgQ63dUwEWfoqIE64//5nJtSC4SBC5WfMYkCjgGbQaYSbxKwGHUSrfrxV9vz8ZtI9i/+g9cZy4HPNmD3H4hOZ+i2xQDpZOYp4/+OXPmpNt7VZ9Ftw8jABB1sQxoe3z2eJs+Jzb1ghmfA9L1gnjBjRECiKZJFHAYBTh06FBx1113lfOnqZjXuhRZEBE5UUABh+eR4oUM5D43L1bIYzvojxEXlEZ5pDl6lStrRsDpd4vfAX5LMPzRuvnmm5M/N8rKdTXavqo8fTgOtJyRK7DEhOFVAo55Cjh91k+XAKHlEF2GxOMJ4LjA8YDwUvBB6CCgvNZhWkec6KvK4/yof5aIRkMAqIN9AdE2a9asJOCAho/DdwERxt+7jurhDx/SzGvfOFdrP6CZETgIMIy84TiAOMVIHB8FwG1p7S+HbgvWhcdLcrF6LeCMqUBPHjhB8GKpPy6ekHibBHm9CONkrvVBTsDh32J8Vk7T0YeLK7aPP+A4ChLB7bNcAGVAAccRJJZv3749pZsRcLyVpvX44DbASTA+96NpXPDjMyfYZr1FmGunPhJ9yMfvkuBigFufuTYR+PSijjxuqQI8S9NohBBLvfBxdE/XU7XOmOb2xwuBxjXlUi82+I60j1zfigo49M3QXbEdjkGO9rIM+xsCAaMujQScliGeKdNxHYDHOkftXn755ZSngEMcWg3JBdCWzznhdiPFFEYy4rNzus5cSKucgOMS+xi/Z8bMxLOIFHb6vQBciCEm2JaMHz++bp25vK5XR6FiXNZmBRzAb1j7JbFtTsABigsI8pzQwLmAsYWV2H/MYz/GWK6xDl4ag6AH+BwUcKjHuvwOePsx3pbVuurnCJ36mhFwfLkIo/Y41vB70998Lk4sR92AbktufzNtAWdMAxi4W4Oj64+Lz/dAyBD8+4QPlruoU5TghMYLKcu0nqbVp7dqeaHh9uGZMvZH47NPuKDQp7eoNJQLyym2AG+XwQ9w8mEan59vZ7GtPnPG2wL6AL6+jUiYj36c1OjTW5qsU9WOeb3A5b5LAF/VqKnC5+BIrMO4mlVimmksKRr5mfS7gfGZI72tQrR/PtAM0+1jfYgW3uLDZ6RYxwVN3+jUdbMtBRxgfFkY1483QHkhgr9qNC43UqnPsuFWIOrqSFXuc3MEF6gfoxv0qRHG69WR4lxdbQPiyxhVAi6mAUauFN4ah/FiD3QbcHxGYr/4fXOfIz4sxQqAgCT4Q5h7CxXHKIHQ4nOpKGMUEK5T28Fwh0GPJ9ZrJh370jq5cyCJvkZ9wD7//PPyDU2U586/AJ8j17cuCf746Mih7gOSE+SN0moEv0f68JtgXa6L511to78JYgFnTAUQTDoNgGltIBr0n6/5J7hIXGphpoy5GLCAM6YC3PIxFw94m9bUE9/cNca0BhZwxhhjjDEtxv8Dpr+22J5y+Y0AAAAASUVORK5CYII=>