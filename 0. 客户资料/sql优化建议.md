Binary Options Platform Database Optimization Strategy
Observations
1. Implement hash partitioning - Single large tables handling high QPS
2. Suboptimal existing indexes - Many high-frequency queries not optimized
3. Missing covering indexes - Frequent table lookups for UI queries
Detailed Index Optimization Strategy
1. Account Table Optimizations
Current Schema:
Critical Query from SQL Documentation (59 QPS):
Atomic Update Query (22 QPS):
sql
CREATE TABLE public.account (
id bigint NOT NULL,
user_id bigint NOT NULL,
account_type character varying(16) NOT NULL,
currency character varying(8) DEFAULT 'USDT'::character varying NOT NULL,
balance numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
frozen_balance numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
-- ... other fields
);
-- Existing index
CREATE INDEX idx_account_user_id ON public.account USING btree (user_id);
sql
-- AccountMapper.findByUserIdAndAccountType - HIGHEST FREQUENCY
SELECT id, user_id, account_type, currency, balance, frozen_balance,
total_deposit, total_withdraw, total_profit, total_loss,
reset_count, last_reset_time, create_time, update_time
FROM account
WHERE user_id = #{userId}
AND account_type = #{accountType}
sql
Problem: Current idx_account_user_id doesn't include account_type - requires table lookup
Solution - New Indexes:
2. Option Order Table Optimizations
Current Schema:
Critical Queries from SQL Documentation:
-- AccountMapper.atomicBalanceChange - CRITICAL PERFORMANCE
UPDATE account
SET balance = balance + #{balanceChange},
frozen_balance = frozen_balance + #{frozenChange},
update_time = CURRENT_TIMESTAMP
WHERE id = #{id}
AND balance + #{balanceChange} >= 0
AND frozen_balance + #{frozenChange} >= 0
sql
-- Replace single column index with composite
DROP INDEX idx_account_user_id;
CREATE INDEX idx_account_user_type ON account (user_id, account_type);
-- Add covering index for balance operations
CREATE INDEX idx_account_balance_operations ON account (user_id, account_type)
INCLUDE (balance, frozen_balance, id);
sql
CREATE TABLE public.option_order (
id bigint NOT NULL,
user_id bigint NOT NULL,
account_type character varying(16) NOT NULL,
symbol_id bigint NOT NULL,
round_id bigint NOT NULL,
status character varying(16) DEFAULT 'PENDING'::character varying NOT NULL,
-- ... other fields
);
-- Existing indexes
CREATE INDEX idx_option_order_user_account_create_time ON option_order
(user_id, account_type, create_time);
CREATE INDEX idx_option_order_round_status ON option_order (round_id, status);
User Order List (42 QPS):
Settlement Batch Query (Every 5 minutes):
User Statistics Query (Currently expensive aggregation):
Solution - Enhanced Indexes:
sql
-- OrderMapper.findByUserIdAndAccountType - HIGH FREQUENCY UI QUERY
SELECT id, user_id, account_type, symbol_id, round_id, round_no,
direction, amount, odds, expected_profit, order_price, settle_price,
status, profit, fee, settle_time, cancel_time,
create_time, update_time
FROM option_order
WHERE user_id = #{userId}
AND account_type = #{accountType}
ORDER BY id DESC
LIMIT #{limit} OFFSET #{offset}
sql
-- OrderMapper.findPendingOrdersByRound - CRITICAL SETTLEMENT PATH
SELECT id, user_id, account_type, symbol_id, round_id, round_no,
direction, amount, odds, expected_profit, order_price, settle_price,
status, profit, fee, settle_time, cancel_time,
create_time, update_time
FROM option_order
WHERE round_id = #{roundId}
AND status = 'ACTIVE'
ORDER BY id ASC
sql
-- OrderMapper.userAmountStatistics - NEEDS OPTIMIZATION
SELECT COALESCE(SUM(amount), 0)
FROM option_order
WHERE user_id = #{userId}
AND account_type = #{accountType}
AND create_time >= #{startTime}
AND create_time <= #{endTime}
sql
3. Trading Round Table Optimizations
Current Schema:
Critical Query (17 QPS - Every Order Placement):
-- Optimize existing user query index for DESC ordering
DROP INDEX idx_option_order_user_account_create_time;
CREATE INDEX idx_order_user_account_id_desc ON option_order
(user_id, account_type, id DESC);
-- Add covering index for user queries to avoid table lookups
CREATE INDEX idx_order_user_covering ON option_order
(user_id, account_type, id DESC)
INCLUDE (symbol_id, round_id, direction, amount, status, profit, create_time);
-- Add time range index for statistics
CREATE INDEX idx_order_user_time_range ON option_order
(user_id, account_type, create_time)
INCLUDE (amount);
sql
CREATE TABLE public.trading_round (
id bigint NOT NULL,
symbol_id bigint NOT NULL,
duration_minutes integer NOT NULL,
status character varying(16) DEFAULT 'OPEN'::character varying NOT NULL,
start_time timestamp without time zone NOT NULL,
end_time timestamp without time zone NOT NULL,
-- ... other fields
);
-- Existing index
CREATE INDEX idx_trading_round_current ON trading_round
(symbol_id, duration_minutes, status, start_time, end_time);
sql
Settlement Query (Every 5 minutes):
Solution - Refined Indexes:
4. Account Transaction Table Optimizations
Current Schema:
-- TradingRoundMapper.findCurrentRound - CRITICAL PATH
SELECT id, round_no, symbol_id, duration_minutes, start_time,
lock_time, end_time, start_price, end_price, status,
total_up_amount, total_down_amount, create_time, update_time
FROM trading_round
WHERE symbol_id = #{symbolId}
AND duration_minutes = #{durationMinutes}
AND status IN ('OPEN', 'LOCKED')
AND CURRENT_TIMESTAMP BETWEEN start_time AND end_time
ORDER BY start_time DESC
LIMIT 1
sql
-- TradingRoundMapper.findRoundsNeedingSettlement
SELECT id, round_no, symbol_id, duration_minutes, start_time,
lock_time, end_time, start_price, end_price, status,
total_up_amount, total_down_amount, create_time, update_time
FROM trading_round
WHERE status IN ('OPEN', 'LOCKED')
AND end_time <= #{currentTime}
ORDER BY end_time
sql
-- Add settlement-specific index
CREATE INDEX idx_trading_round_settlement ON trading_round
(status, end_time)
WHERE status IN ('OPEN', 'LOCKED');
-- Add covering index for current round queries
CREATE INDEX idx_trading_round_current_covering ON trading_round
(symbol_id, duration_minutes, status, start_time, end_time)
INCLUDE (id, round_no, total_up_amount, total_down_amount)
WHERE status IN ('OPEN', 'LOCKED');
sql
Critical Queries:
User Transaction History:
Account Type Reconciliation:
Solution - Add Additional Indexes:
CREATE TABLE public.account_transaction (
id bigint NOT NULL,
user_id bigint NOT NULL,
account_id bigint NOT NULL,
type character varying(16) NOT NULL,
amount numeric(32,16) NOT NULL,
create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
-- ... other fields
);
-- Existing indexes
CREATE INDEX idx_transaction_user_time ON account_transaction (user_id, create_time DESC);
CREATE INDEX idx_transaction_account_time ON account_transaction (account_id, create_time DESC);
sql
-- AccountTransactionMapper.findByUserId - ADMIN DASHBOARD
SELECT id, user_id, account_id, type, amount, frozen_amount,
balance_before, balance_after, frozen_before, frozen_after,
ref_id, ref_type, description, remark, create_time
FROM account_transaction
WHERE user_id = #{userId}
ORDER BY create_time DESC
LIMIT #{limit} OFFSET #{offset}
sql
-- AccountTransactionMapper.findByAccountType - RECONCILIATION
SELECT at.*
FROM account_transaction at
INNER JOIN account a ON at.account_id = a.id
WHERE a.account_type = #{accountType}
ORDER BY at.create_time DESC
LIMIT #{limit} OFFSET #{offset}
sql
5. Blacklist Table Optimizations
Current Schema:
Critical Query (17 QPS - Every Order Placement):
Solution - Add Partial Index:
-- Add index for reference-based lookups
CREATE INDEX idx_transaction_ref ON account_transaction (ref_id, ref_type)
WHERE ref_id IS NOT NULL;
-- Add covering index for user queries
CREATE INDEX idx_transaction_user_covering ON account_transaction
(user_id, create_time DESC)
INCLUDE (account_id, type, amount, balance_after);
sql
CREATE TABLE public.blacklist (
id bigint NOT NULL,
user_id bigint NOT NULL,
status smallint DEFAULT 1 NOT NULL,
start_time timestamp without time zone NOT NULL,
end_time timestamp without time zone,
-- ... other fields
);
-- Existing index
CREATE INDEX idx_blacklist_user_status_time ON blacklist
(user_id, status, start_time, end_time);
sql
-- BlacklistMapper.findByUserId - SECURITY CHECK
SELECT id, user_id, reason, operator_id, operator_name,
start_time, end_time, status, create_time, update_time
FROM blacklist
WHERE user_id = #{userId}
AND status = 1
AND start_time <= #{currentTime}
AND (end_time IS NULL OR end_time > #{currentTime})
LIMIT 1
sql
6. BTSE Transfer Log Optimizations
Current Schema:
Critical Queries:
Timeout Processing (Every 5 seconds):
Order Transfer Lookup:
-- Add partial index for active blacklists only
CREATE INDEX idx_blacklist_active_users ON blacklist (user_id, start_time, end_time)
WHERE status = 1;
sql
CREATE TABLE public.btse_transfer_log (
id bigint NOT NULL,
trace_id character varying(100) NOT NULL,
user_id bigint NOT NULL,
refer_id bigint,
direction character varying(10) NOT NULL,
status character varying(20) DEFAULT 'PENDING'::character varying,
create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
-- ... other fields
);
-- Existing index
CREATE INDEX idx_btse_transfer_timeout ON btse_transfer_log
(direction, status, create_time);
sql
-- BtseTransferLogMapper.findTimeoutPendingTransfers
SELECT id, trace_id, user_id, refer_id, direction, amount, currency,
transfer_id, api_method, status, error_message, request_data,
response_data, retry_count, environment, is_mock,
request_time, response_time, create_time, update_time
FROM btse_transfer_log
WHERE direction = #{direction}
AND status = #{status}
AND create_time < #{timeoutTime}
ORDER BY create_time ASC
LIMIT #{limit}
sql
Solution - Add Order Reference Index:
7. User Risk Stats Table Optimization
Critical Query (17 QPS - Every Order Placement):
Incremental Update Query (20 QPS - Order Placement + Settlement):
-- BtseTransferLogMapper.findSuccessfulTransferByOrder
SELECT id, trace_id, user_id, refer_id, direction, amount, currency,
transfer_id, api_method, status, error_message, request_data,
response_data, retry_count, environment, is_mock,
request_time, response_time, create_time, update_time
FROM btse_transfer_log
WHERE refer_id = #{orderId}
AND direction = #{direction}
AND status = 'SUCCESS'
ORDER BY create_time DESC
LIMIT 1
sql
-- Add index for order-based transfer lookups
CREATE INDEX idx_btse_transfer_order ON btse_transfer_log
(refer_id, direction, status, create_time DESC)
WHERE refer_id IS NOT NULL;
sql
-- UserRiskStatsMapper.selectByUserIdAndAccountType - PRIMARY RISK CHECK
SELECT id, user_id, account_type, today_order_count, today_order_amount,
today_win_count, today_loss_count, today_profit,
week_order_count, week_order_amount, week_win_count, week_loss_count, week_profit,
month_order_count, month_order_amount, month_win_count, month_loss_count, month_profit,
total_order_count, total_order_amount, total_win_count, total_loss_count, total_profit,
last_order_time, last_reset_date, last_reset_week, last_reset_month,
create_time, update_time
FROM user_risk_stats
WHERE user_id = #{userId}
AND account_type = #{accountType}
sql
Reset Queries (Scheduled Tasks):
Optimization:
-- UserRiskStatsMapper.incrementOrderStats - REAL-TIME UPDATES
UPDATE user_risk_stats SET
today_order_count = today_order_count + 1,
week_order_count = week_order_count + 1,
month_order_count = month_order_count + 1,
total_order_count = total_order_count + 1,
today_order_amount = today_order_amount + #{amount},
week_order_amount = week_order_amount + #{amount},
month_order_amount = month_order_amount + #{amount},
total_order_amount = total_order_amount + #{amount},
last_order_time = CURRENT_TIMESTAMP,
update_time = CURRENT_TIMESTAMP
WHERE user_id = #{userId} AND account_type = #{accountType}
sql
-- UserRiskStatsMapper.selectNeedResetRecords - BATCH RESET OPERATIONS
SELECT id, user_id, account_type, last_reset_date, last_reset_week, last_reset_month
FROM user_risk_stats
WHERE (last_reset_date IS NULL OR last_reset_date < CURRENT_DATE)
OR (last_reset_week IS NULL OR last_reset_week < DATE_TRUNC('week', CURRENT_DATE))
OR (last_reset_month IS NULL OR last_reset_month < DATE_TRUNC('month', CURRENT_DATE))
ORDER BY update_time
LIMIT #{limit}
sql
Hash Partitioning Strategy
Account Table Partitioning
-- Add covering index for risk check queries
CREATE INDEX idx_user_risk_stats_risk_check ON user_risk_stats (user_id, account_type)
INCLUDE (today_order_count, today_order_amount, week_order_count, week_order_amount,
month_order_count, month_order_amount, total_order_count, total_order_amount);
-- Add indexes for reset operations
CREATE INDEX idx_user_risk_stats_daily_reset ON user_risk_stats (last_reset_date, update_time)
WHERE last_reset_date IS NULL;
CREATE INDEX idx_user_risk_stats_weekly_reset ON user_risk_stats (last_reset_week, update_time)
WHERE last_reset_week IS NULL;
CREATE INDEX idx_user_risk_stats_monthly_reset ON user_risk_stats (last_reset_month, update_time)
WHERE last_reset_month IS NULL;
-- Alternative: Create regular indexes for reset date queries
CREATE INDEX idx_user_risk_stats_reset_dates ON user_risk_stats (last_reset_date, last_reset_week, last_reset_
sql
-- Create partitioned account table
ALTER TABLE account RENAME TO account_old;
CREATE TABLE account (
id bigint NOT NULL DEFAULT nextval('account_id_seq'),
user_id bigint NOT NULL,
account_type character varying(16) NOT NULL,
currency character varying(8) DEFAULT 'USDT'::character varying NOT NULL,
balance numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
frozen_balance numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
total_deposit numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
total_withdraw numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
total_profit numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
total_loss numeric(32,16) DEFAULT 0.0000000000000000 NOT NULL,
reset_count integer DEFAULT 0 NOT NULL,
last_reset_time timestamp without time zone,
create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
CONSTRAINT check_positive_balances CHECK (
balance >= 0 AND frozen_balance >= 0
)
) PARTITION BY HASH (user_id);
-- Create 16 partitions
DO $account_partition$
BEGIN
FOR i IN 0..15 LOOP
EXECUTE format('
CREATE TABLE account_p%s PARTITION OF account
FOR VALUES WITH (modulus 16, remainder %s)', i, i);
END LOOP;
END $account_partition$;
-- Create optimized indexes on partitioned table
CREATE UNIQUE INDEX account_pkey ON account (id, user_id);
CREATE UNIQUE INDEX uk_user_type_currency ON account (user_id, account_type, currency);
CREATE INDEX idx_account_user_type ON account (user_id, account_type);
CREATE INDEX idx_account_balance_operations ON account (user_id, account_type)
INCLUDE (balance, frozen_balance, id);
-- Add triggers
CREATE TRIGGER update_account_update_time
BEFORE UPDATE ON account
FOR EACH ROW EXECUTE FUNCTION update_modified_column();
Option Order Table Partitioning
-- Migrate data
INSERT INTO account SELECT * FROM account_old;
sql
-- Create partitioned option_order table
ALTER TABLE option_order RENAME TO option_order_old;
CREATE TABLE option_order (
id bigint NOT NULL DEFAULT nextval('option_order_id_seq'),
user_id bigint NOT NULL,
account_type character varying(16) NOT NULL,
symbol_id bigint NOT NULL,
round_id bigint NOT NULL,
round_no character varying(64) NOT NULL,
direction character varying(8) NOT NULL,
amount numeric(32,16) NOT NULL,
odds numeric(10,4) NOT NULL,
expected_profit numeric(32,16) NOT NULL,
order_price numeric(32,16) NOT NULL,
settle_price numeric(32,16),
status character varying(16) DEFAULT 'PENDING'::character varying NOT NULL,
profit numeric(32,16),
fee numeric(32,16),
cancel_time timestamp without time zone,
settle_time timestamp without time zone,
create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
CONSTRAINT check_positive_amount CHECK (amount > 0),
CONSTRAINT check_valid_direction CHECK (direction IN ('UP', 'DOWN')),
CONSTRAINT check_valid_status CHECK (status IN ('PENDING', 'ACTIVE', 'WIN', 'LOSE', 'CANCELLED'))
) PARTITION BY HASH (user_id);
-- Create 32 partitions (higher volume)
DO $order_partition$
BEGIN
FOR i IN 0..31 LOOP
EXECUTE format('
CREATE TABLE option_order_p%s PARTITION OF option_order
FOR VALUES WITH (modulus 32, remainder %s)', i, i);
END LOOP;
END $order_partition$;
-- Create optimized indexes
CREATE UNIQUE INDEX option_order_pkey ON option_order (id, user_id);
CREATE INDEX idx_order_user_account_id_desc ON option_order (user_id, account_type, id DESC);
CREATE INDEX idx_order_round_status ON option_order (round_id, status);
CREATE INDEX idx_order_user_covering ON option_order
(user_id, account_type, id DESC)
INCLUDE (symbol_id, round_id, direction, amount, status, profit, create_time);
Account Transaction Partitioning
CREATE INDEX idx_order_user_time_range ON option_order
(user_id, account_type, create_time)
INCLUDE (amount);
-- Add triggers
CREATE TRIGGER update_option_order_update_time
BEFORE UPDATE ON option_order
FOR EACH ROW EXECUTE FUNCTION update_modified_column();
-- Migrate data
INSERT INTO option_order SELECT * FROM option_order_old;
sql
-- Create partitioned account_transaction table
ALTER TABLE account_transaction RENAME TO account_transaction_old;
CREATE TABLE account_transaction (
id bigint NOT NULL DEFAULT nextval('account_transaction_id_seq'),
user_id bigint NOT NULL,
account_id bigint NOT NULL,
type character varying(16) NOT NULL,
amount numeric(32,16) NOT NULL,
frozen_amount numeric(32,16) DEFAULT 0.0000000000000000,
balance_before numeric(32,16) NOT NULL,
balance_after numeric(32,16) NOT NULL,
frozen_before numeric(32,16) DEFAULT 0.0000000000000000,
frozen_after numeric(32,16) DEFAULT 0.0000000000000000,
ref_id bigint,
ref_type character varying(16),
description character varying(255),
remark character varying(255),
create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
) PARTITION BY HASH (user_id);
-- Create 32 partitions
DO $transaction_partition$
BEGIN
FOR i IN 0..31 LOOP
EXECUTE format('
CREATE TABLE account_transaction_p%s PARTITION OF account_transaction
FOR VALUES WITH (modulus 32, remainder %s)', i, i);
END LOOP;
END $transaction_partition$;
-- Create optimized indexes
CREATE UNIQUE INDEX account_transaction_pkey ON account_transaction (id, user_id);
CREATE INDEX idx_transaction_user_time ON account_transaction (user_id, create_time DESC);
CREATE INDEX idx_transaction_account_time ON account_transaction (account_id, create_time DESC);
CREATE INDEX idx_transaction_ref ON account_transaction (ref_id, ref_type)
WHERE ref_id IS NOT NULL;
CREATE INDEX idx_transaction_user_covering ON account_transaction
(user_id, create_time DESC)
INCLUDE (account_id, type, amount, balance_after);
-- Migrate data
INSERT INTO account_transaction SELECT * FROM account_transaction_old;