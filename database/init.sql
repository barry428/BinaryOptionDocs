-- 二元期权平台数据库初始化脚本
-- 基于 docs/2. 设计类/207_详细设计文档.md
-- 创建时间: 2025-07-22

CREATE DATABASE IF NOT EXISTS `binary_option` DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
USE `binary_option`;

-- =====================================================
-- option-common-service 数据表
-- =====================================================

-- 1. 用户表 (user) - 已存在，但需要完善
CREATE TABLE `user` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `external_id` varchar(64) NOT NULL COMMENT '外部用户ID(BTSE用户ID)',
  `password` varchar(128) NOT NULL COMMENT '密码(加密)',
  `nickname` varchar(64) DEFAULT NULL COMMENT '昵称',
  `email` varchar(128) DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(32) DEFAULT NULL COMMENT '手机号',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '状态(1:正常 2:禁用)',
  `signature` varchar(128) DEFAULT NULL COMMENT '个性签名',
  `risk_agreement` tinyint NOT NULL DEFAULT '0' COMMENT '风险协议(0:未同意 1:已同意)',
  `aml_agreement` tinyint NOT NULL DEFAULT '0' COMMENT 'AML协议(0:未同意 1:已同意)',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_external_id` (`external_id`),
  UNIQUE KEY `uk_email` (`email`),
  UNIQUE KEY `uk_phone` (`phone`)
) ENGINE=InnoDB COMMENT='用户表';

-- 2. 账户表 (account)
CREATE TABLE `account` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `account_type` varchar(16) NOT NULL COMMENT '账户类型(REAL:实盘 DEMO:模拟)',
  `currency` varchar(8) NOT NULL DEFAULT 'USDT' COMMENT '币种',
  `balance` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '可用余额',
  `frozen_balance` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '冻结余额',
  `total_deposit` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '累计充值',
  `total_withdraw` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '累计提现',
  `total_profit` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '累计盈利',
  `total_loss` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '累计亏损',
  `reset_count` int NOT NULL DEFAULT '0' COMMENT '重置次数(仅模拟账户)',
  `last_reset_time` datetime DEFAULT NULL COMMENT '最后重置时间',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_type_currency` (`user_id`,`account_type`,`currency`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB COMMENT='账户表';

-- 3. 资金流水表 (account_transaction)
CREATE TABLE `account_transaction` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `account_id` bigint NOT NULL COMMENT '账户ID',
  `type` varchar(16) NOT NULL COMMENT '交易类型(DEPOSIT:充值 WITHDRAW:提现 CANCEL:撤单 BET_WIN:投注盈利 BET_LOSE:投注亏损 BET_DRAW:投注平局 RESET:重置)',
  `amount` decimal(32,16) NOT NULL COMMENT '交易金额',
  `balance_before` decimal(32,16) NOT NULL COMMENT '交易前余额',
  `balance_after` decimal(32,16) NOT NULL COMMENT '交易后余额',
  `ref_id` bigint DEFAULT NULL COMMENT '关联ID(订单ID等)',
  `ref_type` varchar(16) DEFAULT NULL COMMENT '关联类型(ORDER等)',
  `remark` varchar(255) DEFAULT NULL COMMENT '备注',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_account` (`user_id`,`account_id`),
  KEY `idx_ref` (`ref_id`,`ref_type`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB COMMENT='资金流水表';

-- 4. 币种配置表 (symbol_config)
CREATE TABLE `symbol_config` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `symbol` varchar(16) NOT NULL COMMENT '交易对(如BTC/USDT)',
  `base_currency` varchar(8) NOT NULL COMMENT '基础币种(BTC)',
  `quote_currency` varchar(8) NOT NULL COMMENT '计价币种(USDT)',
  `enabled` tinyint NOT NULL DEFAULT '1' COMMENT '是否启用(0:禁用 1:启用)',
  `min_amount` decimal(32,16) NOT NULL DEFAULT '10.0000000000000000' COMMENT '最小下注金额',
  `max_amount` decimal(32,16) NOT NULL DEFAULT '10000.0000000000000000' COMMENT '最大下注金额',
  `btse_symbol` varchar(32) NOT NULL COMMENT 'BTSE交易对名称',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_symbol` (`symbol`)
) ENGINE=InnoDB COMMENT='币种配置表';

-- =====================================================
-- option-order-service 数据表
-- =====================================================

