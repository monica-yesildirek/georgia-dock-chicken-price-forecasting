############################################################
# CHICKEN PRICE TIME SERIES FORECASTING
# Reproducible portfolio analysis
############################################################

required_packages <- c("forecast", "fUnitRoots")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Install the required packages before running this script: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

find_project_root <- function(start_dir) {
  current <- normalizePath(start_dir, winslash = "/", mustWork = TRUE)

  repeat {
    if (
      file.exists(file.path(current, "README.md")) &&
      dir.exists(file.path(current, "analysis"))
    ) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not locate the repository root.", call. = FALSE)
    }
    current <- parent
  }
}

command_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", command_args, value = TRUE)
start_dir <- if (length(file_arg) == 1) {
  dirname(normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE))
} else {
  getwd()
}

project_root <- find_project_root(start_dir)
data_dir <- file.path(project_root, "data")
figure_dir <- file.path(project_root, "figures")
result_dir <- file.path(project_root, "results")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)

if (.Platform$OS.type == "windows") {
  try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE)
}

############################################################
# 1. LOAD AND VALIDATE DATA
############################################################

data_path <- file.path(data_dir, "chicken_prices.csv")
chicken_data <- read.csv(data_path, stringsAsFactors = FALSE)
chicken_data$date <- as.Date(chicken_data$date)

if (!identical(names(chicken_data), c("date", "price_cents_per_lb"))) {
  stop("Unexpected columns in data/chicken_prices.csv.", call. = FALSE)
}

if (nrow(chicken_data) != 180 || anyNA(chicken_data)) {
  stop("Expected 180 complete monthly observations.", call. = FALSE)
}

expected_dates <- seq(
  from = chicken_data$date[1],
  by = "month",
  length.out = nrow(chicken_data)
)

if (!identical(chicken_data$date, expected_dates)) {
  stop("Dates must be consecutive monthly observations.", call. = FALSE)
}

start_year <- as.integer(format(chicken_data$date[1], "%Y"))
start_month <- as.integer(format(chicken_data$date[1], "%m"))
X <- ts(
  chicken_data$price_cents_per_lb,
  start = c(start_year, start_month),
  frequency = 12
)

ordinary_difference <- diff(X)
seasonal_difference <- diff(X, lag = 12)

############################################################
# 2. SHARED FIGURE STYLE
############################################################

report_teal <- "#156082"
accent_orange <- "#C55A11"
soft_teal <- "#DDEBF7"
report_font <- "sans"

if (.Platform$OS.type == "windows") {
  font_result <- try(
    grDevices::windowsFonts(Aptos = grDevices::windowsFont("Aptos")),
    silent = TRUE
  )
  if (!inherits(font_result, "try-error")) {
    report_font <- "Aptos"
  }
}

report_style <- function(mar = c(4.5, 4.5, 3, 1)) {
  par(
    family = report_font,
    col = report_teal,
    col.main = report_teal,
    col.lab = "black",
    col.axis = "black",
    fg = "black",
    lwd = 1.5,
    font.main = 2,
    cex.main = 1.10,
    cex.lab = 1,
    cex.axis = 0.88,
    mar = mar,
    mgp = c(2.6, 0.8, 0),
    las = 1,
    bty = "l"
  )
}

open_png <- function(filename, width, height) {
  png(
    file.path(figure_dir, filename),
    width = width,
    height = height,
    units = "in",
    res = 300
  )
}

############################################################
# 3. PRELIMINARY ANALYSIS
############################################################

open_png("Figure_01_Original_Chicken_Series.png", 7.5, 5)
report_style()
plot(
  X,
  xlab = "Year",
  ylab = "Chicken price (cents per pound)",
  main = "Monthly Chicken Price Series",
  col = report_teal,
  lwd = 1.5,
  xaxp = c(2002, 2016, 7)
)
dev.off()

open_png("Figure_02_ACF_Original_Chicken_Series.png", 7.5, 5)
report_style()
acf(
  X,
  lag.max = 48,
  main = "Sample ACF of the Original Chicken Series",
  xlab = "Lag (years)",
  ylab = "ACF",
  col = report_teal,
  ci.col = accent_orange,
  lwd = 1.5
)
dev.off()

