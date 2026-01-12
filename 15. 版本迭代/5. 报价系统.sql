-- DDL for Binary Option Trading Schema in PostgreSQL

-- Table for settlements
CREATE TABLE bo_markets (
    market_id VARCHAR(255) PRIMARY KEY,
    underlying_asset VARCHAR(255) NOT NULL,
    duration VARCHAR(10) NOT NULL,
    symbol VARCHAR(255) NOT NULL,
    expiration_timestamp TIMESTAMP NOT NULL,
    strike_price DECIMAL(18, 8) NOT NULL,
    option_type VARCHAR(4) NOT NULL CHECK (option_type IN ('CALL', 'PUT')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, expiration_timestamp)
);

-- Table for trades
CREATE TABLE bo_trades (
    trade_id SERIAL PRIMARY KEY,
    trader_id INTEGER NOT NULL, -- References an external user system
    market_id VARCHAR(255) NOT NULL,
    whitelabel VARCHAR(255) NOT NULL,
    trade_type VARCHAR(4) NOT NULL CHECK (trade_type IN ('BUY', 'SELL')),
    quantity INTEGER NOT NULL,
    price DECIMAL(18, 8) NOT NULL,
    probability_it_m DECIMAL(5, 4), -- Probability of the option ending in-the-money at the time of trade
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for realized PNL
CREATE TABLE bo_realized_pnl (
    realized_pnl_id SERIAL PRIMARY KEY,
    trader_id INTEGER NOT NULL, -- References an external user system
    trade_id INTEGER REFERENCES bo_trades(trade_id),
    pnl DECIMAL(18, 8) NOT NULL,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for trader balance audit trail
CREATE TABLE bo_trader_balance_audit (
    audit_id SERIAL PRIMARY KEY,
    trader_id INTEGER NOT NULL, -- References an external user system
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('DEPOSIT', 'WITHDRAWAL', 'PNL_SETTLEMENT')),
    amount DECIMAL(18, 8) NOT NULL, -- Positive for credit, negative for debit
    trade_id INTEGER REFERENCES bo_trades(trade_id), -- Link to the individual trade that generated the PNL
    symbol VARCHAR(255), -- For settlement-level summary records
    whitelabel VARCHAR(255) NOT NULL,
    underlying_asset VARCHAR(255) NOT NULL,
    expiration_timestamp TIMESTAMP, -- For settlement-level summary records
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- DML for sample data (for unit testing)

-- Insert sample markets for specific symbol/expiration pairs
INSERT INTO bo_markets (market_id, underlying_asset, duration, symbol, expiration_timestamp, strike_price, option_type) VALUES
('20251231160500_AAPL_5m', 'stocks', '5m', 'AAPL', '2025-12-31 16:05:00', 185.00, 'CALL'),
('20251231160100_GOOG_1m', 'stocks', '1m', 'GOOG', '2025-12-31 16:01:00', 145.00, 'PUT');

-- Trader IDs (from an external user system)
-- 1: Alice (User)
-- 2: Bob (System/Maker/Counterparty)

-- Insert sample trades
-- Alice (Trader 1) buys 10 units of a 5-minute AAPL Call
INSERT INTO bo_trades (trader_id, market_id, whitelabel, trade_type, quantity, price, probability_it_m) VALUES
(1, '20251231160500_AAPL_5m', 'whitelabel_A', 'BUY', 10, 5.00, 0.6500);
-- System (Trader 2) sells 10 units of a 5-minute AAPL Call
INSERT INTO bo_trades (trader_id, market_id, whitelabel, trade_type, quantity, price, probability_it_m) VALUES
(2, '20251231160500_AAPL_5m', 'whitelabel_A', 'SELL', 10, 5.00, 0.6500);

-- Alice (Trader 1) buys 5 units of a 1-minute GOOG Put
INSERT INTO bo_trades (trader_id, market_id, whitelabel, trade_type, quantity, price, probability_it_m) VALUES
(1, '20251231160100_GOOG_1m', 'whitelabel_B', 'BUY', 5, 3.00, 0.5500);
-- System (Trader 2) sells 5 units of a 1-minute GOOG Put
INSERT INTO bo_trades (trader_id, market_id, whitelabel, trade_type, quantity, price, probability_it_m) VALUES
(2, '20251231160100_GOOG_1m', 'whitelabel_B', 'SELL', 5, 3.00, 0.5500);


-- Insert sample realized PNL (calculated for trades after settlement)
-- PNL for Alice (AAPL Call Buy): (185 settlement - 180 strike) * 10 quantity - (5 price * 10 quantity) = 50 - 50 = 0
INSERT INTO bo_realized_pnl (trader_id, trade_id, pnl) VALUES
(1, 1, 0.00);
-- PNL for System (AAPL Call Sell): (5 price * 10 quantity) - (185 settlement - 180 strike) * 10 quantity = 50 - 50 = 0
INSERT INTO bo_realized_pnl (trader_id, trade_id, pnl) VALUES
(2, 2, 0.00);

-- PNL for Alice (GOOG Put Buy): (150 strike - 145 settlement) * 5 quantity - (3 price * 5 quantity) = 25 - 15 = 10
INSERT INTO bo_realized_pnl (trader_id, trade_id, pnl) VALUES
(1, 3, 10.00);
-- PNL for System (GOOG Put Sell): (3 price * 5 quantity) - (150 strike - 145 settlement) * 5 quantity = 15 - 25 = -10
INSERT INTO bo_realized_pnl (trader_id, trade_id, pnl) VALUES
(2, 4, -10.00);

-- Insert balance audit entries for each individual trade's PNL settlement
INSERT INTO bo_trader_balance_audit (trader_id, transaction_type, amount, trade_id, whitelabel, underlying_asset) VALUES
(1, 'PNL_SETTLEMENT', 0.00, 1, 'whitelabel_A', 'stocks'),
(2, 'PNL_SETTLEMENT', 0.00, 2, 'whitelabel_A', 'stocks'),
(1, 'PNL_SETTLEMENT', 10.00, 3, 'whitelabel_B', 'stocks'),
(2, 'PNL_SETTLEMENT', -10.00, 4, 'whitelabel_B', 'stocks');

-- Insert summary balance audit entries for the MAKER's total PNL for each expired option
-- For AAPL @ 2025-12-31 16:05:00, the sum of user PNLs is 0. The maker's PNL is -0 = 0.
INSERT INTO bo_trader_balance_audit (trader_id, transaction_type, amount, trade_id, symbol, whitelabel, underlying_asset, expiration_timestamp) VALUES
(2, 'PNL_SETTLEMENT', 0.00, NULL, 'AAPL', 'whitelabel_A', 'stocks', '2025-12-31 16:05:00');
-- For GOOG @ 2025-12-31 16:01:00, the sum of user PNLs is 10. The maker's PNL is -10.
INSERT INTO bo_trader_balance_audit (trader_id, transaction_type, amount, trade_id, symbol, whitelabel, underlying_asset, expiration_timestamp) VALUES
(2, 'PNL_SETTLEMENT', -10.00, NULL, 'GOOG', 'whitelabel_B', 'stocks', '2025-12-31 16:01:00');