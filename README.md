# Georgia Dock Chicken Price Forecasting

A repeatable R forecasting workflow that turns 15 years of monthly Georgia dock chicken prices into a two-year planning baseline with clear risk ranges.

![Twenty-four-month forecast of Georgia dock chicken prices](figures/Figure_07_Twenty_Four_Month_Forecast.png)

## Business Problem and Objectives

Wholesale chicken prices affect purchasing budgets, product costs, and margin expectations. Procurement and financial-planning teams need a shared view of where prices may move and how much uncertainty to include in their plans. Relying on the latest price or a simple annual average would not account for the trend and recurring patterns in the market.

| Business requirement | Project response |
| --- | --- |
| Primary users | Procurement and financial-planning teams with exposure to wholesale chicken prices |
| Decision | Set a baseline price outlook and planning range for August 2016 through July 2018 |
| Business problem | Estimate the likely price path without creating false confidence around a volatile market outcome |
| Constraints | 180 monthly observations, no external cost or supply indicators, and greater uncertainty farther into the forecast |
| Success criteria | Beat practical forecast benchmarks, pass model risk checks, quantify uncertainty, and provide a repeatable workflow |

The project objectives were to:

- establish a credible 24-month baseline for budgeting and procurement discussions;
- show a range of possible prices, not just a single point estimate;
- test the selected approach against simpler forecasting methods; and
- create an R workflow that can be rerun when new data become available.

## Data and Discovery

The analysis uses the `chicken` dataset distributed with the `astsa` R package. A clean, project-ready extract is stored in [`data/chicken_prices.csv`](data/chicken_prices.csv).

| Data characteristic | Detail |
| --- | --- |
| Measure | Monthly whole-bird spot price at Georgia docks |
| Period | August 2001-July 2016 |
| Volume | 180 consecutive monthly observations |
| Unit | U.S. cents per pound |
| Quality controls | Required fields, no missing values, correct record count, and consecutive monthly dates |

Discovery work identified several signals that matter for planning:

- Prices increased from approximately 66 cents per pound in 2001 to more than 110 cents per pound in 2016. A long-range plan therefore needed to account for an upward price level rather than assume a flat historical average.
- Price variability remained relatively stable as the level increased, so the forecast could remain in the original cents-per-pound scale used by the business.
- The series showed strong persistence and recurring annual dependence. A forecast based only on the latest observation would miss important information in the historical pattern.
- Both ordinary month-to-month change and year-over-year change were credible ways to stabilize the series. Both were carried into model testing so the final choice would be based on performance rather than an early assumption.

The dataset contains price history only. It does not include feed costs, supply levels, weather, energy prices, policy changes, or market disruptions. Forecasts are therefore treated as planning ranges based on historical behavior, not as predictions of unexpected market events.

## Solution Design

The solution is a lightweight forecasting pipeline that compares credible model choices, removes unstable or unnecessarily complex options, and selects the strongest remaining candidate through out-of-sample testing.

1. Review the price history for trend, seasonality, unusual movements, and changes in variability.
2. Evaluate both month-to-month and year-over-year transformations instead of committing to one approach in advance.
3. Screen eight SARIMA candidates supported by the patterns in the data.
4. Remove candidates with unstable estimates, unhelpful terms, or remaining forecastable patterns in their errors.
5. Test whether adding drift improves the retained models; omit it when it does not add measurable value.
6. Compare the eligible candidates with seasonal-naive and random-walk-with-drift benchmarks.
7. Select the model with the best overall rolling-origin RMSE, using MAE, simplicity, and within-family fit statistics as supporting evidence.
8. Refit the selected model to the full history and produce a 24-month forecast with 80% and 95% planning ranges.

This design favors reliability over complexity. A higher-order brute-force model was not included because the data did not provide a business or statistical reason for the added complexity. Only models that passed the eligibility checks were allowed into the final comparison.

## Development

The deliverable is a repeatable R pipeline rather than a one-time spreadsheet calculation. [`analysis/chicken_sales_forecast.R`](analysis/chicken_sales_forecast.R) is the single entry point for data checks, discovery, model comparison, validation, diagnostics, and forecasting.

The workflow uses base R with the `forecast` and `fUnitRoots` packages. One run reads the clean CSV and recreates the seven figures and consolidated result files. A database and application layer were not needed for this version because the project uses one small, version-controlled dataset and produces static decision-support outputs. If the forecast were operationalized, these layers could be added when automated data ingestion or self-service access becomes necessary.

