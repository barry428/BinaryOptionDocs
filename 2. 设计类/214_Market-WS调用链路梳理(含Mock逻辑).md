# Market WebSocket调用链路梳理（含Mock和真实数据逻辑）

## 1. 架构概述

### 1.1 整体架构
```
前端/测试页面
    ↓ WebSocket连接
ws://localhost:8083/ws/market
    ↓
MarketWebSocketHandler (消息处理)
    ↓
MarketDataClient接口 (可配置数据源)
    ├── MockMarketDataClient (Mock数据生成)
    └── BtseMarketDataClient (真实BTSE数据)
    ↓
定时推送任务 (每500毫秒更新)
    ↓
JSON序列化 + WebSocket推送
```

### 1.2 服务端口与功能
- **market-service**: 端口8083
- **WebSocket端点**: `/ws/market`  
- **测试页面**: `http://localhost:8083/market-test.html`
- **REST API**: `/api/market/*`

## 2. 启动阶段调用链

### 2.1 Application.java 启动流程
```
Application.main()
    ↓
SpringApplication.run()
    ↓
Spring Boot 自动配置
    ├── @SpringBootApplication 扫描组件
    ├── @ComponentScan("com.binaryoption.marketservice", "com.binaryoption.commonutils")
    ├── @EnableDiscoveryClient 注册Nacos
    ├── @EnableFeignClients 启用RPC客户端  
    ├── @EnableCaching 启用缓存
    └── @MapperScan("com.binaryoption.marketservice.mapper") MyBatis扫描
```

### 2.2 配置类初始化顺序
```
1. WebSocketConfig.java
   └── registerWebSocketHandlers()
       └── 注册 /ws/market 端点 → MarketWebSocketHandler

2. JacksonConfig.java  
   └── objectMapper() Bean创建
       ├── registerModule(JavaTimeModule) - 支持LocalDateTime
       └── disable(WRITE_DATES_AS_TIMESTAMPS) - 使用ISO格式

3. MyBatisConfig.java
   └── databaseIdProvider() - MySQL/PostgreSQL双数据库支持

4. SwaggerConfig.java
   └── API文档配置
```

### 2.3 Service Bean初始化
```
MarketDataConfig配置加载:
    ├── @ConfigurationProperties("market.data")
    ├── Mock配置:
    │   ├── enabled: true/false
    │   ├── updateInterval: 500ms
    │   ├── priceVolatility: 0.04 (4%)
    │   └── symbols: 交易对和基础价格配置
    └── Real配置:
        └── btse: WebSocket和REST API配置

MarketDataClient Bean创建:
    ├── @ConditionalOnProperty("market.data.mock.enabled", "true")
    │   └── MockMarketDataClient
    └── @ConditionalOnProperty("market.data.mock.enabled", "false")
        └── BtseMarketDataClient (默认)

MockMarketDataClient @PostConstruct init():
    ├── 从配置加载交易对和基础价格
    ├── 初始化currentPrices和previousPrices
    └── 测试生成数据 - 验证Mock功能正常

BtseMarketDataClient @PostConstruct init():
    ├── initializeWebSocketConnection()
    ├── 连接到BTSE WebSocket
    └── initializeDefaultData() - 临时方案
```

## 3. WebSocket连接建立

### 3.1 连接建立流程
```
客户端连接请求: ws://localhost:8083/ws/market
    ↓
WebSocketConfig.addHandler() 路由
    ↓
MarketWebSocketHandler.afterConnectionEstablished()
    ├── sessions.add(session) - 添加到活跃连接集合
    ├── sessionSymbols.put(sessionId, new CopyOnWriteArraySet<>()) - 初始化订阅列表
    ├── 发送欢迎消息:
    │   └── {"type":"welcome","supportedSymbols":marketDataClient.getSupportedSymbols()}
    └── startMarketDataPush() - 启动全局推送任务 (只启动一次)
        └── scheduler.scheduleAtFixedRate(broadcastMarketData, 500, 500, MILLISECONDS)
```

### 3.2 连接状态管理
```java
// 线程安全的连接管理
private final Set<WebSocketSession> sessions = new CopyOnWriteArraySet<>();
private final Map<String, Set<String>> sessionSymbols = new ConcurrentHashMap<>();
private volatile boolean pushingStarted = false; // 防止重复启动推送
```

## 4. 实时数据推送循环