-- 5. 周期配置表 (duration_config)
CREATE TABLE `duration_config` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `duration_minutes` int NOT NULL COMMENT '周期时长(分钟)',
  `duration_name` varchar(32) NOT NULL COMMENT '周期名称(如5分钟)',
  `enabled` tinyint NOT NULL DEFAULT '1' COMMENT '是否启用(0:禁用 1:启用)',
  `lock_seconds` int NOT NULL DEFAULT '30' COMMENT '锁单时间(秒)',
  `base_odds` decimal(10,4) NOT NULL DEFAULT '1.9000' COMMENT '基础赔率',
  `fee_rate` decimal(6,4) NOT NULL DEFAULT '0.1000' COMMENT '手续费率(0.1表示10%)',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_duration` (`duration_minutes`)
) ENGINE=InnoDB COMMENT='周期配置表';

-- 6. 交易回合表 (trading_round)
CREATE TABLE `trading_round` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `round_no` varchar(64) NOT NULL COMMENT '回合编号',
  `symbol_id` bigint NOT NULL COMMENT '交易对ID',
  `duration_minutes` int NOT NULL COMMENT '周期时长(分钟)',
  `start_time` datetime NOT NULL COMMENT '开始时间',
  `lock_time` datetime NOT NULL COMMENT '锁单时间(结束前30秒)',
  `end_time` datetime NOT NULL COMMENT '结束时间',
  `start_price` decimal(32,16) DEFAULT NULL COMMENT '开盘价',
  `end_price` decimal(32,16) DEFAULT NULL COMMENT '收盘价',
  `status` varchar(16) NOT NULL DEFAULT 'OPEN' COMMENT '状态(OPEN:开放 LOCKED:锁单 SETTLED:已结算)',
  `total_up_amount` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT 'UP总投注额',
  `total_down_amount` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT 'DOWN总投注额',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_round_no` (`round_no`),
  KEY `idx_symbol_time` (`symbol_id`,`start_time`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB COMMENT='交易回合表';

-- 7. 订单表 (option_order) - 已存在，但需要完善
DROP TABLE IF EXISTS `option_order`;
CREATE TABLE `option_order` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `account_type` varchar(16) NOT NULL COMMENT '账户类型(REAL:实盘 DEMO:模拟)',
  `symbol_id` bigint NOT NULL COMMENT '交易对ID',
  `round_id` bigint NOT NULL COMMENT '回合ID',
  `round_no` varchar(64) NOT NULL COMMENT '回合编号',
  `direction` varchar(8) NOT NULL COMMENT '方向(UP:看涨 DOWN:看跌)',
  `amount` decimal(32,16) NOT NULL COMMENT '投注金额',
  `odds` decimal(10,4) NOT NULL COMMENT '赔率',
  `expected_profit` decimal(32,16) NOT NULL COMMENT '预期收益',
  `order_price` decimal(32,16) NOT NULL COMMENT '下单价格',
  `settle_price` decimal(32,16) DEFAULT NULL COMMENT '结算价格',
  `status` varchar(16) NOT NULL DEFAULT 'PENDING' COMMENT '状态(PENDING:进行中 WIN:盈利 LOSE:亏损 DRAW:平局 CANCELLED:已撤销)',
  `profit` decimal(32,16) DEFAULT NULL COMMENT '实际盈亏',
  `fee` decimal(32,16) DEFAULT NULL COMMENT '手续费',
  `cancel_time` datetime DEFAULT NULL COMMENT '撤销时间',
  `settle_time` datetime DEFAULT NULL COMMENT '结算时间',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_symbol_round` (`user_id`,`symbol_id`,`round_id`),
  KEY `idx_round_status` (`round_id`,`status`),
  KEY `idx_user_create_time` (`user_id`,`create_time`)
) ENGINE=InnoDB COMMENT='订单表';

-- 8. 风控配置表 (risk_config)
CREATE TABLE `risk_config` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `config_key` varchar(64) NOT NULL COMMENT '配置键',
  `config_value` varchar(255) NOT NULL COMMENT '配置值',
  `config_type` varchar(16) NOT NULL COMMENT '配置类型(LIMIT:限额 BLACKLIST:黑名单 GLOBAL:全局)',
  `description` varchar(255) DEFAULT NULL COMMENT '描述',
  `enabled` tinyint NOT NULL DEFAULT '1' COMMENT '是否启用',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB COMMENT='风控配置表';

-- 9. 风控日志表 (risk_log)
CREATE TABLE `risk_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `risk_type` varchar(32) NOT NULL COMMENT '风控类型(AMOUNT_LIMIT:金额限制 FREQUENCY_LIMIT:频次限制 BLACKLIST:黑名单)',
  `risk_level` varchar(16) NOT NULL COMMENT '风险级别(LOW:低 MEDIUM:中 HIGH:高)',
  `action` varchar(32) NOT NULL COMMENT '处理动作(BLOCK:阻断 WARN:警告 LOG:记录)',
  `description` varchar(500) NOT NULL COMMENT '详细描述',
  `request_data` text COMMENT '请求数据',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_time` (`user_id`,`create_time`),
  KEY `idx_risk_type` (`risk_type`)
) ENGINE=InnoDB COMMENT='风控日志表';

-- =====================================================
-- option-admin-service 数据表
-- =====================================================

-- 10. 黑名单表 (blacklist)
CREATE TABLE `blacklist` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `reason` varchar(255) NOT NULL COMMENT '加入黑名单原因',
  `operator_id` bigint NOT NULL COMMENT '操作员ID',
  `operator_name` varchar(64) NOT NULL COMMENT '操作员姓名',
  `start_time` datetime NOT NULL COMMENT '生效时间',
  `end_time` datetime DEFAULT NULL COMMENT '失效时间(NULL表示永久)',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '状态(1:生效 0:失效)',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status_time` (`status`,`start_time`,`end_time`)
) ENGINE=InnoDB COMMENT='黑名单表';

