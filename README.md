# Chicken Price Time Series Forecasting

An end-to-end time-series analysis of monthly U.S. chicken prices, from exploratory diagnostics and stationarity testing through SARIMA model selection and a 24-month forecast.

![Twenty-four-month forecast of chicken prices](figures/Figure_07_Twenty_Four_Month_Forecast.png)

## Project overview

| Item | Detail |
| --- | --- |
| Business question | How can historical chicken prices be modeled to support two-year budgeting and procurement planning? |
| Data | 180 monthly whole-bird spot-price observations at Georgia docks |
| Period | August 2001-July 2016 |
| Unit | U.S. cents per pound |
| Selected model | SARIMA(3,0,0) x (0,1,1)[12] with a linear time term |
| Forecast horizon | 24 months, August 2016-July 2018 |

## Results

- Chicken prices rose from about 66 cents per pound in 2001 to more than 110 cents per pound in 2016, with relatively stable variance. The analysis therefore retained the original scale rather than applying a log transformation.
- A lag-12 seasonal difference removed the persistent upward movement. An augmented Dickey-Fuller test rejected a unit root after differencing (`p < .01`).
- The selected SARIMA(3,0,0) x (0,1,1)[12] model had the lowest residual variance, AIC, and AICc among the three data-driven candidates. Its fitted linear time coefficient was 0.2833 cents per pound per month.
- The forecast initially dips to roughly 109 cents per pound, then rises to 118.9 cents per pound by July 2018. The final 95% prediction interval is 108.6-129.2 cents per pound.
- Residual diagnostics showed modest long-lag dependence. The forecast is useful as a planning range, but it does not account for unobserved market shocks or external drivers.

The information-criterion values in [`results/model_comparison.csv`](results/model_comparison.csv) are the scaled values returned by `astsa::sarima()` for models fitted to the same original series. The exhaustive candidate search was run on the seasonally differenced series; its trace is retained in [`results/auto_arima_trace.txt`](results/auto_arima_trace.txt).

## Approach

1. Inspect the original series for trend, seasonality, outliers, and changing variance.
2. Review the ACF and apply a lag-12 seasonal difference.
3. Confirm stationarity with an augmented Dickey-Fuller test.
4. Use the differenced-series ACF/PACF and an exhaustive AICc search to identify candidate models.
5. Compare three SARIMA candidates using coefficients, residual variance, AIC, AICc, BIC, and residual diagnostics.
6. Refit the selected model and generate point forecasts with 80% and 95% prediction intervals.

## Repository structure

```text
.
|-- analysis/   # Portable R analysis and forecast pipeline
|-- data/       # Clean monthly price series used by the script
|-- figures/    # Exploratory, diagnostic, and forecast graphics
|-- report/     # Full written analysis
|-- results/    # Model estimates, comparisons, tests, and forecasts
`-- README.md   # Portfolio summary
```

## Reproduce the analysis

The script is portable and does not depend on a user-specific working directory.

```r
install.packages(c("astsa", "forecast", "fUnitRoots"))
```

From the repository root, run:

```bash
Rscript analysis/chicken_sales_forecast.R
```

The script reads [`data/chicken_prices.csv`](data/chicken_prices.csv) and recreates the figures and result files in place. The clean CSV is derived from the `chicken` dataset distributed with the `astsa` R package.

## Deliverables

- [Full project report](report/chicken_sales_time_series_report.docx)
- [Portable R analysis](analysis/chicken_sales_forecast.R)
- [Model comparison](results/model_comparison.csv)
- [Twenty-four-month forecast](results/forecast_24_months.csv)

## Tools

R; `astsa`; `forecast`; `fUnitRoots`; SARIMA modeling; ACF/PACF analysis; augmented Dickey-Fuller testing; residual diagnostics; prediction intervals.