### 4.1 定时推送任务
```
每500毫秒执行 broadcastMarketData():
    ↓
1. 数据生成阶段:
   MarketDataClient.generateAllMarketTicks()
   ├── Mock模式: 遍历配置的交易对生成随机数据
   └── 真实模式: 从BTSE WebSocket缓存获取最新数据

2. 单个交易对数据生成:
   generateMarketTick(symbol):
   ├── 获取当前价格 currentPrices.get(symbol)
   ├── 生成价格波动: (-2% 到 +2%)  
   │   └── changePercent = (random() - 0.5) * 0.04
   ├── 计算新价格: currentPrice * (1 + changePercent)
   ├── 价格边界限制: basePrice ± 20%
   ├── 生成其他数据:
   │   ├── volume: 1000-50000 随机值
   │   ├── high24h: currentPrice * 1.05
   │   ├── low24h: currentPrice * 0.95  
   │   ├── change24h: newPrice - previousPrice
   │   └── changePercent24h: change24h / previousPrice * 100
   └── 构建 MarketTick 对象

3. 推送到客户端:
   ├── 检查会话是否存在且开启
   ├── 获取订阅列表 sessionSymbols.get(sessionId)
   ├── 数据过滤:
   │   ├── 无订阅 → 推送所有支持的交易对数据
   │   └── 有订阅 → 过滤后推送订阅的交易对
   ├── JSON序列化: objectMapper.writeValueAsString(ticks)
   └── WebSocket发送: sendMessage(session, jsonMessage)
```

### 4.2 数据格式详解
```json
{
  "type": "marketData",
  "data": [
    {
      "symbol": "BTCUSDT",
      "price": 45123.45,           // 当前价格
      "volume": 12345.67,          // 24h成交量  
      "high24h": 47379.62,         // 24h最高价
      "low24h": 42867.28,          // 24h最低价
      "change24h": 123.45,         // 24h价格变化
      "changePercent24h": 0.27,    // 24h涨跌幅%
      "timestamp": "2025-08-10 23:47:55"
    },
    // ... 其他7个交易对
  ]
}
```

## 5. 消息处理机制

### 5.1 客户端消息类型
```
handleTextMessage(session, message):
    ├── "subscribe:BTCUSDT" 
    │   ├── 解析交易对符号
    │   ├── sessionSymbols.get(sessionId).add(symbol)
    │   └── 响应: {"type":"subscribed","symbol":"BTCUSDT"}
    │
    ├── "unsubscribe:BTCUSDT"
    │   ├── sessionSymbols.get(sessionId).remove(symbol) 
    │   └── 响应: {"type":"unsubscribed","symbol":"BTCUSDT"}
    │
    ├── "ping"
    │   └── 响应: {"type":"pong","timestamp":1691234567890}
    │
    └── 其他消息
        └── 回显: {"type":"echo","message":"原消息内容"}
```

### 5.2 订阅管理逻辑
```java
// 推送时的订阅过滤
Set<String> subscribedSymbols = sessionSymbols.get(sessionId);

if (subscribedSymbols == null || subscribedSymbols.isEmpty()) {
    // 推送所有交易对数据
    sendMessage(session, allMarketData);
} else {
    // 只推送订阅的交易对
    List<MarketTick> filteredTicks = allTicks.stream()
        .filter(tick -> subscribedSymbols.contains(tick.getSymbol()))
        .toList();
    sendMessage(session, filteredData);
}
```

## 6. Mock数据生成详解

### 6.1 价格生成算法
```java
// 价格波动生成
private MarketTick generateMarketTick(String symbol) {
    BigDecimal basePrice = basePrices.get(symbol);        // 基础价格
    BigDecimal currentPrice = currentPrices.get(symbol);  // 当前价格
    
    // 1. 生成随机波动 (-2% 到 +2%)
    double changePercent = (ThreadLocalRandom.current().nextDouble() - 0.5) * 0.04;
    
    // 2. 计算新价格
    BigDecimal newPrice = currentPrice.multiply(BigDecimal.ONE.add(BigDecimal.valueOf(changePercent)));
    
    // 3. 边界控制 (基础价格的80%-120%)
    BigDecimal maxPrice = basePrice.multiply(new BigDecimal("1.20"));
    BigDecimal minPrice = basePrice.multiply(new BigDecimal("0.80"));
    
    if (newPrice.compareTo(maxPrice) > 0) newPrice = maxPrice;
    if (newPrice.compareTo(minPrice) < 0) newPrice = minPrice;
    
    // 4. 更新价格历史
    previousPrices.put(symbol, currentPrice);
    currentPrices.put(symbol, newPrice);
    
    return MarketTick.builder()
        .symbol(symbol)
        .price(newPrice)
        .volume(generateVolume())      // 1000-50000随机
        .high24h(currentPrice.multiply(new BigDecimal("1.05")))
        .low24h(currentPrice.multiply(new BigDecimal("0.95")))
        .change24h(newPrice.subtract(previousPrice))
        .changePercent24h(calculatePercentChange(newPrice, previousPrice))
        .timestamp(LocalDateTime.now())
        .build();
}
```

