-- ============================================
-- 订单列表展示优化 - 数据库迁移脚本
-- 版本: v5.2
-- 日期: 2025-11-25
-- 作者: Barry & Claude
-- ============================================

-- ============================================
-- 第一部分：bo_user_round 表优化
-- ============================================

-- 1.1 添加冗余字段 round_end_time 和 symbol_id
ALTER TABLE bo_user_round
ADD COLUMN round_end_time TIMESTAMP,
ADD COLUMN symbol_id BIGINT;

COMMENT ON COLUMN bo_user_round.symbol_id IS '交易对ID（冗余字段，避免JOIN查询，便于按symbol过滤）';

-- 1.2 初始化现有数据的 round_end_time 和 symbol_id（从 bo_trading_round 表同步）
UPDATE bo_user_round ur
SET round_end_time = tr.end_time,
    symbol_id = tr.symbol_id
FROM bo_trading_round tr
WHERE ur.round_id = tr.id
  AND ur.round_end_time IS NULL;

-- 1.3 删除旧索引（不再使用）
DROP INDEX IF EXISTS idx_round_users;           -- (round_id, account_type)
DROP INDEX IF EXISTS idx_user_round_query;      -- (user_id, account_type, last_settle_time DESC)

-- 1.4 创建新索引 - 当前订单（未结束的轮次，支持symbol过滤）
CREATE INDEX idx_user_round_active
ON bo_user_round(user_id, account_type, symbol_id, round_id);

COMMENT ON INDEX idx_user_round_active IS '当前订单查询索引：支持按user_id、account_type、symbol_id查询未结束的轮次';

-- 1.5 创建新索引 - 历史订单（已结束的轮次，倒序排序，支持symbol过滤）
CREATE INDEX idx_user_round_history_sort
ON bo_user_round(user_id, account_type, symbol_id, round_end_time DESC, round_id ASC);

COMMENT ON INDEX idx_user_round_history_sort IS '历史订单查询索引：支持按user_id、account_type、symbol_id查询已结束的轮次并按时间倒序排序';


-- ============================================
-- 第二部分：bo_option_order 表优化
-- ============================================

-- 2.1 添加 symbol_id 字段（避免JOIN bo_trading_round表）
ALTER TABLE bo_option_order
ADD COLUMN symbol_id BIGINT;

COMMENT ON COLUMN bo_option_order.symbol_id IS '交易对ID（冗余字段，避免JOIN查询）';

-- 2.2 初始化现有数据的 symbol_id（从 bo_trading_round 表同步）
UPDATE bo_option_order o
SET symbol_id = tr.symbol_id
FROM bo_trading_round tr
WHERE o.round_id = tr.id
  AND o.symbol_id IS NULL;

-- 2.3 添加非空约束（确保数据完整性）
ALTER TABLE bo_option_order
ALTER COLUMN symbol_id SET NOT NULL;

-- 2.4 创建 symbol_id 索引
CREATE INDEX idx_order_symbol
ON bo_option_order(symbol_id);

COMMENT ON INDEX idx_order_symbol IS '按交易对查询订单索引';


-- ============================================
-- 第三部分：bo_option_order 表分区策略
-- ============================================

-- 注意：如果表中已有数据，需要先迁移数据到分区表
-- 以下SQL适用于新表或空表的情况

-- 3.1 创建分区主表（如果是新表）
-- 如果是已有表，需要使用 pg_partman 或手动迁移数据
/*
CREATE TABLE bo_option_order (
    id BIGSERIAL NOT NULL,
    user_id BIGINT NOT NULL,
    round_id BIGINT NOT NULL,
    symbol_id BIGINT NOT NULL,
    account_type VARCHAR(10) NOT NULL,
    direction VARCHAR(10) NOT NULL,
    amount NUMERIC(20, 8) NOT NULL,
    odds NUMERIC(20, 15) NOT NULL,
    expected_profit NUMERIC(20, 8),
    order_price NUMERIC(20, 8),
    settle_price NUMERIC(20, 8),
    status VARCHAR(20) NOT NULL,
    fee NUMERIC(20, 8),
    actual_profit NUMERIC(20, 8),
    client_ip VARCHAR(50),
    user_agent VARCHAR(255),
    create_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    settle_time TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_option_order PRIMARY KEY (id, create_time)
) PARTITION BY RANGE (create_time);

COMMENT ON TABLE bo_option_order IS '期权订单表（按月分区）';
*/

