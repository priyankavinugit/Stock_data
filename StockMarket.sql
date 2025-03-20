create database Stock_Market;
use stock_market;
select * from stock_market.stock_data;

--- Calculate summary statistics for the 'Open,' 'High,' 'Low,' 'Close,' columns, including mean, minimum, maximum, and standard deviation.

SELECT 
    AVG(Open) AS avg_open,
    MIN(Open) AS min_open,
    MAX(Open) AS max_open,
    STDDEV(Open) AS stddev_open,

    AVG(High) AS avg_high,
    MIN(High) AS min_high,
    MAX(High) AS max_high,
    STDDEV(High) AS stddev_high,

    AVG(Low) AS avg_low,
    MIN(Low) AS min_low,
    MAX(Low) AS max_low,
    STDDEV(Low) AS stddev_low,

    AVG(Close) AS avg_close,
    MIN(Close) AS min_close,
    MAX(Close) AS max_close,
    STDDEV(Close) AS stddev_close
FROM stock_data;

--- Explore the distribution of closing prices ('Close') over the given period.

SELECT 
    CASE
        WHEN Close < 50 THEN '0-50'
        WHEN Close BETWEEN 50 AND 100 THEN '50-100'
        WHEN Close BETWEEN 100 AND 150 THEN '100-150'
        WHEN Close BETWEEN 150 AND 200 THEN '150-200'
        ELSE '200+'
    END AS price_range,
    COUNT(*) AS frequency
FROM stock_data
GROUP BY price_range
ORDER BY frequency DESC;



describe stock_data
ALTER TABLE stock_data RENAME COLUMN ï»¿date TO stock_date;


--- Compute the Exponential Moving Average (EMA) for the closing prices over a selected period (e.g., 10 days).

WITH ranked_data AS (
    SELECT 
        stock_date,  
        Close, 
        ROW_NUMBER() OVER (ORDER BY stock_date) AS row_num
    FROM stock_data
)
SELECT 
    r1.stock_date,  
    r1.Close,
    -- Simple Moving Average (SMA) for the last 10 days
    AVG(r2.Close) OVER (ORDER BY r1.stock_date ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS sma_10,  
    -- Exponential Moving Average (EMA) calculation
    (2 / (10 + 1)) * (r1.Close - r2.Close) + r2.Close AS EMA_10
FROM ranked_data r1
JOIN ranked_data r2 ON r1.row_num = r2.row_num + 1;



WITH ranked_data AS (
    SELECT 
        stock_date,  
        Close, 
        ROW_NUMBER() OVER (ORDER BY stock_date) AS row_num,
        -- Simple Moving Average (SMA) calculation
        AVG(Close) OVER (ORDER BY stock_date ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS sma_10
    FROM stock_data
),
ema_calculated AS (
    SELECT 
        r1.stock_date,
        r1.Close,
        r1.sma_10,
        -- Calculate EMA (here we manually calculate the EMA for each row using the previous row's EMA)
        (2 / (10 + 1)) * (r1.Close - COALESCE(r2.EMA_10, r1.Close)) + COALESCE(r2.EMA_10, r1.Close) AS EMA_10
    FROM ranked_data r1
    LEFT JOIN ema_calculated r2 ON r1.row_num = r2.row_num + 1  
)
SELECT 
    r1.stock_date,
    r1.Close,
    r1.EMA_10,
    CASE
        WHEN r1.Close > r1.EMA_10 AND r2.Close < r2.EMA_10 THEN 'Buy Signal'   -- Buy signal: Close crosses above EMA
        WHEN r1.Close < r1.EMA_10 AND r2.Close > r2.EMA_10 THEN 'Sell Signal'  -- Sell signal: Close crosses below EMA
        ELSE 'No Signal'    -- No signal if there's no crossover
    END AS signal
FROM ema_calculated r1
JOIN ema_calculated r2 ON r1.row_num = r2.row_num + 1  -- Compare current day's data with the previous day's data
ORDER BY r1.stock_date;


--- Calculate daily returns and assess the overall relative strength index (RSI) over the given time frame.

WITH daily_returns AS (
    SELECT 
        stock_date,
        Close,
        LAG(Close) OVER (ORDER BY stock_date) AS previous_close,
        -- Calculate daily return
        ((Close - LAG(Close) OVER (ORDER BY stock_date)) / LAG(Close) OVER (ORDER BY stock_date)) * 100 AS daily_return
    FROM stock_data
),
gains_losses AS (
    SELECT
        stock_date,
        Close,
        previous_close,
        CASE
            WHEN Close > previous_close THEN Close - previous_close  -- Gain
            ELSE 0
        END AS gain,
        CASE
            WHEN Close < previous_close THEN previous_close - Close  -- Loss
            ELSE 0
        END AS loss
    FROM daily_returns
),
average_gains_losses AS (
    SELECT
        stock_date,
        gain,
        loss,
        -- Calculate the average gain and loss over the first 14 days
        AVG(gain) OVER (ORDER BY stock_date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_gain,
        AVG(loss) OVER (ORDER BY stock_date ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS avg_loss
    FROM gains_losses
),
rs_and_rsi AS (
    SELECT
        stock_date,
        avg_gain,
        avg_loss,
        -- Calculate Relative Strength (RS) and RSI
        CASE 
            WHEN avg_loss = 0 THEN 100
            ELSE (avg_gain / avg_loss)
        END AS rs,
        CASE 
            WHEN avg_loss = 0 THEN 100
            ELSE 100 - (100 / (1 + (avg_gain / avg_loss)))
        END AS rsi
    FROM average_gains_losses
)
SELECT
    daily_returns.stock_date,
    daily_returns.Close,
    daily_returns.daily_return,
    rs_and_rsi.rsi
FROM daily_returns
JOIN rs_and_rsi ON daily_returns.stock_date = rs_and_rsi.stock_date
ORDER BY daily_returns.stock_date;

--- Evaluate the stocks performance in terms of daily price change

WITH daily_changes AS (
    SELECT
        stock_date,
        Close,
        LAG(Close) OVER (ORDER BY stock_date) AS previous_close,
        -- Calculate daily price change (absolute)
        Close - LAG(Close) OVER (ORDER BY stock_date) AS daily_price_change,
        -- Calculate daily percentage change
        ((Close - LAG(Close) OVER (ORDER BY stock_date)) / LAG(Close) OVER (ORDER BY stock_date)) * 100 AS daily_percentage_change
    FROM stock_data
)
SELECT
    stock_date,
    Close,
    daily_price_change,
    daily_percentage_change
FROM daily_changes
ORDER BY stock_date;