-- 11. 管理员用户表 (admin_user)
CREATE TABLE `admin_user` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `external_id` varchar(64) DEFAULT NULL COMMENT '外部系统ID(BTSE管理员ID)',
  `username` varchar(64) NOT NULL COMMENT '用户名',
  `password` varchar(128) DEFAULT NULL COMMENT '密码(SSO用户可为空)',
  `email` varchar(128) DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(32) DEFAULT NULL COMMENT '手机号',
  `real_name` varchar(64) DEFAULT NULL COMMENT '真实姓名',
  `avatar` varchar(255) DEFAULT NULL COMMENT '头像URL',
  `source` varchar(16) NOT NULL DEFAULT 'LOCAL' COMMENT '来源(LOCAL:本地 BTSE:BTSE系统)',
  `role` varchar(32) NOT NULL DEFAULT 'OPERATOR' COMMENT '角色(SUPER_ADMIN:超级管理员 ADMIN:管理员 OPERATOR:操作员)',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '状态(1:正常 0:禁用)',
  `permissions` text COMMENT '权限列表(逗号分隔)',
  `last_login_time` datetime DEFAULT NULL COMMENT '最后登录时间',
  `last_login_ip` varchar(64) DEFAULT NULL COMMENT '最后登录IP',
  `last_login_type` varchar(16) DEFAULT NULL COMMENT '最后登录方式(PASSWORD:密码 SSO:单点登录)',
  `login_fail_count` int NOT NULL DEFAULT '0' COMMENT '登录失败次数',
  `lock_until` datetime DEFAULT NULL COMMENT '锁定到期时间',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `create_by` bigint DEFAULT NULL COMMENT '创建人ID',
  `update_by` bigint DEFAULT NULL COMMENT '更新人ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_external_id` (`external_id`),
  UNIQUE KEY `uk_email` (`email`),
  KEY `idx_status` (`status`),
  KEY `idx_source` (`source`),
  KEY `idx_role` (`role`)
) ENGINE=InnoDB COMMENT='管理员用户表';