-- 3.2 创建月度分区（示例：当前月和未来3个月）
CREATE TABLE IF NOT EXISTS bo_option_order_y2025m11 PARTITION OF bo_option_order
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');

CREATE TABLE IF NOT EXISTS bo_option_order_y2025m12 PARTITION OF bo_option_order
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS bo_option_order_y2026m01 PARTITION OF bo_option_order
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE IF NOT EXISTS bo_option_order_y2026m02 PARTITION OF bo_option_order
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- 3.3 在每个分区上创建索引
-- 当前月分区索引
CREATE INDEX IF NOT EXISTS idx_order_user_y2025m11
ON bo_option_order_y2025m11(user_id, account_type, status);

CREATE INDEX IF NOT EXISTS idx_order_round_y2025m11
ON bo_option_order_y2025m11(round_id);

CREATE INDEX IF NOT EXISTS idx_order_symbol_y2025m11
ON bo_option_order_y2025m11(symbol_id);

-- 下个月分区索引
CREATE INDEX IF NOT EXISTS idx_order_user_y2025m12
ON bo_option_order_y2025m12(user_id, account_type, status);

CREATE INDEX IF NOT EXISTS idx_order_round_y2025m12
ON bo_option_order_y2025m12(round_id);

CREATE INDEX IF NOT EXISTS idx_order_symbol_y2025m12
ON bo_option_order_y2025m12(symbol_id);

-- 3.4 创建自动分区函数
CREATE OR REPLACE FUNCTION create_next_month_partition()
RETURNS void AS $$
DECLARE
    next_month DATE := date_trunc('month', CURRENT_DATE) + interval '2 month';
    partition_name TEXT := 'bo_option_order_y' || to_char(next_month, 'YYYYmMM');
    start_date DATE := next_month;
    end_date DATE := next_month + interval '1 month';
BEGIN
    -- 创建分区表
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF bo_option_order FOR VALUES FROM (%L) TO (%L)',
        partition_name, start_date, end_date);

    -- 创建索引
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_order_user_%s ON %I(user_id, account_type, status)',
        to_char(next_month, 'YYYYmMM'), partition_name);

    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_order_round_%s ON %I(round_id)',
        to_char(next_month, 'YYYYmMM'), partition_name);

    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_order_symbol_%s ON %I(symbol_id)',
        to_char(next_month, 'YYYYmMM'), partition_name);

    RAISE NOTICE 'Created partition % for date range % to %', partition_name, start_date, end_date;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_next_month_partition() IS '自动创建下月分区表和索引';

-- 3.5 创建定时任务（使用 pg_cron 扩展，需要预先安装）
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('create-partition', '0 0 1 * *', 'SELECT create_next_month_partition()');


-- ============================================
-- 第四部分：验证查询
-- ============================================

-- 4.1 验证当前订单查询（不带symbol过滤）
EXPLAIN ANALYZE
SELECT ur.round_id
FROM bo_user_round ur
WHERE ur.user_id = 1
  AND ur.account_type = 'REAL'
  AND (ur.round_end_time IS NULL OR ur.round_end_time >= CURRENT_TIMESTAMP)
ORDER BY ur.round_id;

-- 4.2 验证当前订单查询（带symbol过滤）
EXPLAIN ANALYZE
SELECT ur.round_id
FROM bo_user_round ur
WHERE ur.user_id = 1
  AND ur.account_type = 'REAL'
  AND ur.symbol_id = 1
  AND (ur.round_end_time IS NULL OR ur.round_end_time >= CURRENT_TIMESTAMP)
ORDER BY ur.round_id;

-- 4.3 验证历史订单查询（不带时间区间）
EXPLAIN ANALYZE
SELECT ur.round_id
FROM bo_user_round ur
WHERE ur.user_id = 1
  AND ur.account_type = 'REAL'
  AND ur.round_end_time < CURRENT_TIMESTAMP