open_png("Figure_03_Differencing_Comparison.png", 8, 7.5)
report_style(c(3.5, 4.2, 2.6, 1))
par(mfrow = c(2, 2))
plot(
  ordinary_difference,
  xlab = "Year",
  ylab = "First difference",
  main = "Ordinary Difference",
  col = report_teal,
  lwd = 1.4
)
acf(
  ordinary_difference,
  lag.max = 48,
  xlab = "Lag (years)",
  ylab = "ACF",
  main = "ACF: Ordinary Difference",
  col = report_teal,
  ci.col = accent_orange,
  lwd = 1.4
)
plot(
  seasonal_difference,
  xlab = "Year",
  ylab = "Lag-12 difference",
  main = "Seasonal Difference",
  col = report_teal,
  lwd = 1.4
)
acf(
  seasonal_difference,
  lag.max = 48,
  xlab = "Lag (years)",
  ylab = "ACF",
  main = "ACF: Seasonal Difference",
  col = report_teal,
  ci.col = accent_orange,
  lwd = 1.4
)
par(mfrow = c(1, 1))
dev.off()

adf_test <- function(series, label) {
  test <- suppressWarnings(
    fUnitRoots::adfTest(series, lags = 5, type = "c")
  )
  data.frame(
    Series = label,
    Lags = 5,
    Test.Statistic = as.numeric(test@test$statistic),
    P.value = as.numeric(test@test$p.value),
    stringsAsFactors = FALSE
  )
}

adf_results <- rbind(
  adf_test(X, "Original series"),
  adf_test(ordinary_difference, "Ordinary difference (d=1, D=0)"),
  adf_test(seasonal_difference, "Seasonal difference (d=0, D=1)")
)
write.csv(adf_results, file.path(result_dir, "adf_test.csv"), row.names = FALSE)

open_png("Figure_04_Ordinary_Difference_ACF_PACF.png", 8, 4.5)
report_style()
par(mfrow = c(1, 2), mar = c(4.5, 4.3, 3, 1))
acf(
  ordinary_difference,
  lag.max = 48,
  main = "Sample ACF",
  xlab = "Lag (years)",
  ylab = "ACF",
  col = report_teal,
  ci.col = accent_orange,
  lwd = 1.5
)
pacf(
  ordinary_difference,
  lag.max = 48,
  main = "Sample PACF",
  xlab = "Lag (years)",
  ylab = "Partial ACF",
  col = report_teal,
  ci.col = accent_orange,
  lwd = 1.5
)
par(mfrow = c(1, 1))
dev.off()

############################################################
# 4. THEORY-DRIVEN CANDIDATE SET
############################################################

candidate_specs <- data.frame(
  Model.ID = c(
    "sd_ar2", "sd_ar3", "sd_arma21",
    "od_ar1", "od_ar2", "od_ar3", "od_arma21", "od_ar2_sarma11"
  ),
  Model = c(
    "SARIMA(2,0,0) x (0,1,1)[12] + trend",
    "SARIMA(3,0,0) x (0,1,1)[12] + trend",
    "SARIMA(2,0,1) x (0,1,1)[12] + trend",
    "SARIMA(1,1,0) x (1,0,0)[12]",
    "SARIMA(2,1,0) x (1,0,0)[12]",
    "SARIMA(3,1,0) x (1,0,0)[12]",
    "SARIMA(2,1,1) x (1,0,0)[12]",
    "SARIMA(2,1,0) x (1,0,1)[12]"
  ),
  Family = c(
    rep("d=0, D=1", 3),
    rep("d=1, D=0", 5)
  ),
  p = c(2, 3, 2, 1, 2, 3, 2, 2),
  d = c(0, 0, 0, 1, 1, 1, 1, 1),
  q = c(0, 0, 1, 0, 0, 0, 1, 0),
  P = c(0, 0, 0, 1, 1, 1, 1, 1),
  D = c(1, 1, 1, 0, 0, 0, 0, 0),
  Q = c(1, 1, 1, 0, 0, 0, 0, 1),
  Trend = c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
  Identification.Basis = c(
    "Parsimonious seasonal-difference AR benchmark",
    "Seasonal-difference PACF and AICc candidate",
    "Seasonal-difference mixed ARMA candidate",
    "Lower-order ordinary-difference AR benchmark",
    "PACF cutoff near lag 2 with seasonal AR dependence",
    "Higher-order AR check around the PACF cutoff",
    "Mixed ARMA check around the PACF cutoff",
    "Residual-driven seasonal MA refinement of the AR(2) model"
  ),
  stringsAsFactors = FALSE
)

