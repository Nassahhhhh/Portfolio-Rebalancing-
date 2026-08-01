# SQL Portfolio Rebalancing Engine

A pure-SQL project that detects portfolio allocation drift and calculates the exact trades needed to rebalance a portfolio back to its target allocation — using real historical stock price data.

## The Problem

When you build a portfolio with target allocations (e.g., 20% Tech, 20% Healthcare, 15% Energy...), those percentages don't stay fixed. As stock prices move at different rates, the actual dollar-weight of each holding drifts away from its target — even though you never bought or sold anything. Left unmanaged, this silently changes the portfolio's risk profile. This project detects that drift and calculates the trades needed to fix it, using nothing but SQL.

## Data

Real daily closing prices (Nov 2016 – Nov 2017) for 6 stocks across 5 sectors, sourced from the [Huge Stock Market Dataset](https://www.kaggle.com/datasets/borismarjanovic/huge-stock-market-dataset) on Kaggle:

| Ticker | Sector | Target Allocation |
|---|---|---|
| AAPL | Tech | 20% |
| MSFT | Tech | 15% |
| JNJ | Healthcare | 20% |
| XOM | Energy | 15% |
| JPM | Finance | 15% |
| KO | Consumer Goods | 15% |

## Schema

- **`assets`** — ticker, sector, target allocation %
- **`daily_prices`** — daily closing price per asset
- **`portfolio_holdings`** — fixed share quantity per asset (calculated once from a hypothetical $100,000 investment split by target allocation, using day-1 prices). Share counts stay constant over the year, which is what causes weight drift as prices move.

## Key Queries

1. **Daily asset value** — `quantity × price` per asset per day
2. **Drift detection** — actual weight (%) vs target weight (%) for every asset, every day, using subqueries and joins to compute per-asset and total portfolio value
3. **Rebalancing trade suggestions** — for the most recent date, calculates exactly how much to buy or sell of each asset to bring the portfolio back to target allocation

## Sample Output (as of 2017-11-10)

| Ticker | Current Value | Target Value | Suggested Trade |
|---|---|---|---|
| AAPL | $31,999.64 | $26,558.35 | **Sell $5,441.28** |
| XOM | $15,575.39 | $19,918.76 | **Buy $4,343.37** |
| KO | $17,135.49 | $19,918.76 | **Buy $2,783.27** |
| JPM | $21,691.06 | $19,918.76 | **Sell $1,772.30** |
| JNJ | $24,846.61 | $26,558.35 | **Buy $1,712.34** |
| MSFT | $21,544.16 | $19,918.76 | **Sell $1,625.40** |

AAPL's strong performance over the year pushed it from 20% to over 24% of the portfolio, while XOM (energy) underperformed and dropped from 15% to under 12% — a realistic pattern reflecting tech's outperformance over energy during this period.

## Tools

MySQL 8.0 — window functions, subqueries, joins, aggregate functions.
