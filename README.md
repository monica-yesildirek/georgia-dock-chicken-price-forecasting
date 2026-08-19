# Chicken Price Time Series Forecasting

An end-to-end analysis of monthly U.S. chicken prices, from differencing and model identification through residual screening, rolling-origin validation, and a 24-month forecast.

![Twenty-four-month forecast of chicken prices](figures/Figure_07_Twenty_Four_Month_Forecast.png)

## Project overview

| Item | Detail |
| --- | --- |
| Business question | How can historical chicken prices support two-year budgeting and procurement planning? |
| Data | 180 monthly whole-bird spot-price observations at Georgia docks |
| Period | August 2001-July 2016 |
| Unit | U.S. cents per pound |
| Selected model | SARIMA(2,1,0) x (1,0,1)[12], without drift |
| Validation design | Expanding window, 37 origins, 24-month horizon |
| Forecast horizon | August 2016-July 2018 |

## Results

- Chicken prices increased from approximately 66 cents per pound in 2001 to more than 110 cents per pound in 2016 while retaining relatively stable variance. The original scale was therefore retained.
- The original-series ACF decayed slowly, and its augmented Dickey-Fuller test did not reject a unit root (`p = .885`). Both an ordinary difference and a lag-12 difference were evaluated rather than treating either differencing order as predetermined.
- Eight theory-driven SARIMA candidates were screened. The ordinary-difference SARIMA(2,1,0) x (1,0,1)[12] and SARIMA(2,1,0) x (1,0,0)[12] models were the only candidates with significant coefficients, valid roots, and Ljung-Box p-values above .05 at lags 12, 24, and 36.
- The selected SARIMA(2,1,0) x (1,0,1)[12] model reduced aggregate rolling-origin RMSE to `5.604`, compared with `6.576` for the runner-up and `5.898` for a random walk with drift. Its aggregate MAE was `4.528`.
- The final point forecast begins at 110.8 cents per pound in August 2016, reaches a short-term low of 108.9 cents in December 2016, and rises to 114.9 cents by July 2018. The final 95% prediction interval is 97.7-132.0 cents per pound.

The selected model contains strong seasonal persistence: its seasonal AR estimate is 0.979 and its minimum AR root is 1.002. The fitted roots remain valid, and the model produced the strongest out-of-sample results, but the near-boundary behavior contributes to widening long-horizon prediction intervals. Forecasts should therefore be interpreted as planning ranges based on historical price behavior rather than predictions of future market shocks.

## Modeling approach

1. Inspect the original series for trend, seasonality, outliers, and changing variance.
2. Compare ordinary and lag-12 seasonal differences using time plots, ACF/PACF behavior, and augmented Dickey-Fuller tests.
3. Screen eight ACF/PACF-justified SARIMA specifications across the `d=1, D=0` and `d=0, D=1` families.
4. Retain only candidates with significant structural coefficients, stationary and invertible roots, and Ljung-Box p-values above .05 at lags 12, 24, and 36.
5. Test drift only as a nested addition to the retained ordinary-difference models. Drift was not significant and was omitted.
6. Compare eligible models using expanding-window forecasts from an initial 120-month training period. Report RMSE and MAE at horizons 1, 12, and 24 and across all horizons.
7. Use information criteria only within a common differencing family. Select the diagnostically adequate model with the lowest aggregate validation RMSE.
8. Refit the selected model to all 180 observations and generate a 24-month forecast with 80% and 95% prediction intervals.

## Why the other candidates were excluded

The screening stage was intentionally broader than the final comparison. The lower-order ordinary-difference AR(1) model and all three seasonal-difference models retained residual dependence. Adding AR(3) or MA(1) to the ordinary-difference AR(2) structure produced nonsignificant coefficients without a diagnostic advantage. The final comparison therefore contains the two models that satisfied every eligibility condition rather than an arbitrary number of candidates.

## Repository structure

```text
.
|-- analysis/   # Portable R analysis, screening, validation, and forecast pipeline
|-- data/       # Clean monthly price series used by the script
|-- figures/    # Exploratory, diagnostic, and forecast graphics
|-- report/     # Full written analysis
|-- results/    # Screening, validation, estimates, tests, and forecasts
`-- README.md   # Portfolio summary
```

## Reproduce the analysis

The analysis uses R only and does not depend on a user-specific working directory.

```r
install.packages(c("forecast", "fUnitRoots"))
```

From the repository root, run:

```bash
Rscript analysis/chicken_sales_forecast.R
```

The script reads [`data/chicken_prices.csv`](data/chicken_prices.csv) and recreates the seven figures and consolidated result files. The CSV is derived from the `chicken` dataset distributed with the `astsa` R package.

## Key deliverables

- [Full project report](report/chicken_sales_time_series_report.docx)
- [Portable R analysis](analysis/chicken_sales_forecast.R)
- [Candidate screening](results/candidate_screening.csv)
- [Rolling-origin validation](results/rolling_validation.csv)
- [Finalist comparison](results/finalist_comparison.csv)
- [Twenty-four-month forecast](results/forecast_24_months.csv)

## Tools and methods

R; `forecast`; `fUnitRoots`; SARIMA modeling; ACF/PACF analysis; augmented Dickey-Fuller testing; Ljung-Box diagnostics; expanding-window forecast validation; prediction intervals.