multiply_polynomials <- function(first, second) {
  result <- numeric(length(first) + length(second) - 1)
  for (i in seq_along(first)) {
    for (j in seq_along(second)) {
      result[i + j - 1] <- result[i + j - 1] + first[i] * second[j]
    }
  }
  result
}

fit_candidate <- function(series, spec) {
  methods <- c("ML", "CSS-ML", "CSS")
  errors <- character(0)

  for (fit_method in methods) {
    fit <- try(
      suppressWarnings({
        if (isTRUE(spec$Trend)) {
          forecast::Arima(
            series,
            order = c(spec$p, spec$d, spec$q),
            seasonal = list(
              order = c(spec$P, spec$D, spec$Q),
              period = 12
            ),
            xreg = seq_along(series),
            include.mean = FALSE,
            method = fit_method
          )
        } else {
          forecast::Arima(
            series,
            order = c(spec$p, spec$d, spec$q),
            seasonal = list(
              order = c(spec$P, spec$D, spec$Q),
              period = 12
            ),
            include.mean = FALSE,
            include.drift = FALSE,
            method = fit_method
          )
        }
      }),
      silent = TRUE
    )

    if (!inherits(fit, "try-error")) {
      attr(fit, "fit_method") <- fit_method
      return(fit)
    }
    errors <- c(errors, paste(fit_method, as.character(fit)))
  }

  stop(
    "Candidate fit failed for ", spec$Model, ": ",
    paste(errors, collapse = " | "),
    call. = FALSE
  )
}

forecast_candidate <- function(fit, spec, observed_length, horizon) {
  if (isTRUE(spec$Trend)) {
    forecast::forecast(
      fit,
      h = horizon,
      xreg = (observed_length + 1):(observed_length + horizon),
      level = c(80, 95)
    )
  } else {
    forecast::forecast(fit, h = horizon, level = c(80, 95))
  }
}

