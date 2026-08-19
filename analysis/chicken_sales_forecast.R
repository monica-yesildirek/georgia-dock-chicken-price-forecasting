############################################################
# CHICKEN PRICE TIME SERIES FORECASTING
# Reproducible portfolio analysis
############################################################

required_packages <- c("astsa", "forecast", "fUnitRoots")
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

# astsa uses a multiplication symbol in diagnostic plot labels. Explicitly
# select a UTF-8 Windows locale when available so the symbol renders cleanly.
if (.Platform$OS.type == "windows") {
  try(Sys.setlocale("LC_CTYPE", "English_United States.utf8"), silent = TRUE)
}

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)

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

############################################################
# 2. SHARED FIGURE STYLE
############################################################

report_teal <- "#156082"
accent_orange <- "#C55A11"
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

report_style <- function() {
  par(
    family = report_font,
    col = report_teal,
    col.main = report_teal,
    col.lab = "black",
    col.axis = "black",
    fg = "black",
    lwd = 1.5,
    font.main = 2,
    cex.main = 1.15,
    cex.lab = 1,
    cex.axis = 0.9,
    mar = c(4.5, 4.5, 3, 1),
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
  ylab = "Chicken price",
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

Y <- diff(X, lag = 12)

open_png("Figure_03_Seasonal_Difference_ACF.png", 7.5, 7)
report_style()
par(mfrow = c(2, 1), mar = c(3.8, 4.5, 2.7, 1))
acf(
  Y,
  lag.max = 48,
  xlab = "Lag (years)",
  ylab = "ACF",
  main = "Sample ACF of the Seasonally Differenced Series",
  col = report_teal,
  ci.col = accent_orange,
  lwd = 1.5
)
plot(
  Y,
  xlab = "Year",
  ylab = "Lag-12 difference",
  main = "Seasonally Differenced Chicken Series",
  col = report_teal,
  lwd = 1.5,
  xaxp = c(2004, 2016, 6)
)
par(mfrow = c(1, 1))
dev.off()

adf_original <- fUnitRoots::adfTest(X, lags = 5, type = "c")
adf_seasonal <- fUnitRoots::adfTest(Y, lags = 5, type = "c")
adf_results <- data.frame(
  Series = c("Original series", "Lag-12 differenced series"),
  P.value = c(
    as.numeric(adf_original@test$p.value),
    as.numeric(adf_seasonal@test$p.value)
  )
)
write.csv(
  adf_results,
  file.path(result_dir, "adf_test.csv"),
  row.names = FALSE
)

############################################################
# 4. MODEL IDENTIFICATION
############################################################

open_png("Figure_04_ACF_PACF_Stationary_Series.png", 8, 4.5)
report_style()
par(mfrow = c(1, 2), mar = c(4.5, 4.3, 3, 1))
acf(
  Y,
  lag.max = 48,
  main = "Sample ACF",
  xlab = "Lag (years)",
  ylab = "ACF",
  col = report_teal,
  ci.col = accent_orange,
  lwd = 1.5
)
pacf(
  Y,
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

auto_output <- capture.output(
  auto_search <- forecast::auto.arima(
    Y,
    stationary = TRUE,
    seasonal = TRUE,
    ic = "aicc",
    trace = TRUE,
    stepwise = FALSE,
    approximation = FALSE
  )
)
writeLines(auto_output, file.path(result_dir, "auto_arima_trace.txt"))

############################################################
# 5. CANDIDATE FITTING AND COMPARISON
############################################################

final_output <- capture.output(
  final_fit <- astsa::sarima(
    X, 3, 0, 0, 0, 1, 1, 12,
    details = FALSE,
    no.constant = FALSE
  )
)
competing_output <- capture.output(
  competing_fit <- astsa::sarima(
    X, 2, 0, 1, 0, 1, 1, 12,
    details = FALSE,
    no.constant = FALSE
  )
)
simpler_output <- capture.output(
  simpler_fit <- astsa::sarima(
    X, 2, 0, 0, 0, 1, 1, 12,
    details = FALSE,
    no.constant = FALSE
  )
)

# External benchmark retained from the written report.
benchmark_output <- capture.output(
  benchmark_fit <- astsa::sarima(
    X, 2, 1, 0, 1, 0, 0, 12,
    details = FALSE,
    no.constant = FALSE
  )
)

writeLines(final_output, file.path(result_dir, "final_model_summary.txt"))
writeLines(
  competing_output,
  file.path(result_dir, "competing_model_summary.txt")
)
writeLines(simpler_output, file.path(result_dir, "simpler_model_summary.txt"))

tidy_coefficients <- function(fit, model_name) {
  coefficient_table <- as.data.frame(fit$t.table)
  data.frame(
    Model = model_name,
    Parameter = rownames(coefficient_table),
    Estimate = coefficient_table[, 1],
    Standard.Error = coefficient_table[, 2],
    t.value = coefficient_table[, 3],
    p.value = coefficient_table[, 4],
    row.names = NULL,
    check.names = FALSE
  )
}

write.csv(
  tidy_coefficients(final_fit, "SARIMA(3,0,0)x(0,1,1)[12]"),
  file.path(result_dir, "final_model_coefficients.csv"),
  row.names = FALSE
)
write.csv(
  tidy_coefficients(competing_fit, "SARIMA(2,0,1)x(0,1,1)[12]"),
  file.path(result_dir, "competing_model_coefficients.csv"),
  row.names = FALSE
)
write.csv(
  tidy_coefficients(simpler_fit, "SARIMA(2,0,0)x(0,1,1)[12]"),
  file.path(result_dir, "simpler_model_coefficients.csv"),
  row.names = FALSE
)

estimate_se <- function(fit, parameter) {
  if (!parameter %in% rownames(fit$t.table)) {
    return("--")
  }
  sprintf(
    "%.4f (%.4f)",
    fit$t.table[parameter, 1],
    fit$t.table[parameter, 2]
  )
}

formatted_p <- function(fit, parameter) {
  if (!parameter %in% rownames(fit$t.table)) {
    return("--")
  }
  value <- fit$t.table[parameter, 4]
  if (value < 0.001) {
    "< .001"
  } else {
    sub("^0", "", sprintf("%.3f", value))
  }
}

parameters <- c("ar1", "ar2", "ar3", "ma1", "sma1", "constant")
parameter_labels <- c(
  "AR(1)", "AR(2)", "AR(3)", "MA(1)", "Seasonal MA(1)", "Drift"
)

coefficient_comparison <- data.frame(
  Parameter = parameter_labels,
  `Leading Estimate (SE)` = vapply(
    parameters, function(parameter) estimate_se(final_fit, parameter), character(1)
  ),
  `Leading p` = vapply(
    parameters, function(parameter) formatted_p(final_fit, parameter), character(1)
  ),
  `Competing Estimate (SE)` = vapply(
    parameters,
    function(parameter) estimate_se(competing_fit, parameter),
    character(1)
  ),
  `Competing p` = vapply(
    parameters,
    function(parameter) formatted_p(competing_fit, parameter),
    character(1)
  ),
  check.names = FALSE,
  row.names = NULL
)
write.csv(
  coefficient_comparison,
  file.path(result_dir, "model_coefficients_table.csv"),
  row.names = FALSE
)

model_row <- function(fit, model_name) {
  data.frame(
    Model = model_name,
    Parameters = length(fit$fit$coef),
    Sigma.squared = fit$fit$sigma2,
    Log.Likelihood = fit$fit$loglik,
    AIC = unname(fit$ICs["AIC"]),
    AICc = unname(fit$ICs["AICc"]),
    BIC = unname(fit$ICs["BIC"])
  )
}

model_comparison <- rbind(
  model_row(final_fit, "SARIMA(3,0,0)x(0,1,1)[12]"),
  model_row(competing_fit, "SARIMA(2,0,1)x(0,1,1)[12]"),
  model_row(simpler_fit, "SARIMA(2,0,0)x(0,1,1)[12]")
)
model_comparison$Delta.AICc <-
  model_comparison$AICc - min(model_comparison$AICc)
write.csv(
  model_comparison,
  file.path(result_dir, "model_comparison.csv"),
  row.names = FALSE
)

############################################################
# 6. MODEL DIAGNOSTICS
############################################################

open_png("Figure_05_Final_Model_Diagnostics.png", 8, 8)
par(family = report_font)
invisible(capture.output(
  astsa::sarima(X, 3, 0, 0, 0, 1, 1, 12, no.constant = FALSE)
))
dev.off()

open_png("Figure_06_Competing_Model_Diagnostics.png", 8, 8)
par(family = report_font)
invisible(capture.output(
  astsa::sarima(X, 2, 0, 1, 0, 1, 1, 12, no.constant = FALSE)
))
dev.off()

############################################################
# 7. FINAL MODEL AND 24-MONTH FORECAST
############################################################

forecast_horizon <- 24
trend <- seq_along(X)

forecast_fit <- forecast::Arima(
  X,
  order = c(3, 0, 0),
  seasonal = list(order = c(0, 1, 1), period = 12),
  xreg = trend,
  include.mean = FALSE
)

future_trend <- (length(X) + 1):(length(X) + forecast_horizon)
final_forecast <- forecast::forecast(
  forecast_fit,
  h = forecast_horizon,
  xreg = future_trend,
  level = c(80, 95)
)

forecast_mean <- final_forecast$mean
lower_80 <- final_forecast$lower[, "80%"]
upper_80 <- final_forecast$upper[, "80%"]
lower_95 <- final_forecast$lower[, "95%"]
upper_95 <- final_forecast$upper[, "95%"]

forecast_results <- data.frame(
  Time = round(as.numeric(time(forecast_mean)), 6),
  Point.Forecast = round(as.numeric(forecast_mean), 3),
  Lower.80 = round(as.numeric(lower_80), 3),
  Upper.80 = round(as.numeric(upper_80), 3),
  Lower.95 = round(as.numeric(lower_95), 3),
  Upper.95 = round(as.numeric(upper_95), 3)
)
forecast_output <- data.frame(
  Time = sub("\\.?0+$", "", sprintf("%.6f", forecast_results$Time)),
  Point.Forecast = sprintf("%.3f", forecast_results$Point.Forecast),
  Lower.80 = sprintf("%.3f", forecast_results$Lower.80),
  Upper.80 = sprintf("%.3f", forecast_results$Upper.80),
  Lower.95 = sprintf("%.3f", forecast_results$Lower.95),
  Upper.95 = sprintf("%.3f", forecast_results$Upper.95),
  check.names = FALSE
)
write.table(
  forecast_output,
  file.path(result_dir, "forecast_24_months.csv"),
  row.names = FALSE,
  col.names = TRUE,
  quote = FALSE,
  sep = ","
)

forecast_time <- as.numeric(time(forecast_mean))
observed_time <- as.numeric(time(X))

open_png("Figure_07_Twenty_Four_Month_Forecast.png", 7.5, 5.5)
report_style()
plot(
  observed_time,
  as.numeric(X),
  type = "l",
  xlim = range(c(observed_time, forecast_time)),
  ylim = range(c(as.numeric(X), lower_95, upper_95), na.rm = TRUE),
  xlab = "Year",
  ylab = "Chicken price",
  main = "Twenty-Four-Month Forecast of Chicken Prices",
  col = report_teal,
  lwd = 1.5,
  xaxp = c(2002, 2018, 8)
)
polygon(
  c(forecast_time, rev(forecast_time)),
  c(as.numeric(lower_95), rev(as.numeric(upper_95))),
  border = NA,
  col = grDevices::adjustcolor(report_teal, alpha.f = 0.15)
)
polygon(
  c(forecast_time, rev(forecast_time)),
  c(as.numeric(lower_80), rev(as.numeric(upper_80))),
  border = NA,
  col = grDevices::adjustcolor(report_teal, alpha.f = 0.30)
)
lines(observed_time, as.numeric(X), col = report_teal, lwd = 1.5)
lines(
  forecast_time,
  as.numeric(forecast_mean),
  col = report_teal,
  lwd = 2
)
dev.off()

writeLines(
  capture.output(sessionInfo()),
  file.path(result_dir, "session_info.txt")
)

message("Analysis complete. Figures and results were written to the repository.")
