#!/usr/bin/env Rscript
# dplyr_claims.R

# 20261101
# 0.0.0

# The R/dplyr snippets in COMPARISON.md, in the document's order, each run against
# small inline data, followed by the probes behind its claims about R and dplyr.
#
# Each step prints its label and its result, or the condition it signalled, so a
# claim that something fails or warns is shown doing so.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(zoo)
})

show <- function(label, expr) {
  cat('##', label, '\n')
  withCallingHandlers(
    tryCatch(print(expr), error = function(e) cat('raises', conditionMessage(e), '\n')),
    warning = function(w) { cat('warns', conditionMessage(w), '\n'); invokeRestart('muffleWarning') },
    message = function(m) { cat('messages', conditionMessage(m)); invokeRestart('muffleMessage') }
  )
  cat('\n')
}

cat('R', paste(R.version$major, R.version$minor, sep = '.'),
  '| dplyr', as.character(packageVersion('dplyr')),
  '| tidyr', as.character(packageVersion('tidyr')),
  '| tibble', as.character(packageVersion('tibble')),
  '| zoo', as.character(packageVersion('zoo')), '\n\n')

df <- tibble(
  symbol = c('BHP', 'RIO', 'BHP', 'WES'),
  exchange = 'ASX',
  quarter = c('Q1', 'Q1', 'Q2', 'Q2'),
  close = c(42.5, 118.3, 43.1, 15.0),
  pe = c(12.0, NA, 16.0, 9.0),
  volume = c(100, 200, 0, 50),
  price = c(10.0, 20.0, 11.0, 5.0),
  quantity = c(3, 2, 4, 10),
  cost = c(20.0, 30.0, 25.0, 40.0)
)


# Ingestion and schema

show('Schema-free instantiation', tibble(symbol = c('BHP', 'RIO'), close = c(42.5, 118.3)))
show('claim: a tibble keeps no row names', has_rownames(as_tibble(data.frame(close = 42.5, row.names = 'BHP'))))

show('No index', filter(df, symbol == 'BHP'))
show('No index, another column', filter(df, close == 42.5))


# Selection

show('Keyword selection', filter(df, symbol == 'BHP', quarter == 'Q1'))
show('Array selection', filter(df, quarter %in% c('Q1', 'Q2')))
show('Range selection', filter(df, between(close, 10.0, 20.0)))

show('Proc selection', filter(df, !is.na(pe), pe < 15))
my_predicate <- function(pe) !is.na(pe) & pe < 15
show('Proc selection, a vectorised function', filter(df, my_predicate(pe)))
scalar_predicate <- function(v) !is.na(v) && v < 15
show('claim: a scalar predicate must be mapped over the column', filter(df, scalar_predicate(pe)))
show('claim: ...mapped with sapply', filter(df, sapply(pe, scalar_predicate)))

show('Regex selection', filter(df, grepl("^BH", symbol)))

show('Mixed selection', filter(df,
    grepl("^BH", symbol),
    between(close, 10.0, 50.0),
    !is.na(pe), pe < 15,
    quarter == 'Q1'
))


# Projection and contraction

show('Projection', select(df, symbol, close))
show('Contraction', select(df, -symbol, -close))
show('Combined selection and projection', df %>% filter(quarter == 'Q1') %>% select(symbol, close))


# Formulae

show('Computed dimension', df %>% mutate(revenue = price * quantity) %>% select(revenue))
show('Formula chain', df %>% mutate(
    revenue = price * quantity,
    profit = revenue - cost,
    margin = profit / revenue
) %>% select(revenue, profit, margin))
show('claim: formula chain out of order', df %>% mutate(profit = revenue - cost, revenue = price * quantity))

prices <- tibble(
  symbol = rep(c('BHP', 'RIO'), each = 25),
  date = rep(as.Date('2025-01-01') + 0:24, 2),
  close = c(40 + 0:24, 110 + 0:24),
  volume = rep(1000 + 10 * 0:24, 2)
)

show('claim: rollmean centres the window by default',
  prices %>% group_by(symbol) %>% mutate(sma_20 = zoo::rollmean(close, 20, fill = NA)) %>% filter(symbol == 'BHP') %>% pull(sma_20))
show('Two-arity formulae, align = "right" trailing the window',
  prices %>% group_by(symbol) %>% mutate(sma_20 = zoo::rollmean(close, 20, fill = NA, align = 'right')) %>% filter(symbol == 'BHP') %>% pull(sma_20))

sma <- function(x, n) zoo::rollmean(x, n, fill = NA, align = 'right')
show('Parameterised formulae', prices %>% group_by(symbol) %>% mutate(
    sma_close_20 = sma(close, 20),
    sma_volume_50 = sma(volume, 50)
) %>% tail(3))


# Composition

ohlcv <- tibble(
  symbol = c('BHP', 'BHP', 'RIO'), exchange = 'ASX',
  date = as.Date(c('2025-03-31', '2025-07-01', '2025-07-01')), close = c(42.5, 44.0, 118.3)
)
fundamentals <- tibble(
  symbol = c('BHP', 'BHP', 'RIO'), exchange = 'ASX',
  quarter_end = as.Date(c('2024-12-31', '2025-06-30', '2025-06-30')), pe = c(11.0, 12.0, 9.0)
)