coefficient_table <- function(fit, model_id, model_label) {
  estimates <- stats::coef(fit)
  standard_errors <- sqrt(diag(fit$var.coef))
  z_values <- estimates / standard_errors
  p_values <- 2 * stats::pnorm(-abs(z_values))

  data.frame(
    Model.ID = model_id,
    Model = model_label,
    Parameter = names(estimates),
    Estimate = as.numeric(estimates),
    Standard.Error = as.numeric(standard_errors),
    z.value = as.numeric(z_values),
    P.value = as.numeric(p_values),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

root_diagnostics <- function(fit, spec) {
  estimates <- stats::coef(fit)

  ar_values <- estimates[paste0("ar", seq_len(spec$p))]
  ar_values <- ar_values[!is.na(ar_values)]
  seasonal_ar_values <- estimates[paste0("sar", seq_len(spec$P))]
  seasonal_ar_values <- seasonal_ar_values[!is.na(seasonal_ar_values)]

  ma_values <- estimates[paste0("ma", seq_len(spec$q))]
  ma_values <- ma_values[!is.na(ma_values)]
  seasonal_ma_values <- estimates[paste0("sma", seq_len(spec$Q))]
  seasonal_ma_values <- seasonal_ma_values[!is.na(seasonal_ma_values)]

  ar_polynomial <- if (length(ar_values) > 0) c(1, -ar_values) else 1
  seasonal_ar_polynomial <- numeric(12 * length(seasonal_ar_values) + 1)
  seasonal_ar_polynomial[1] <- 1
  if (length(seasonal_ar_values) > 0) {
    seasonal_ar_polynomial[12 * seq_along(seasonal_ar_values) + 1] <-
      -seasonal_ar_values
  }

  ma_polynomial <- if (length(ma_values) > 0) c(1, ma_values) else 1
  seasonal_ma_polynomial <- numeric(12 * length(seasonal_ma_values) + 1)
  seasonal_ma_polynomial[1] <- 1
  if (length(seasonal_ma_values) > 0) {
    seasonal_ma_polynomial[12 * seq_along(seasonal_ma_values) + 1] <-
      seasonal_ma_values
  }

  full_ar <- multiply_polynomials(ar_polynomial, seasonal_ar_polynomial)
  full_ma <- multiply_polynomials(ma_polynomial, seasonal_ma_polynomial)

  min_ar_root <- if (length(full_ar) > 1) {
    min(Mod(polyroot(full_ar)))
  } else {
    Inf
  }
  min_ma_root <- if (length(full_ma) > 1) {
    min(Mod(polyroot(full_ma)))
  } else {
    Inf
  }

  data.frame(
    Minimum.AR.Root = min_ar_root,
    Minimum.MA.Root = min_ma_root,
    Valid.Roots = min_ar_root > 1 + 1e-6 && min_ma_root > 1 + 1e-6,
    Near.Boundary = min(c(min_ar_root, min_ma_root)) < 1.01,
    stringsAsFactors = FALSE
  )
}

ljung_box_p <- function(fit, spec, lag) {
  residual_values <- as.numeric(stats::residuals(fit))
  residual_values <- residual_values[is.finite(residual_values)]
  fit_df <- spec$p + spec$q + spec$P + spec$Q
  stats::Box.test(
    residual_values,
    lag = lag,
    type = "Ljung-Box",
    fitdf = fit_df
  )$p.value
}

full_fits <- vector("list", nrow(candidate_specs))
names(full_fits) <- candidate_specs$Model.ID
all_coefficients <- vector("list", nrow(candidate_specs))
screening_rows <- vector("list", nrow(candidate_specs))

for (i in seq_len(nrow(candidate_specs))) {
  spec <- candidate_specs[i, ]
  message("Fitting full-series candidate: ", spec$Model)
  fit <- fit_candidate(X, spec)
  full_fits[[spec$Model.ID]] <- fit

  coefficients <- coefficient_table(fit, spec$Model.ID, spec$Model)
  all_coefficients[[i]] <- coefficients
  roots <- root_diagnostics(fit, spec)
  p_values <- coefficients$P.value
  lb_values <- vapply(
    c(12, 24, 36),
    function(lag) ljung_box_p(fit, spec, lag),
    numeric(1)
  )

  coefficients_significant <- all(p_values < 0.05)
  residuals_adequate <- all(lb_values > 0.05)
  eligible <- coefficients_significant && residuals_adequate && roots$Valid.Roots

  decision <- if (!roots$Valid.Roots) {
    "Excluded: nonstationary or noninvertible fitted roots"
  } else if (!coefficients_significant) {
    "Excluded: one or more structural coefficients are not significant"
  } else if (!residuals_adequate) {
    "Excluded: residual dependence remains in Ljung-Box checks"
  } else {
    "Eligible finalist"
  }

  screening_rows[[i]] <- data.frame(
    Model.ID = spec$Model.ID,
    Model = spec$Model,
    Family = spec$Family,
    Identification.Basis = spec$Identification.Basis,
    Parameters = length(stats::coef(fit)),
    Fit.Method = attr(fit, "fit_method"),
    Sigma.squared = fit$sigma2,
    Log.Likelihood = as.numeric(stats::logLik(fit)),
    AIC = stats::AIC(fit),
    AICc = fit$aicc,
    BIC = stats::BIC(fit),
    Minimum.AR.Root = roots$Minimum.AR.Root,
    Minimum.MA.Root = roots$Minimum.MA.Root,
    Near.Boundary = roots$Near.Boundary,
    Maximum.Coefficient.P = max(p_values),
    Ljung.Box.12.P = lb_values[1],
    Ljung.Box.24.P = lb_values[2],
    Ljung.Box.36.P = lb_values[3],
    Coefficients.Significant = coefficients_significant,
    Residuals.Adequate = residuals_adequate,
    Valid.Roots = roots$Valid.Roots,
    Eligible = eligible,
    Decision = decision,
    stringsAsFactors = FALSE
  )
}

all_coefficients <- do.call(rbind, all_coefficients)
candidate_screening <- do.call(rbind, screening_rows)

candidate_screening$Delta.AICc.Within.Family <- ave(
  candidate_screening$AICc,
  candidate_screening$Family,
  FUN = function(value) value - min(value, na.rm = TRUE)
)

write.csv(
  candidate_screening,
  file.path(result_dir, "candidate_screening.csv"),
  row.names = FALSE
)
write.csv(
  all_coefficients,
  file.path(result_dir, "candidate_coefficients.csv"),
  row.names = FALSE
)

############################################################
# 5. DRIFT SIGNIFICANCE CHECKS
############################################################

fit_with_drift <- function(series, spec) {
  methods <- c("ML", "CSS-ML", "CSS")
  for (fit_method in methods) {
    fit <- try(
      suppressWarnings(
        forecast::Arima(
          series,
          order = c(spec$p, spec$d, spec$q),
          seasonal = list(
            order = c(spec$P, spec$D, spec$Q),
            period = 12
          ),
          include.mean = FALSE,
          include.drift = TRUE,
          method = fit_method
        )
      ),
      silent = TRUE
    )
    if (!inherits(fit, "try-error")) {
      return(fit)
    }
  }
  stop("Drift check failed for ", spec$Model, call. = FALSE)
}

drift_model_ids <- c("od_ar2", "od_ar2_sarma11")
drift_checks <- lapply(drift_model_ids, function(model_id) {
  spec <- candidate_specs[candidate_specs$Model.ID == model_id, ]
  fit <- fit_with_drift(X, spec)
  estimates <- stats::coef(fit)
  standard_errors <- sqrt(diag(fit$var.coef))
  drift_index <- which(names(estimates) == "drift")
  drift_p <- 2 * stats::pnorm(
    -abs(estimates[drift_index] / standard_errors[drift_index])
  )

  data.frame(
    Model.ID = model_id,
    Model = spec$Model,
    Drift.Estimate = estimates[drift_index],
    Drift.Standard.Error = standard_errors[drift_index],
    Drift.P.value = drift_p,
    Decision = if (drift_p < 0.05) "Retain drift" else "Omit drift",
    stringsAsFactors = FALSE,
    row.names = NULL
  )
})
drift_checks <- do.call(rbind, drift_checks)
write.csv(drift_checks, file.path(result_dir, "drift_checks.csv"), row.names = FALSE)

if (any(drift_checks$Drift.P.value < 0.05)) {
  stop("A retained ordinary-difference model requires drift; review the specification.")
}

############################################################
# 6. EXPANDING-WINDOW FORECAST VALIDATION
############################################################

validation_initial <- 120
validation_horizon <- 24
validation_origins <- validation_initial:(length(X) - validation_horizon)

error_metrics <- function(errors) {
  data.frame(
    RMSE.1 = sqrt(mean(errors[, 1]^2)),
    MAE.1 = mean(abs(errors[, 1])),
    RMSE.12 = sqrt(mean(errors[, 12]^2)),
    MAE.12 = mean(abs(errors[, 12])),
    RMSE.24 = sqrt(mean(errors[, 24]^2)),
    MAE.24 = mean(abs(errors[, 24])),
    RMSE.All = sqrt(mean(errors^2)),
    MAE.All = mean(abs(errors)),
    stringsAsFactors = FALSE
  )
}

validation_rows <- vector("list", nrow(candidate_specs))

for (i in seq_len(nrow(candidate_specs))) {
  spec <- candidate_specs[i, ]
  message("Rolling validation: ", spec$Model)
  errors <- matrix(
    NA_real_,
    nrow = length(validation_origins),
    ncol = validation_horizon
  )

  for (j in seq_along(validation_origins)) {
    origin <- validation_origins[j]
    training_series <- ts(
      as.numeric(X)[seq_len(origin)],
      start = start(X),
      frequency = frequency(X)
    )
    fit <- fit_candidate(training_series, spec)
    predicted <- forecast_candidate(
      fit,
      spec,
      origin,
      validation_horizon
    )
    actual <- as.numeric(X[(origin + 1):(origin + validation_horizon)])
    errors[j, ] <- as.numeric(predicted$mean) - actual
  }

  validation_rows[[i]] <- cbind(
    data.frame(
      Type = "SARIMA candidate",
      Model.ID = spec$Model.ID,
      Model = spec$Model,
      Origins = length(validation_origins),
      stringsAsFactors = FALSE
    ),
    error_metrics(errors)
  )
}

benchmark_errors <- function(method) {
  errors <- matrix(
    NA_real_,
    nrow = length(validation_origins),
    ncol = validation_horizon
  )

  for (j in seq_along(validation_origins)) {
    origin <- validation_origins[j]
    training_values <- as.numeric(X)[seq_len(origin)]
    actual <- as.numeric(X[(origin + 1):(origin + validation_horizon)])

    predicted <- if (method == "seasonal_naive") {
      rep(tail(training_values, 12), length.out = validation_horizon)
    } else {
      slope <- (tail(training_values, 1) - training_values[1]) /
        (length(training_values) - 1)
      tail(training_values, 1) + seq_len(validation_horizon) * slope
    }
    errors[j, ] <- predicted - actual
  }
  error_metrics(errors)
}

seasonal_naive_metrics <- benchmark_errors("seasonal_naive")
drift_benchmark_metrics <- benchmark_errors("random_walk_drift")

benchmark_rows <- rbind(
  cbind(
    data.frame(
      Type = "Benchmark",
      Model.ID = "seasonal_naive",
      Model = "Seasonal naive",
      Origins = length(validation_origins),
      stringsAsFactors = FALSE
    ),
    seasonal_naive_metrics
  ),
  cbind(
    data.frame(
      Type = "Benchmark",
      Model.ID = "random_walk_drift",
      Model = "Random walk with drift",
      Origins = length(validation_origins),
      stringsAsFactors = FALSE
    ),
    drift_benchmark_metrics
  )
)

rolling_validation <- rbind(do.call(rbind, validation_rows), benchmark_rows)
write.csv(
  rolling_validation,
  file.path(result_dir, "rolling_validation.csv"),
  row.names = FALSE
)

############################################################
# 7. FINALIST COMPARISON AND DETERMINISTIC SELECTION
############################################################

eligible_screening <- candidate_screening[candidate_screening$Eligible, ]
if (nrow(eligible_screening) < 2) {
  stop("Fewer than two diagnostically adequate SARIMA finalists remain.")
}

finalist_validation <- rolling_validation[
  rolling_validation$Model.ID %in% eligible_screening$Model.ID,
]
finalist_comparison <- merge(
  eligible_screening,
  finalist_validation,
  by = c("Model.ID", "Model"),
  sort = FALSE
)
finalist_comparison <- finalist_comparison[
  match(eligible_screening$Model.ID, finalist_comparison$Model.ID),
]

best_rmse <- min(finalist_comparison$RMSE.All)
near_best <- finalist_comparison[
  finalist_comparison$RMSE.All <= best_rmse * 1.02,
]
near_best <- near_best[
  order(
    near_best$MAE.All,
    near_best$Parameters,
    near_best$Delta.AICc.Within.Family
  ),
]
selected_id <- near_best$Model.ID[1]

ranked_finalists <- finalist_comparison[
  order(finalist_comparison$RMSE.All, finalist_comparison$MAE.All),
]
runner_up_id <- ranked_finalists$Model.ID[
  ranked_finalists$Model.ID != selected_id
][1]

finalist_comparison$Selection <- ifelse(
  finalist_comparison$Model.ID == selected_id,
  "Selected",
  ifelse(finalist_comparison$Model.ID == runner_up_id, "Runner-up", "Finalist")
)
write.csv(
  finalist_comparison,
  file.path(result_dir, "finalist_comparison.csv"),
  row.names = FALSE
)

expected_selected_id <- "od_ar2_sarma11"
if (!identical(selected_id, expected_selected_id)) {
  stop(
    "The reproducible selection did not confirm the expected final model. ",
    "Selected: ", selected_id,
    call. = FALSE
  )
}

selected_spec <- candidate_specs[candidate_specs$Model.ID == selected_id, ]
runner_up_spec <- candidate_specs[candidate_specs$Model.ID == runner_up_id, ]
selected_fit <- full_fits[[selected_id]]
runner_up_fit <- full_fits[[runner_up_id]]

selected_validation <- rolling_validation[
  rolling_validation$Model.ID == selected_id,
]
runner_up_validation <- rolling_validation[
  rolling_validation$Model.ID == runner_up_id,
]
benchmark_validation <- rolling_validation[
  rolling_validation$Type == "Benchmark",
]

if (
  selected_validation$RMSE.All >= runner_up_validation$RMSE.All ||
  any(selected_validation$RMSE.All >= benchmark_validation$RMSE.All)
) {
  stop("The selected model did not outperform the runner-up and both benchmarks.")
}

selected_coefficients <- coefficient_table(
  selected_fit,
  selected_id,
  selected_spec$Model
)
runner_up_coefficients <- coefficient_table(
  runner_up_fit,
  runner_up_id,
  runner_up_spec$Model
)
write.csv(
  selected_coefficients,
  file.path(result_dir, "selected_model_coefficients.csv"),
  row.names = FALSE
)
write.csv(
  runner_up_coefficients,
  file.path(result_dir, "runner_up_model_coefficients.csv"),
  row.names = FALSE
)

model_summary_text <- function(spec, fit, validation, role) {
  screening <- candidate_screening[
    candidate_screening$Model.ID == spec$Model.ID,
  ]
  coefficients <- coefficient_table(fit, spec$Model.ID, spec$Model)
  c(
    paste(role, ": ", spec$Model, sep = ""),
    paste("Differencing family:", spec$Family),
    paste("Fit method:", attr(fit, "fit_method")),
    paste("Residual variance:", sprintf("%.6f", fit$sigma2)),
    paste("AICc (within-family use only):", sprintf("%.4f", fit$aicc)),
    paste("BIC (within-family use only):", sprintf("%.4f", stats::BIC(fit))),
    paste(
      "Ljung-Box p-values at lags 12, 24, and 36:",
      paste(
        sprintf(
          "%.4f",
          c(
            screening$Ljung.Box.12.P,
            screening$Ljung.Box.24.P,
            screening$Ljung.Box.36.P
          )
        ),
        collapse = ", "
      )
    ),
    paste("Aggregate validation RMSE:", sprintf("%.4f", validation$RMSE.All)),
    paste("Aggregate validation MAE:", sprintf("%.4f", validation$MAE.All)),
    "",
    "Coefficients:",
    paste(
      sprintf(
        "%s = %.6f (SE = %.6f, p = %.6g)",
        coefficients$Parameter,
        coefficients$Estimate,
        coefficients$Standard.Error,
        coefficients$P.value
      ),
      collapse = "\n"
    )
  )
}

writeLines(
  model_summary_text(
    selected_spec,
    selected_fit,
    selected_validation,
    "Selected model"
  ),
  file.path(result_dir, "selected_model_summary.txt")
)
writeLines(
  model_summary_text(
    runner_up_spec,
    runner_up_fit,
    runner_up_validation,
    "Runner-up model"
  ),
  file.path(result_dir, "runner_up_model_summary.txt")
)

############################################################
# 8. DIAGNOSTIC FIGURES
############################################################

diagnostic_plot <- function(fit, spec, title) {
  residual_values <- as.numeric(stats::residuals(fit))
  residual_values <- residual_values[is.finite(residual_values)]
  standardized_residuals <- residual_values / stats::sd(residual_values)
  fit_df <- spec$p + spec$q + spec$P + spec$Q
  diagnostic_lags <- seq(max(5, fit_df + 1), 36)
  lb_p_values <- vapply(
    diagnostic_lags,
    function(lag) {
      stats::Box.test(
        residual_values,
        lag = lag,
        type = "Ljung-Box",
        fitdf = fit_df
      )$p.value
    },
    numeric(1)
  )

  report_style(c(4.2, 4.3, 3, 1))
  par(mfrow = c(2, 2))
  plot(
    standardized_residuals,
    type = "l",
    col = report_teal,
    lwd = 1.2,
    main = "Standardized Residuals",
    xlab = "Observation",
    ylab = "Residual"
  )
  abline(h = 0, col = "gray50", lty = 2)
  acf(
    residual_values,
    lag.max = 36,
    main = "Residual ACF",
    xlab = "Lag",
    ylab = "ACF",
    col = report_teal,
    ci.col = accent_orange
  )
  stats::qqnorm(
    standardized_residuals,
    main = "Normal Q-Q Plot",
    xlab = "Theoretical Quantiles",
    ylab = "Sample Quantiles",
    col = report_teal,
    pch = 1
  )
  stats::qqline(standardized_residuals, col = accent_orange, lwd = 1.5)
  plot(
    diagnostic_lags,
    lb_p_values,
    type = "o",
    pch = 1,
    col = report_teal,
    ylim = c(0, 1),
    main = "Ljung-Box p-values",
    xlab = "Lag",
    ylab = "p-value"
  )
  abline(h = 0.05, col = accent_orange, lty = 2, lwd = 1.5)
  mtext(title, outer = TRUE, side = 3, line = -1.2, font = 2, col = report_teal)
  par(mfrow = c(1, 1))
}

open_png("Figure_05_Selected_Model_Diagnostics.png", 8, 8)
par(oma = c(0, 0, 2, 0))
diagnostic_plot(selected_fit, selected_spec, selected_spec$Model)
dev.off()

open_png("Figure_06_Runner_Up_Model_Diagnostics.png", 8, 8)
par(oma = c(0, 0, 2, 0))
diagnostic_plot(runner_up_fit, runner_up_spec, runner_up_spec$Model)
dev.off()

############################################################
# 9. FINAL 24-MONTH FORECAST
############################################################

forecast_horizon <- 24
final_forecast <- forecast_candidate(
  selected_fit,
  selected_spec,
  length(X),
  forecast_horizon
)

forecast_dates <- seq(
  from = max(chicken_data$date),
  by = "month",
  length.out = forecast_horizon + 1
)[-1]

forecast_results <- data.frame(
  Date = forecast_dates,
  Point.Forecast = round(as.numeric(final_forecast$mean), 3),
  Lower.80 = round(as.numeric(final_forecast$lower[, "80%"]), 3),
  Upper.80 = round(as.numeric(final_forecast$upper[, "80%"]), 3),
  Lower.95 = round(as.numeric(final_forecast$lower[, "95%"]), 3),
  Upper.95 = round(as.numeric(final_forecast$upper[, "95%"]), 3),
  stringsAsFactors = FALSE
)
write.csv(
  forecast_results,
  file.path(result_dir, "forecast_24_months.csv"),
  row.names = FALSE
)

forecast_time <- as.numeric(time(final_forecast$mean))
observed_time <- as.numeric(time(X))
lower_80 <- as.numeric(final_forecast$lower[, "80%"])
upper_80 <- as.numeric(final_forecast$upper[, "80%"])
lower_95 <- as.numeric(final_forecast$lower[, "95%"])
upper_95 <- as.numeric(final_forecast$upper[, "95%"])

open_png("Figure_07_Twenty_Four_Month_Forecast.png", 7.5, 5.5)
report_style()
plot(
  observed_time,
  as.numeric(X),
  type = "l",
  xlim = range(c(observed_time, forecast_time)),
  ylim = range(c(as.numeric(X), lower_95, upper_95), na.rm = TRUE),
  xlab = "Year",
  ylab = "Chicken price (cents per pound)",
  main = "Twenty-Four-Month Forecast of Chicken Prices",
  col = report_teal,
  lwd = 1.5,
  xaxp = c(2002, 2018, 8)
)
polygon(
  c(forecast_time, rev(forecast_time)),
  c(lower_95, rev(upper_95)),
  border = NA,
  col = grDevices::adjustcolor(report_teal, alpha.f = 0.15)
)
polygon(
  c(forecast_time, rev(forecast_time)),
  c(lower_80, rev(upper_80)),
  border = NA,
  col = grDevices::adjustcolor(report_teal, alpha.f = 0.30)
)
lines(observed_time, as.numeric(X), col = report_teal, lwd = 1.5)
lines(
  forecast_time,
  as.numeric(final_forecast$mean),
  col = accent_orange,
  lwd = 2
)
legend(
  "topleft",
  legend = c("Observed", "Forecast", "80% interval", "95% interval"),
  col = c(report_teal, accent_orange, soft_teal, soft_teal),
  lty = c(1, 1, NA, NA),
  lwd = c(1.5, 2, NA, NA),
  pch = c(NA, NA, 15, 15),
  pt.cex = c(NA, NA, 2, 2),
  bty = "n",
  cex = 0.8
)
dev.off()

############################################################
# 10. FINAL ASSERTIONS AND SESSION INFORMATION
############################################################

if (
  nrow(forecast_results) != 24 ||
  forecast_results$Date[1] != as.Date("2016-08-01") ||
  tail(forecast_results$Date, 1) != as.Date("2018-07-01")
) {
  stop("The final forecast dates are not August 2016 through July 2018.")
}

if (
  any(selected_coefficients$P.value >= 0.05) ||
  any(
    candidate_screening[
      candidate_screening$Model.ID == selected_id,
      c("Ljung.Box.12.P", "Ljung.Box.24.P", "Ljung.Box.36.P")
    ] <= 0.05
  )
) {
  stop("The selected model failed the final coefficient or residual checks.")
}

session_lines <- sub("[[:space:]]+$", "", capture.output(sessionInfo()))
writeLines(session_lines, file.path(result_dir, "session_info.txt"))

message("Analysis complete.")
message("Selected model: ", selected_spec$Model)
message("Runner-up model: ", runner_up_spec$Model)
message("Figures and consolidated results were written to the repository.")