-- 12. 管理员操作日志表 (admin_operation_log)
CREATE TABLE `admin_operation_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `operator_id` bigint NOT NULL COMMENT '操作员ID',
  `operator_name` varchar(64) NOT NULL COMMENT '操作员姓名',
  `operation_type` varchar(32) NOT NULL COMMENT '操作类型(USER_UPDATE:用户更新 CONFIG_UPDATE:配置更新等)',
  `operation_desc` varchar(255) NOT NULL COMMENT '操作描述',
  `target_type` varchar(32) DEFAULT NULL COMMENT '目标类型(USER:用户 CONFIG:配置等)',
  `target_id` varchar(64) DEFAULT NULL COMMENT '目标ID',
  `before_data` text COMMENT '操作前数据',
  `after_data` text COMMENT '操作后数据',
  `ip_address` varchar(64) DEFAULT NULL COMMENT '操作IP',
  `user_agent` varchar(255) DEFAULT NULL COMMENT '用户代理',
  `result` tinyint NOT NULL DEFAULT '1' COMMENT '操作结果(1:成功 0:失败)',
  `error_msg` varchar(500) DEFAULT NULL COMMENT '错误信息',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_operator_time` (`operator_id`,`create_time`),
  KEY `idx_operation_type` (`operation_type`),
  KEY `idx_target` (`target_type`,`target_id`)
) ENGINE=InnoDB COMMENT='管理员操作日志表';

-- 13. 全局配置表 (global_config)
CREATE TABLE `global_config` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `config_key` varchar(64) NOT NULL COMMENT '配置键',
  `config_value` text NOT NULL COMMENT '配置值',
  `config_type` varchar(16) NOT NULL COMMENT '配置类型(STRING:字符串 NUMBER:数字 BOOLEAN:布尔 JSON:JSON对象)',
  `config_group` varchar(32) NOT NULL COMMENT '配置分组(SYSTEM:系统 BUSINESS:业务 UI:界面)',
  `description` varchar(255) DEFAULT NULL COMMENT '配置描述',
  `enabled` tinyint NOT NULL DEFAULT '1' COMMENT '是否启用',
  `sort_order` int NOT NULL DEFAULT '0' COMMENT '排序',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`),
  KEY `idx_config_group` (`config_group`)
) ENGINE=InnoDB COMMENT='全局配置表';

-- 14. 每日统计表 (daily_stats)
CREATE TABLE `daily_stats` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `stat_date` date NOT NULL COMMENT '统计日期',
  `symbol_id` bigint DEFAULT NULL COMMENT '交易对ID(NULL表示全部)',
  `total_users` int NOT NULL DEFAULT '0' COMMENT '总用户数',
  `active_users` int NOT NULL DEFAULT '0' COMMENT '活跃用户数',
  `new_users` int NOT NULL DEFAULT '0' COMMENT '新增用户数',
  `total_orders` int NOT NULL DEFAULT '0' COMMENT '订单总数',
  `pending_orders` int NOT NULL DEFAULT '0' COMMENT '进行中订单数',
  `win_orders` int NOT NULL DEFAULT '0' COMMENT '盈利订单数',
  `lose_orders` int NOT NULL DEFAULT '0' COMMENT '亏损订单数',
  `draw_orders` int NOT NULL DEFAULT '0' COMMENT '平局订单数',
  `total_volume` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '交易总量',
  `total_profit` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '用户总盈利',
  `total_loss` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '用户总亏损',
  `total_fee` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '平台手续费收入',
  `win_rate` decimal(5,4) NOT NULL DEFAULT '0.0000' COMMENT '胜率',
  `avg_order_amount` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '平均下单金额',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_date_symbol` (`stat_date`, `symbol_id`),
  KEY `idx_stat_date` (`stat_date`)
) ENGINE=InnoDB COMMENT='每日统计表';