ORDER BY ur.round_end_time DESC, ur.round_id ASC
LIMIT 10;

-- 4.4 验证历史订单查询（带symbol过滤）
EXPLAIN ANALYZE
SELECT ur.round_id
FROM bo_user_round ur
WHERE ur.user_id = 1
  AND ur.account_type = 'REAL'
  AND ur.symbol_id = 1
  AND ur.round_end_time < CURRENT_TIMESTAMP
ORDER BY ur.round_end_time DESC, ur.round_id ASC
LIMIT 10;

-- 4.5 验证历史订单查询（带时间区间和symbol过滤）
EXPLAIN ANALYZE
SELECT ur.round_id
FROM bo_user_round ur
WHERE ur.user_id = 1
  AND ur.account_type = 'REAL'
  AND ur.symbol_id = 1
  AND ur.round_end_time < CURRENT_TIMESTAMP
  AND ur.round_end_time >= '2025-11-01 00:00:00'
  AND ur.round_end_time <= '2025-11-25 23:59:59'
ORDER BY ur.round_end_time DESC, ur.round_id ASC
LIMIT 10;

-- 4.6 验证订单批量查询
EXPLAIN ANALYZE
SELECT id, user_id, round_id, symbol_id, direction, amount, odds, status, create_time
FROM bo_option_order
WHERE user_id = 1
  AND account_type = 'REAL'
  AND round_id IN (12345, 12346, 12347, 12348, 12349)
ORDER BY round_id, create_time DESC;

-- 4.7 验证统计查询（不带symbol过滤）
EXPLAIN ANALYZE
SELECT COUNT(DISTINCT ur.round_id)
FROM bo_user_round ur
WHERE ur.user_id = 1
  AND ur.account_type = 'REAL'
  AND ur.round_end_time < CURRENT_TIMESTAMP;

-- 4.8 验证统计查询（带symbol过滤）
EXPLAIN ANALYZE
SELECT COUNT(DISTINCT ur.round_id)
FROM bo_user_round ur
WHERE ur.user_id = 1
  AND ur.account_type = 'REAL'
  AND ur.symbol_id = 1
  AND ur.round_end_time < CURRENT_TIMESTAMP;


-- ============================================
-- 第五部分：数据维护
-- ============================================

-- 5.1 分析表统计信息
ANALYZE bo_user_round;
ANALYZE bo_option_order;

-- 5.2 查看索引使用情况
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND tablename IN ('bo_user_round', 'bo_option_order')
ORDER BY tablename, indexname;

-- 5.3 查看表大小
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as indexes_size
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('bo_user_round', 'bo_option_order')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;


-- ============================================
-- 第六部分：回滚脚本（如果需要）
-- ============================================

/*
-- 回滚步骤1: 删除新索引
DROP INDEX IF EXISTS idx_user_round_active;
DROP INDEX IF EXISTS idx_user_round_history_sort;

-- 回滚步骤2: 恢复旧索引
CREATE INDEX idx_round_users ON bo_user_round(round_id, account_type);
CREATE INDEX idx_user_round_query ON bo_user_round(user_id, account_type, last_settle_time DESC);

-- 回滚步骤3: 删除新字段
ALTER TABLE bo_user_round DROP COLUMN IF EXISTS round_end_time;
ALTER TABLE bo_option_order DROP COLUMN IF EXISTS symbol_id;

-- 回滚步骤4: 删除自动分区函数
DROP FUNCTION IF EXISTS create_next_month_partition();
*/


-- ============================================
-- 执行完成提示
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '订单优化数据库迁移脚本执行完成';
    RAISE NOTICE '版本: v5.2';
    RAISE NOTICE '日期: 2025-11-25';
    RAISE NOTICE '========================================';
    RAISE NOTICE '请执行以下操作:';
    RAISE NOTICE '1. 检查验证查询的执行计划是否使用了正确的索引';
    RAISE NOTICE '2. 更新应用程序代码实现新的查询逻辑';
    RAISE NOTICE '3. 配置定时任务自动创建未来月份的分区';
    RAISE NOTICE '4. 监控查询性能和索引使用情况';
    RAISE NOTICE '========================================';
END $$;