### 6.2 数据精度处理
```java
// 根据交易对设置价格精度
private int getPriceScale(String symbol) {
    if (symbol.contains("BTC") || symbol.contains("ETH")) {
        return 2; // BTC/ETH 使用2位小数
    } else if (symbol.contains("BNB") || symbol.contains("DOT")) {
        return 2; // 主流币种使用2位小数  
    } else {
        return 4; // 小币种使用4位小数 (ADA, DOGE, XRP等)
    }
}

// 成交量生成
private BigDecimal generateVolume() {
    double volume = ThreadLocalRandom.current().nextDouble(1000, 50000);
    return BigDecimal.valueOf(volume).setScale(2, RoundingMode.HALF_UP);
}
```

## 7. JSON序列化配置

### 7.1 Jackson配置
```java
@Configuration
public class JacksonConfig {
    @Bean
    @Primary
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        // 支持Java 8时间类型
        mapper.registerModule(new JavaTimeModule());
        // 时间格式为ISO字符串而非时间戳
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        return mapper;
    }
}
```

### 7.2 时间格式处理
```java
// MarketTick中的时间注解
@JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
private LocalDateTime timestamp;

// 序列化结果
"timestamp": "2025-08-10 23:47:55"
```

## 8. 连接生命周期管理

### 8.1 连接建立
```
afterConnectionEstablished(WebSocketSession session):
    ├── sessions.add(session) - 添加到活跃连接池
    ├── sessionSymbols.put(sessionId, new Set<>()) - 初始化订阅
    ├── log.info("连接建立: {}, 当前连接数: {}", sessionId, sessions.size())
    ├── 发送欢迎消息 (包含支持的交易对列表)
    └── startMarketDataPush() - 确保推送服务启动
```

### 8.2 连接异常处理
```
handleTransportError(WebSocketSession session, Throwable exception):
    ├── log.error("传输错误: {}", sessionId, exception)
    ├── sessions.remove(session)
    └── sessionSymbols.remove(sessionId)

sendMessage(session, message) 异常处理:
    ├── 检查 session.isOpen()
    ├── 捕获 IOException
    ├── 自动关闭异常连接: session.close()
    └── 从连接池移除: sessions.remove(session)
```

### 8.3 连接关闭清理
```
afterConnectionClosed(WebSocketSession session, CloseStatus status):
    ├── sessions.remove(session) - 从活跃连接移除
    ├── sessionSymbols.remove(sessionId) - 清理订阅数据
    └── log.info("连接关闭: {}, 当前连接数: {}", sessionId, sessions.size())
```

## 9. 配置化数据源架构

### 9.1 MarketDataClient接口设计
```java
public interface MarketDataClient {
    Set<String> getSupportedSymbols();           // 获取支持的交易对
    MarketTick generateMarketTick(String symbol); // 生成单个交易对数据
    List<MarketTick> generateAllMarketTicks();    // 生成所有交易对数据
    BigDecimal getCurrentPrice(String symbol);    // 获取当前价格
    boolean isHealthy();                          // 健康检查
    String getDataSourceType();                  // 数据源类型
}
```

### 9.2 配置文件示例
```yaml
# application.yml
market:
  data:
    mock:
      enabled: true                    # 启用Mock模式
      updateInterval: 500             # 更新间隔(毫秒)
      priceVolatility: 0.04          # 价格波动率(4%)
      symbols:                        # 交易对配置
        - symbol: BTCUSDT
          basePrice: 45000.00
        - symbol: ETHUSDT
          basePrice: 2800.00
        - symbol: BNBUSDT
          basePrice: 320.00
    real:
      btse:
        websocketUrl: wss://ws.btse.com/ws/oss/futures
        restApiUrl: https://api.btse.com
        timeout: 10000
        reconnect:
          maxAttempts: 3
          delay: 5000
```