-- 14. 每小时统计表 (hourly_stats)
CREATE TABLE `hourly_stats` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `stat_datetime` datetime NOT NULL COMMENT '统计时间(精确到小时)',
  `symbol_id` bigint DEFAULT NULL COMMENT '交易对ID(NULL表示全部)',
  `active_users` int NOT NULL DEFAULT '0' COMMENT '活跃用户数',
  `total_orders` int NOT NULL DEFAULT '0' COMMENT '订单总数',
  `total_volume` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '交易总量',
  `total_profit` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '用户总盈利',
  `total_loss` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '用户总亏损',
  `total_fee` decimal(32,16) NOT NULL DEFAULT '0.0000000000000000' COMMENT '平台手续费收入',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_datetime_symbol` (`stat_datetime`, `symbol_id`),
  KEY `idx_stat_datetime` (`stat_datetime`)
) ENGINE=InnoDB COMMENT='每小时统计表';

-- =====================================================
-- 初始化数据
-- =====================================================

-- 插入默认币种配置
INSERT INTO `symbol_config` (`symbol`, `base_currency`, `quote_currency`, `btse_symbol`, `enabled`, `min_amount`, `max_amount`, `sort_order`) VALUES
('BTC/USDT', 'BTC', 'USDT', 'BTCUSDT', 1, '10.0000000000000000', '10000.0000000000000000', 1),
('ETH/USDT', 'ETH', 'USDT', 'ETHUSDT', 1, '10.0000000000000000', '10000.0000000000000000', 2);

-- 插入默认周期配置
INSERT INTO `duration_config` (`duration_minutes`, `duration_name`, `enabled`, `lock_seconds`, `base_odds`, `fee_rate`, `sort_order`) VALUES
(5, '5分钟', 1, 30, '1.9000', '0.1000', 1),
(10, '10分钟', 1, 30, '1.9000', '0.1000', 2),
(15, '15分钟', 1, 30, '1.9000', '0.1000', 3);

-- 插入默认风控配置
INSERT INTO `risk_config` (`config_key`, `config_value`, `config_type`, `description`, `enabled`) VALUES
('MIN_BET_AMOUNT', '10', 'LIMIT', '最小下注金额', 1),
('MAX_BET_AMOUNT', '10000', 'LIMIT', '最大下注金额', 1),
('DAILY_BET_LIMIT', '100000', 'LIMIT', '单日投注限额', 1),
('WEEKLY_BET_LIMIT', '500000', 'LIMIT', '单周投注限额', 1),
('MONTHLY_BET_LIMIT', '2000000', 'LIMIT', '单月投注限额', 1);

-- 插入默认全局配置
INSERT INTO `global_config` (`config_key`, `config_value`, `config_type`, `config_group`, `description`, `enabled`, `sort_order`) VALUES
('SYSTEM_MAINTENANCE', 'false', 'BOOLEAN', 'SYSTEM', '系统维护状态', 1, 1),
('DEFAULT_DEMO_BALANCE', '100000', 'NUMBER', 'BUSINESS', '默认模拟账户余额', 1, 2),
('PLATFORM_NAME', '二元期权交易平台', 'STRING', 'UI', '平台名称', 1, 3);

-- =====================================================
-- 数据库索引优化
-- =====================================================

-- 1. 用户表索引优化
ALTER TABLE `user` ADD INDEX `idx_status_create_time` (`status`, `create_time`);
ALTER TABLE `user` ADD INDEX `idx_create_time` (`create_time`);

-- 2. 账户表索引优化  
ALTER TABLE `account` ADD INDEX `idx_account_type_balance` (`account_type`, `balance`);
ALTER TABLE `account` ADD INDEX `idx_user_account_type` (`user_id`, `account_type`);

-- 3. 资金流水表索引优化
ALTER TABLE `account_transaction` ADD INDEX `idx_type_create_time` (`type`, `create_time`);
ALTER TABLE `account_transaction` ADD INDEX `idx_user_type` (`user_id`, `type`);
ALTER TABLE `account_transaction` ADD INDEX `idx_user_create_time_single` (`user_id`, `create_time`);

-- 4. 订单表索引优化
ALTER TABLE `option_order` ADD INDEX `idx_user_account_status` (`user_id`, `account_type`, `status`);
ALTER TABLE `option_order` ADD INDEX `idx_user_account_create_time` (`user_id`, `account_type`, `create_time`);
ALTER TABLE `option_order` ADD INDEX `idx_status_create_time` (`status`, `create_time`);
ALTER TABLE `option_order` ADD INDEX `idx_settle_time` (`settle_time`);
ALTER TABLE `option_order` ADD INDEX `idx_symbol_create_time` (`symbol_id`, `create_time`);

-- 5. 交易回合表索引优化
ALTER TABLE `trading_round` ADD INDEX `idx_symbol_duration_status` (`symbol_id`, `duration_minutes`, `status`);
ALTER TABLE `trading_round` ADD INDEX `idx_end_time_status` (`end_time`, `status`);
ALTER TABLE `trading_round` ADD INDEX `idx_lock_time_status` (`lock_time`, `status`);

-- 6. 风控配置表索引优化
ALTER TABLE `risk_config` ADD INDEX `idx_config_type` (`config_type`);
ALTER TABLE `risk_config` ADD INDEX `idx_enabled` (`enabled`);

-- 7. 风控日志表索引优化
ALTER TABLE `risk_log` ADD INDEX `idx_user_time_risk` (`user_id`, `create_time`);
ALTER TABLE `risk_log` ADD INDEX `idx_risk_type_log` (`risk_type`);
ALTER TABLE `risk_log` ADD INDEX `idx_action` (`action`);
ALTER TABLE `risk_log` ADD INDEX `idx_create_time_risk` (`create_time`);

-- 8. 管理员用户表索引优化
ALTER TABLE `admin_user` ADD INDEX `idx_external_id` (`external_id`);
ALTER TABLE `admin_user` ADD INDEX `idx_last_login_time` (`last_login_time`);
ALTER TABLE `admin_user` ADD INDEX `idx_create_time_admin_user` (`create_time`);

-- 9. 管理员操作日志表索引优化
ALTER TABLE `admin_operation_log` ADD INDEX `idx_result_create_time` (`result`, `create_time`);
ALTER TABLE `admin_operation_log` ADD INDEX `idx_ip_create_time` (`ip_address`, `create_time`);
ALTER TABLE `admin_operation_log` ADD INDEX `idx_create_time_admin` (`create_time`);

-- 10. 黑名单表索引优化
ALTER TABLE `blacklist` ADD INDEX `idx_operator_id` (`operator_id`);
ALTER TABLE `blacklist` ADD INDEX `idx_create_time_blacklist` (`create_time`);

-- 11. 统计表索引优化
ALTER TABLE `daily_stats` ADD INDEX `idx_symbol_stat_date` (`symbol_id`, `stat_date`);
ALTER TABLE `hourly_stats` ADD INDEX `idx_symbol_stat_datetime` (`symbol_id`, `stat_datetime`);

-- 12. 周期配置表索引优化
ALTER TABLE `duration_config` ADD INDEX `idx_enabled_sort` (`enabled`, `sort_order`);
ALTER TABLE `duration_config` ADD INDEX `idx_duration_minutes` (`duration_minutes`);

-- 13. 币种配置表索引优化
ALTER TABLE `symbol_config` ADD INDEX `idx_enabled_sort` (`enabled`, `sort_order`);
ALTER TABLE `symbol_config` ADD INDEX `idx_base_currency` (`base_currency`);
ALTER TABLE `symbol_config` ADD INDEX `idx_quote_currency` (`quote_currency`);

-- =====================================================
-- option-market-service 数据表
-- =====================================================

-- 16. 分钟行情数据表
CREATE TABLE `market_data_minute` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `symbol` varchar(16) NOT NULL COMMENT '交易对',
  `time` datetime NOT NULL COMMENT '时间（精确到分钟）',
  `open` decimal(32,16) NOT NULL COMMENT '开盘价',
  `high` decimal(32,16) NOT NULL COMMENT '最高价',
  `low` decimal(32,16) NOT NULL COMMENT '最低价',
  `close` decimal(32,16) NOT NULL COMMENT '收盘价',
  `tick_count` int NOT NULL DEFAULT 0 COMMENT '价格变动次数',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_symbol_time` (`symbol`, `time`),
  KEY `idx_time` (`time`)
) ENGINE=InnoDB COMMENT='分钟行情数据表，保留一个月数据';

-- 17. 小时行情数据表
CREATE TABLE `market_data_hourly` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `symbol` varchar(16) NOT NULL COMMENT '交易对',
  `time` datetime NOT NULL COMMENT '时间（精确到小时）',
  `open` decimal(32,16) NOT NULL COMMENT '开盘价',
  `high` decimal(32,16) NOT NULL COMMENT '最高价',
  `low` decimal(32,16) NOT NULL COMMENT '最低价',
  `close` decimal(32,16) NOT NULL COMMENT '收盘价',
  `tick_count` int NOT NULL DEFAULT 0 COMMENT '价格变动次数',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_symbol_time` (`symbol`, `time`),
  KEY `idx_time` (`time`)
) ENGINE=InnoDB COMMENT='小时行情数据表，长期存储';

-- =====================================================
-- 索引优化
-- =====================================================

-- 为新增的market表添加索引
ALTER TABLE `market_data_minute` ADD INDEX `idx_create_time` (`create_time`);
ALTER TABLE `market_data_hourly` ADD INDEX `idx_create_time` (`create_time`);

-- =====================================================
-- 脚本执行完成
-- =====================================================
SELECT '数据库初始化完成！已创建17张表并插入基础配置数据，优化了31个索引。' AS result;