```text
.
|-- analysis/   # R pipeline for model comparison, validation, and forecasting
|-- data/       # Clean monthly price series
|-- figures/    # Discovery, diagnostic, and forecast visuals
|-- report/     # Full written analysis
|-- results/    # Model screening, validation, and forecast outputs
`-- README.md   # Business-facing project summary
```

To reproduce the analysis, install the required packages:

```r
install.packages(c("forecast", "fUnitRoots"))
```

Then run the following command from the repository root:

```bash
Rscript analysis/chicken_sales_forecast.R
```

## Testing and Validation

Testing was designed to answer two questions: can the model be trusted technically, and would it have produced useful forecasts on historical data it had not yet seen?

| Control | Business purpose |
| --- | --- |
| Input checks | Prevent incomplete, duplicated, or misaligned monthly data from entering the forecast |
| Coefficient checks | Remove terms that do not contribute reliable information |
| Root checks | Exclude unstable model structures |
| Residual checks at 12, 24, and 36 months | Confirm that the model has not left recurring patterns unused |
| Drift tests | Add a long-term drift term only when it provides measurable value |
| Expanding-window backtest | Recreate how the model would perform as new months became available |
| Benchmark comparison | Confirm that the added modeling effort improves on simpler forecasting choices |

The backtest began with 120 months of training data and expanded across 37 forecast origins. Performance was measured from 1 through 24 months using RMSE and MAE, including dedicated checks at 1, 12, and 24 months.

Eight SARIMA candidates entered screening. Models with remaining error patterns or unsupported additional terms were removed. Two candidates passed every eligibility check and advanced to the final comparison:

| Eligible candidate | Aggregate RMSE | Aggregate MAE | Validation outcome |
| --- | ---: | ---: | --- |
| SARIMA(2,1,0) x (1,0,1)[12] | 5.604 | 4.528 | Best validated performance |
| SARIMA(2,1,0) x (1,0,0)[12] | 6.576 | 5.307 | Eligible runner-up |

The selected model also outperformed the random-walk-with-drift benchmark (`RMSE = 5.898`) and the seasonal-naive benchmark (`RMSE = 11.509`). This indicates that the final model added useful forecast value beyond a simple continuation of the historical pattern.

## Results and Decision Support

SARIMA(2,1,0) x (1,0,1)[12] without drift provided the best validated forecast performance among the eligible candidates. Its aggregate RMSE was 14.8% lower than the eligible runner-up and 5.0% lower than the random-walk-with-drift benchmark.

| Decision-support result | Value |
| --- | --- |
| Selected model | SARIMA(2,1,0) x (1,0,1)[12], without drift |
| Validation design | Expanding window, 37 origins, 24-month horizon |
| Aggregate RMSE | 5.604 cents per pound |
| Aggregate MAE | 4.528 cents per pound |
| Forecast period | August 2016-July 2018 |
| First point forecast | 110.8 cents per pound |
| Short-term low | 108.9 cents per pound in December 2016 |
| Final point forecast | 114.9 cents per pound |
| Final 95% planning range | 97.7-132.0 cents per pound |

The forecast supports several planning activities:

- **Budget baseline:** Use the point forecast as a shared starting assumption for expected chicken costs.
- **Risk scenarios:** Use the 80% and 95% ranges to estimate reasonable upside and downside cost exposure.
- **Procurement discussions:** Use the expected short-term dip and later increase as inputs to purchasing conversations, together with current market intelligence.
- **Expectation setting:** Communicate that confidence decreases as the planning horizon extends.

The selected model has a seasonal AR estimate of 0.979 and a minimum AR root of 1.002. The root remains valid but is close to the stability boundary, making the seasonal pattern highly persistent and somewhat sensitive to changes in the data or model specification. This sensitivity and the widening long-range intervals mean the forecast should guide scenarios rather than serve as a fixed purchasing commitment.

### Limitations and production considerations

- The history ends in July 2016, so current business use would require a refreshed and comparable price source.
- The model cannot anticipate external shocks because it does not include supply, feed-cost, energy, weather, or policy variables.
- Long-range intervals widen materially and should be reflected in contingency budgets.
- A production version should automate data-quality checks, scheduled refitting, forecast-error monitoring, and alerts for structural changes.
- Future development could test external business drivers, compare additional forecasting methods, and recalibrate the planning ranges as new outcomes become available.

### Key deliverables

- [Full project report](report/chicken_sales_time_series_report.docx)
- [Reproducible R pipeline](analysis/chicken_sales_forecast.R)
- [Candidate screening](results/candidate_screening.csv)
- [Rolling-origin validation](results/rolling_validation.csv)
- [Finalist comparison](results/finalist_comparison.csv)
- [Twenty-four-month forecast](results/forecast_24_months.csv)

### Tools and methods

R; `forecast`; `fUnitRoots`; SARIMA forecasting; ACF/PACF analysis; augmented Dickey-Fuller testing; Ljung-Box diagnostics; expanding-window validation; benchmark comparison; prediction intervals.
