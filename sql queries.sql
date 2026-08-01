CREATE DATABASE IF NOT EXISTS portfolio_sim;
USE portfolio_sim;

DROP TABLE IF EXISTS portfolio_holdings;
DROP TABLE IF EXISTS daily_prices;
DROP TABLE IF EXISTS daily_prices_raw;
DROP TABLE IF EXISTS assets;

CREATE TABLE assets (
    asset_id INT AUTO_INCREMENT PRIMARY KEY,
    ticker VARCHAR(10) NOT NULL UNIQUE,
    sector VARCHAR(30) NOT NULL,
    target_allocation DECIMAL(5,4) NOT NULL
);

INSERT INTO assets (ticker, sector, target_allocation) VALUES
    ('AAPL', 'Tech',            0.20),
    ('MSFT', 'Tech',            0.15),
    ('JNJ',  'Healthcare',      0.20),
    ('XOM',  'Energy',          0.15),
    ('JPM',  'Finance',         0.15),
    ('KO',   'Consumer Goods',  0.15);

CREATE TABLE daily_prices (
    price_id INT AUTO_INCREMENT PRIMARY KEY,
    asset_id INT NOT NULL,
    price_date DATE NOT NULL,
    close_price DECIMAL(12,4) NOT NULL,
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    UNIQUE KEY uniq_asset_date (asset_id, price_date)
);

CREATE TABLE daily_prices_raw (
    ticker VARCHAR(10) NOT NULL,
    price_date DATE NOT NULL,
    close_price DECIMAL(12,4) NOT NULL
);

LOAD DATA LOCAL INFILE 'C:/Users/DELL/OneDrive/Desktop/hassan/combined_stock_prices.csv'
INTO TABLE daily_prices_raw
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ticker, price_date, close_price);

INSERT INTO daily_prices (asset_id, price_date, close_price)
SELECT a.asset_id, r.price_date, r.close_price
FROM daily_prices_raw r
JOIN assets a ON a.ticker = r.ticker;

DROP TABLE daily_prices_raw;

CREATE TABLE portfolio_holdings (
    holding_id INT AUTO_INCREMENT PRIMARY KEY,
    asset_id INT NOT NULL,
    holding_date DATE NOT NULL,
    quantity DECIMAL(14,4) NOT NULL,
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    UNIQUE KEY uniq_asset_holding_date (asset_id, holding_date)
);

SET @total_value = 100000;

INSERT INTO portfolio_holdings (asset_id, holding_date, quantity)
SELECT
    dp.asset_id,
    dp.price_date,
    ROUND((@total_value * a.target_allocation) / day1.close_price, 4) AS quantity
FROM daily_prices dp
JOIN assets a ON a.asset_id = dp.asset_id
JOIN (
    SELECT asset_id, close_price
    FROM daily_prices dp1
    WHERE price_date = (
        SELECT MIN(price_date) FROM daily_prices dp2
        WHERE dp2.asset_id = dp1.asset_id
    )
) day1 ON day1.asset_id = dp.asset_id;

SELECT * FROM assets;
SELECT COUNT(*) AS total_price_rows FROM daily_prices;
SELECT COUNT(*) AS total_holding_rows FROM portfolio_holdings;
SELECT MIN(price_date), MAX(price_date) FROM daily_prices;

SELECT
    dp.price_date,
    a.ticker,
    a.sector,
    ROUND(h.quantity * dp.close_price, 2) AS asset_value,
    a.target_allocation
FROM daily_prices dp
JOIN portfolio_holdings h ON h.asset_id = dp.asset_id AND h.holding_date = dp.price_date
JOIN assets a ON a.asset_id = dp.asset_id
ORDER BY dp.price_date, a.ticker
LIMIT 20;

SELECT
    v.price_date,
    v.ticker,
    v.asset_value,
    t.total_value,
    ROUND(v.asset_value / t.total_value, 4) AS actual_weight,
    v.target_allocation,
    ROUND((v.asset_value / t.total_value) - v.target_allocation, 4) AS drift
FROM (
    SELECT
        dp.price_date,
        a.asset_id,
        a.ticker,
        a.target_allocation,
        (h.quantity * dp.close_price) AS asset_value
    FROM daily_prices dp
    JOIN portfolio_holdings h ON h.asset_id = dp.asset_id AND h.holding_date = dp.price_date
    JOIN assets a ON a.asset_id = dp.asset_id
) v
JOIN (
    SELECT
        dp.price_date,
        SUM(h.quantity * dp.close_price) AS total_value
    FROM daily_prices dp
    JOIN portfolio_holdings h ON h.asset_id = dp.asset_id AND h.holding_date = dp.price_date
    GROUP BY dp.price_date
) t ON t.price_date = v.price_date
ORDER BY v.price_date DESC, v.ticker
LIMIT 20;

SELECT
    v.ticker,
    v.asset_value AS current_value,
    ROUND(t.total_value * v.target_allocation, 2) AS target_value,
    ROUND((t.total_value * v.target_allocation) - v.asset_value, 2) AS suggested_trade
FROM (
    SELECT dp.price_date, a.asset_id, a.ticker, a.target_allocation,
           (h.quantity * dp.close_price) AS asset_value
    FROM daily_prices dp
    JOIN portfolio_holdings h ON h.asset_id = dp.asset_id AND h.holding_date = dp.price_date
    JOIN assets a ON a.asset_id = dp.asset_id
) v
JOIN (
    SELECT dp.price_date, SUM(h.quantity * dp.close_price) AS total_value
    FROM daily_prices dp
    JOIN portfolio_holdings h ON h.asset_id = dp.asset_id AND h.holding_date = dp.price_date
    GROUP BY dp.price_date
) t ON t.price_date = v.price_date
WHERE v.price_date = (SELECT MAX(price_date) FROM daily_prices)
ORDER BY ABS((t.total_value * v.target_allocation) - v.asset_value) DESC;
