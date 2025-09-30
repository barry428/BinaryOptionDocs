# Redis Key Management Guide

## Overview
This guide explains how to use the centralized Redis key management system in the Binary Option project.

## Why Centralized Key Management?

1. **Avoid Key Conflicts**: Prevents different modules from using the same Redis keys
2. **Maintainability**: All keys are defined in one place
3. **Documentation**: Easy to see all Redis keys used in the system
4. **Consistency**: Enforces naming conventions across the project

## Key Location

All Redis keys and cache constants are defined in:
```
option-common-utils/src/main/java/com/binaryoption/commonutils/constants/CacheConstants.java
```

This file contains both compile-time constants for Spring Cache annotations and dynamic key builders for Redis operations.

## Naming Convention

- Use colon (`:`) as separator
- Start with project prefix `bo` (Binary Option)
- Follow pattern: `prefix:module:feature:identifier`
- Use lowercase with underscores for multi-word identifiers

Examples:
- `bo:order:settlement:task`
- `bo:user:mapping:{username}`
- `bo::symbols::active_v2`

## How to Use

### 1. Import the Constants Class

```java
import com.binaryoption.commonutils.constants.CacheConstants;
```

### 2. Use in Code

#### For Simple Keys
```java
// Instead of hardcoding:
String key = "BO:User:Mapping:" + username;

// Use:
String key = CacheConstants.buildUserMappingKey(username);
```

#### For Cache Keys
```java
// Instead of:
redisTemplate.opsForValue().set("OAuth:AccessToken:" + token, data);

// Use:
redisTemplate.opsForValue().set(
    CacheConstants.buildOAuthTokenKey(token), 
    data
);
```

### 3. Spring Cache Annotations

For Spring Cache annotations (@Cacheable, @CacheEvict), the keys need to be compile-time constants.

Current usage in code:
```java
@Cacheable(value = "bo::symbols", key = "'active_v2'")
```

These correspond to constants in CacheConstants:
- `CACHE_SYMBOLS = "bo:symbols"`  
- `CACHE_KEY_SYMBOLS_ACTIVE = "'active_v2'"`

### 4. Distributed Lock Annotations

For @DistributedScheduled annotations, the lockKey must be a compile-time constant:

```java
@DistributedScheduled(
    lockKey = CacheConstants.LOCK_ORDER_SETTLEMENT,  // Use the constant directly
    expireTime = 50,
    timeUnit = TimeUnit.SECONDS
)
```

## Key Categories

### User & Authentication
- **User Mapping**: `BO:User:Mapping:{username}`
- **OAuth Tokens**: `OAuth:AccessToken:{token}`

### Cache Keys
- **Symbol Cache**: `bo::symbols::active_v2`, `bo::symbol::v2_{symbol}`
- **Config Cache**: `config:{type}:{key}`
- **Risk Config**: `risk:{type}:{key}`

### Distributed Locks
- **Scheduled Tasks**: 
  - `bo:order:settlement:task`
  - `bo:order:hedge:compensation:task`
  - `bo:trading:round:maintenance:task`
  - `bo:user:risk:stats:reset:task`
  - `bo:btse:transfer:in:compensation:task`
  - `bo:btse:transfer:out:compensation:task`
- **Generic Locks**: `lock:{feature}:{identifier}`

### Market Data
- **Market Tick**: `market:tick:{symbol}`
- **K-line Data**: `market:kline:{symbol}:{period}`

### Session & Temporary
- **Session**: `session:{userId}:{sessionId}`
- **Temporary**: `temp:{feature}:{identifier}`

### Rate Limiting
- **API Rate Limit**: `rate_limit:{api}:{userId/ip}`

## Adding New Keys

When adding new Redis keys:

1. **Define in CacheConstants.java**:
```java
String MY_NEW_KEY_PREFIX = PROJECT_PREFIX + ":myfeature:";
```

2. **Add Builder Method** (if parameterized):
```java
static String buildMyNewKey(String param) {
    return MY_NEW_KEY_PREFIX + param;
}
```

3. **Document the Pattern**:
```java
/**
 * My feature cache key
 * Pattern: bo:myfeature:{identifier}
 */
```

## Migration Checklist

When migrating existing code to use CacheConstants:

- [x] Search for hardcoded Redis keys in your module
- [x] Check for patterns like: `"cache:"`, `"lock:"`, `"bo:"`, `"BO:"`, `"OAuth:"`, `"auth:"`
- [x] Replace with appropriate constants or builder methods
- [x] Test to ensure keys are generated correctly
- [x] Update any documentation

## Completed Migration (2025-09-17)

All Redis keys have been successfully centralized:

### Updated Files:
- `option-gateway/src/main/java/com/binaryoption/gateway/filter/OAuthTokenFilter.java`
- `option-order-service/src/main/java/com/binaryoption/orderservice/service/ScheduledTaskService.java`
- `option-common-service/src/main/java/com/binaryoption/commonservice/service/BtseTransferScheduledTaskService.java`
- `option-security-base/src/main/java/com/binaryoption/securitybase/cache/PermissionCacheService.java`
- `option-order-service/src/main/java/com/binaryoption/orderservice/service/SymbolService.java`
- `option-common-service/src/main/java/com/binaryoption/commonservice/rpc/UserRpcController.java`

### Added Constants:
- OAuth token keys: `OAUTH_TOKEN_PREFIX`
- User mapping keys: `USER_MAPPING_PREFIX`
- Distributed lock keys: All scheduled task locks
- Authentication keys: `USER_PERMISSIONS_PREFIX`, `USER_ROLES_PREFIX`
- Cache keys: Symbol and configuration caches

## Common Patterns to Search

```bash
# Find hardcoded Redis keys
grep -r '".*:.*"' --include="*.java" | grep -E '(cache|lock|bo|BO|OAuth|redis|Redis)'

# Find @Cacheable annotations
grep -r '@Cacheable' --include="*.java"

# Find @DistributedScheduled annotations  
grep -r '@DistributedScheduled' --include="*.java"
```

## Testing

After migration, verify:
1. Redis keys are created with correct format
2. No key conflicts between modules
3. Cache operations work correctly
4. Distributed locks function properly

## Notes

- Some annotations (like @Cacheable and @DistributedScheduled) require compile-time constants
- For these cases, use the constants directly from CacheConstants interface
- All constants are now centralized in a single file for better maintainability
- Consider adding unit tests to verify key generation

## Consolidation Update (2025-09-17)

**Important**: RedisKeyConstants.java has been merged into CacheConstants.java to eliminate duplication:
- All Redis key constants are now in `CacheConstants.java`
- All import statements updated from `RedisKeyConstants` to `CacheConstants`
- Single source of truth for all cache and Redis key management
- Maintained backward compatibility for all existing functionality