show('Equi-join', inner_join(ohlcv, fundamentals, by = c('symbol', 'exchange')))
show('claim: inner_join with no by', inner_join(ohlcv, fundamentals))
show('claim: a rolling join with join_by(closest())',
  left_join(ohlcv, fundamentals, by = join_by(symbol, exchange, closest(date >= quarter_end))))
show('claim: an inequality join', inner_join(ohlcv, fundamentals, by = join_by(symbol, date >= quarter_end)))

show('Cartesian product, tidyr::crossing', crossing(ohlcv %>% select(symbol, close), fundamentals %>% select(pe)))
show('claim: dplyr::cross_join', cross_join(ohlcv %>% select(symbol, close), fundamentals %>% select(pe)))

combined <- cross_join(ohlcv %>% select(symbol, close), fundamentals %>% select(pe))
show('Decomposition', combined %>% select(-any_of(names(ohlcv))) %>% distinct())


# Aggregation

show('Group-by-aggregate', df %>% group_by(symbol) %>% summarise(mean_close = mean(close)))
show('Group by an inline expression', group_by(df, value_score = pe < 10) %>% summarise(mean_close = mean(close)))
grouped <- group_by(df, symbol)
show('claim: the grouped tibble can be held and queried again', list(class(grouped), summarise(grouped, mean(close)), summarise(grouped, max(close))))


# Set operators

a <- tibble(x = c(1, 2))
b <- tibble(x = c(2, 3))
show('Concatenation', bind_rows(a, b))
show('Intersection', intersect(a, b))
show('Union', union(a, b))
show('Difference', setdiff(a, b))
show('claim: symmetric difference', symdiff(a, b))
show('claim: set operations dedupe', intersect(tibble(x = c(1, 1)), tibble(x = c(1, 1))))

today <- tibble(symbol = c('BHP', 'RIO', 'WES'))
exclusions <- tibble(symbol = 'RIO')
yesterday <- tibble(symbol = c('BHP', 'RIO'))
show('Keyed anti-join', anti_join(today, exclusions, by = 'symbol'))

status <- if (setequal(today, yesterday)) {
  'no change'
} else if (nrow(setdiff(yesterday, today)) == 0) {
  paste('added', nrow(setdiff(today, yesterday)), 'candidates')
} else if (nrow(setdiff(today, yesterday)) == 0) {
  paste('removed', nrow(setdiff(yesterday, today)), 'candidates')
} else {
  paste('churn:', nrow(symdiff(today, yesterday)), 'differing')
}
show("claim: the worked example in dplyr's own set operations", status)


# Type handling

show('Type agnosticism', df %>% mutate(
    label = paste0(symbol, " (", exchange, ")"),
    status = ifelse(volume > 0, 'active', 'suspended')
) %>% filter(status == 'active') %>% pull(label))
show('claim: paste puts a space between every part', df %>% mutate(label = paste(symbol, "(", exchange, ")")) %>% pull(label))


# Enumerable integration

show('rowwise', df %>% mutate(revenue = price * quantity, tax = 1) %>% rowwise() %>% mutate(total = revenue + tax) %>% pull(total))
show('Filtering returns a tibble', class(filter(df, close > 40)))
show('Sorting', arrange(df, close) %>% pull(close))


# Comparison

c1 <- tibble(x = c(1, 2), y = c('a', 'b'))
c2 <- c1[2:1, ]
show('identical, same rows in another order', identical(c1, c2))
show('all.equal, same rows in another order', all.equal(c1, c2))
show('claim: setequal ignores row order', setequal(c1, c2))

incoming <- tibble(date = NA, symbol = 'BHP', open = 0, high = 0, low = 0, close = 0, volume = 0)
matches_ohlcv <- function(df) all(c('symbol', 'date', 'open', 'high', 'low', 'close', 'volume') %in% colnames(df))
show('Schema dispatch, predicate function', if (matches_ohlcv(incoming)) 'ohlcv' else 'unknown')

show('Subset, as the document has it', nrow(intersect(tibble(x = 1), tibble(x = c(1, 2)))) == nrow(tibble(x = 1)))
show('claim: the intersect test with duplicates in a', nrow(intersect(tibble(x = c(1, 1)), tibble(x = c(1, 2)))) == 2)


# Introspection

v <- tibble(symbol = c('BHP', 'RIO', 'BHP'), close = c(42.5, 118.3, 43.1))
show('Dimensions', colnames(v))
show('Coordinates', unique(v$symbol))
show('Values', v$symbol)
show('as.list', as.list(v))


# What Namo doesn't have

show('Reshaping', c(exists('pivot_wider'), exists('pivot_longer')))
show('Missing values', list(mean(c(1, NA), na.rm = TRUE), drop_na(tibble(x = c(1, NA))), replace_na(c(1, NA), 0)))
show('Column-level operations', c(mean(df$close), sd(df$close)))
show('Readers in base R', c(exists('read.csv'), exists('read_excel'), exists('dbConnect')))
