-- 用户轮次参与记录表 DDL脚本
-- 用于优化用户历史轮次查询性能

-- 创建表
CREATE TABLE user_round (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    round_id BIGINT NOT NULL,
    account_type VARCHAR(10) NOT NULL,  -- DEMO/REAL
    first_order_time TIMESTAMP NOT NULL,  -- 首次下单时间
    last_settle_time TIMESTAMP,           -- 最后结算时间
    total_orders INTEGER DEFAULT 0,       -- 该轮次订单数
    total_amount DECIMAL(18,8) DEFAULT 0, -- 总投注金额
    net_profit DECIMAL(18,8) DEFAULT 0,   -- 净盈亏
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 联合唯一索引，保证用户在同一轮次同一账户类型只有一条记录
    UNIQUE(user_id, round_id, account_type)
);

-- 主要查询索引：支持用户历史轮次查询和分页
CREATE INDEX idx_user_round_query ON user_round(user_id, account_type, last_settle_time DESC);

-- 轮次查询索引：支持按轮次查询参与用户
CREATE INDEX idx_round_users ON user_round(round_id, account_type);

-- 添加表注释
COMMENT ON TABLE user_round IS '用户轮次参与记录表，用于优化历史轮次查询性能';
COMMENT ON COLUMN user_round.user_id IS '用户ID';
COMMENT ON COLUMN user_round.round_id IS '轮次ID';
COMMENT ON COLUMN user_round.account_type IS '账户类型：DEMO/REAL';
COMMENT ON COLUMN user_round.first_order_time IS '用户在该轮次的首次下单时间';
COMMENT ON COLUMN user_round.last_settle_time IS '该轮次最后结算时间，用于排序分页';
COMMENT ON COLUMN user_round.total_orders IS '用户在该轮次的订单总数';
COMMENT ON COLUMN user_round.total_amount IS '用户在该轮次的总投注金额';
COMMENT ON COLUMN user_round.net_profit IS '用户在该轮次的净盈亏';

-- 性能验证查询
-- 原来的复杂查询（性能差）
/*
EXPLAIN ANALYZE 
SELECT DISTINCT round_id FROM option_order 
WHERE user_id = 1 AND account_type = 'DEMO' AND status IN ('WIN', 'LOSE')
GROUP BY round_id ORDER BY MAX(settle_time) DESC 
LIMIT 10 OFFSET 0;
*/

-- 新的高效查询（性能优）
/*
EXPLAIN ANALYZE 
SELECT round_id FROM user_round 
WHERE user_id = 1 AND account_type = 'DEMO' AND last_settle_time IS NOT NULL
ORDER BY last_settle_time DESC 
LIMIT 10 OFFSET 0;
*/