### 9.3 条件Bean创建
```java
@Component
@Primary
@ConditionalOnProperty(name = "market.data.mock.enabled", havingValue = "true")
public class MockMarketDataClient implements MarketDataClient {
    // Mock实现
}

@Component
@Primary  
@ConditionalOnProperty(name = "market.data.mock.enabled", havingValue = "false", matchIfMissing = true)
public class BtseMarketDataClient implements MarketDataClient {
    // 真实BTSE数据实现
}
```

### 9.4 数据源切换
- **Mock模式**: `market.data.mock.enabled=true`
  - 使用配置的交易对和价格生成随机波动数据
  - 适合开发测试和演示
  - 数据源类型: "MOCK"

- **真实模式**: `market.data.mock.enabled=false` (默认)
  - 连接BTSE WebSocket获取真实市场数据
  - 适合生产环境
  - 数据源类型: "BTSE_REAL"

## 10. 性能与监控

### 10.1 线程安全设计
```java
// 线程安全的数据结构选择
private final Set<WebSocketSession> sessions = new CopyOnWriteArraySet<>();
private final Map<String, Set<String>> sessionSymbols = new ConcurrentHashMap<>();
private final Map<String, BigDecimal> currentPrices = new ConcurrentHashMap<>();

// 防止重复启动推送任务
private volatile boolean pushingStarted = false;
private synchronized void startMarketDataPush() { ... }
```

### 10.2 资源管理
```java
// 线程池配置
private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);

// 推送频率控制
scheduler.scheduleAtFixedRate(this::broadcastMarketData, 500, 500, TimeUnit.MILLISECONDS);

// 内存管理
private final Map<String, BigDecimal> currentPrices = new ConcurrentHashMap<>();  // 最大8个元素
private final Map<String, BigDecimal> previousPrices = new ConcurrentHashMap<>(); // 最大8个元素
```

### 10.3 日志监控
```java
// 关键节点日志
log.info("WebSocket连接建立: {}, 当前连接数: {}", session.getId(), sessions.size());
log.info("市场数据推送服务已启动");
log.debug("生成行情数据 {} 条", allTicks.size());
log.error("向会话 {} 发送市场数据时发生错误", session.getId(), e);
```

## 11. 测试与验证

### 11.1 测试页面功能
**URL**: `http://localhost:8083/market-test.html`

**功能**:
- WebSocket连接状态显示
- 实时行情数据展示 (价格、涨跌幅、成交量等)
- 订阅/取消订阅功能测试
- ping/pong延迟测试  
- 消息日志记录

### 11.2 手动测试方式
```javascript
// JavaScript客户端测试
const ws = new WebSocket('ws://localhost:8083/ws/market');

ws.onopen = () => console.log('连接成功');
ws.onmessage = (event) => console.log('收到:', JSON.parse(event.data));

// 订阅测试
ws.send('subscribe:BTCUSDT');
ws.send('ping');
```

### 11.3 REST API测试
```bash
# 获取支持的交易对
curl http://localhost:8083/api/market/symbols

# 获取实时价格  
curl http://localhost:8083/api/market/price/BTCUSDT

# 健康检查
curl http://localhost:8083/actuator/health
```

## 12. 扩展点与优化

### 12.1 可扩展功能
- **真实数据源接入**: 替换Mock为真实BTSE WebSocket
- **数据持久化**: 价格历史存储到数据库
- **更多交易对**: 动态配置支持的交易对
- **深度数据**: 买卖盘口数据推送
- **技术指标**: MA、MACD、RSI等指标计算

### 12.2 性能优化方向
- **数据压缩**: 启用WebSocket压缩
- **连接池**: 优化连接数限制和清理策略
- **批量推送**: 减少推送频率，批量发送数据
- **缓存策略**: Redis缓存热点数据

## 13. 故障排查

### 13.1 常见问题
1. **空数据推送**: 检查MarketDataClient初始化和配置
2. **JSON序列化失败**: 检查JacksonConfig配置
3. **连接频繁断开**: 检查心跳机制
4. **内存泄漏**: 检查连接清理逻辑

### 13.2 调试建议
```bash
# 启用DEBUG日志
logging.level.com.binaryoption.marketservice=DEBUG

# 监控关键指标
- 当前连接数: sessions.size()
- 推送任务状态: pushingStarted
- 异常计数: WebSocket传输错误
```

---

**更新日志**:
- 2025-08-11: 新增配置化数据源架构，支持Mock和真实BTSE数据切换
- 2025-08-10: 初始版本，基于MockMarketDataService

*最后更新: 2025-08-11*  
*作者: Claude Assistant*