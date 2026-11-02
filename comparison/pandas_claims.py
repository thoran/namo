#!/usr/bin/env python3
# pandas_claims.py

# 20261101
# 0.0.0

"""The pandas snippets in COMPARISON.md, in the document's order, each run against
small inline data, followed by the probes behind its claims about pandas.

Each step prints its label and its result, or the exception it raised, so a claim
that something fails is shown failing.
"""

import warnings

import pandas as pd

warnings.simplefilter('always')


def show(label, thunk):
    print(f'## {label}')
    with warnings.catch_warnings(record=True) as caught:
        try:
            print(thunk())
        except Exception as e:
            print(f'raises {type(e).__name__}: {e}')
    for w in caught:
        print(f'warns {w.category.__name__}: {w.message}')
    print()


records = [
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter': 'Q1', 'close': 42.5, 'pe': 12.0, 'volume': 100, 'price': 10.0, 'quantity': 3, 'cost': 20.0, 'date': '2025-01-02'},
    {'symbol': 'RIO', 'exchange': 'ASX', 'quarter': 'Q1', 'close': 118.3, 'pe': None, 'volume': 200, 'price': 20.0, 'quantity': 2, 'cost': 30.0, 'date': '2025-01-02'},
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter': 'Q2', 'close': 43.1, 'pe': 16.0, 'volume': 0, 'price': 11.0, 'quantity': 4, 'cost': 25.0, 'date': '2025-04-01'},
    {'symbol': 'WES', 'exchange': 'ASX', 'quarter': 'Q2', 'close': 15.0, 'pe': 9.0, 'volume': 50, 'price': 5.0, 'quantity': 10, 'cost': 40.0, 'date': '2025-04-01'},
]
df = pd.DataFrame(records)

print(f'pandas {pd.__version__}\n')


# Ingestion and schema

show('Schema-free instantiation', lambda: pd.DataFrame([{'symbol': 'BHP', 'close': 42.5}, {'symbol': 'RIO', 'close': 118.3}]))
show('claim: inferred types (strings, dates)', lambda: df[['symbol', 'close', 'date']].dtypes)

show("No index: df.loc['BHP'] without an index", lambda: df.loc['BHP'])
show("No index: df.loc['BHP'] after set_index('symbol')", lambda: df.set_index('symbol').loc['BHP'])
show('No index: column filter', lambda: df[df['close'] == 42.5])


# Selection

show('Keyword selection', lambda: df[df['symbol'] == 'BHP'])
show('Keyword selection, two columns', lambda: df[(df['symbol'] == 'BHP') & (df['quarter'] == 'Q1')])
show('Keyword selection, query', lambda: df.query("symbol == 'BHP' and quarter == 'Q1'"))

show('Array selection', lambda: df[df['quarter'].isin(['Q1', 'Q2'])])
show('Range selection', lambda: df[df['close'].between(10.0, 20.0)])

show('Proc selection, apply', lambda: df[df['pe'].apply(lambda v: v is not None and v < 15)])
show('claim: a missing pe reaches the lambda as NaN, not None', lambda: df['pe'].tolist())
show('claim: the indexer takes a callable directly', lambda: df.loc[lambda d: d['pe'] < 15])
show('claim: so does []', lambda: df[lambda d: d['pe'] < 15])

show('Regex selection', lambda: df[df['symbol'].str.match(r'^BH')])
show('claim: DataFrame.filter(regex=) matches labels, not values', lambda: df.filter(regex=r'^c'))

show('Mixed selection', lambda: df[
    (df['symbol'].str.match(r'^BH')) &
    (df['close'].between(10.0, 50.0)) &
    (df['pe'].apply(lambda v: v is not None and v < 15)) &
    (df['quarter'] == 'Q1')
])
indexed = df.set_index(['symbol', 'quarter']).sort_index()
show('claim: .loc on a MultiIndex takes a scalar, a list and a slice per level in one call', lambda: indexed.loc[(['BHP', 'WES'], slice('Q1', 'Q1')), :])


# Projection and contraction

show('Projection', lambda: df[['symbol', 'close']])
show('Contraction', lambda: df.drop(columns=['symbol', 'close']))
show('Combined selection and projection, one .loc call', lambda: df.loc[df['quarter'] == 'Q1', ['symbol', 'close']])


# Formulae

def computed_dimension():
    d = df.copy()
    d['revenue'] = d['price'] * d['quantity']
    d.loc[0, 'price'] = 100.0
    return d[['price', 'quantity', 'revenue']]
show('Computed dimension, then a change to price', computed_dimension)

def formula_chain():
    d = df.copy()
    d['revenue'] = d['price'] * d['quantity']
    d['profit'] = d['revenue'] - d['cost']
    d['margin'] = d['profit'] / d['revenue']
    return d[['revenue', 'profit', 'margin']]
show('Formula chain', formula_chain)

def formula_chain_out_of_order():
    d = df.copy()
    d['profit'] = d['revenue'] - d['cost']
    d['revenue'] = d['price'] * d['quantity']
    return d
show('claim: formula chain out of order', formula_chain_out_of_order)

dates = pd.date_range('2025-01-01', periods=25, freq='D')
prices = pd.DataFrame([
    {'symbol': symbol, 'date': date, 'close': base + i, 'volume': 1000 + 10 * i}
    for symbol, base in [('BHP', 40.0), ('RIO', 110.0)]
    for i, date in enumerate(dates)
])

def two_arity():
    p = prices.copy()
    p['sma_20'] = p.groupby('symbol')['close'].transform(lambda x: x.rolling(20).mean())
    return p[p['date'] >= dates[18]]
show('Two-arity formulae, rolling', two_arity)

def sma(df, field, period):
    return df.groupby('symbol')[field].transform(lambda x: x.rolling(period).mean())

def parameterised():
    p = prices.copy()
    p['sma_close_20'] = sma(p, 'close', 20)
    p['sma_volume_50'] = sma(p, 'volume', 50)
    return p.tail(3)
show('Parameterised formulae, an external function', parameterised)

@pd.api.extensions.register_dataframe_accessor('ta')
class TechnicalAnalysis:
    def __init__(self, frame):
        self.frame = frame
    def sma(self, field, period):
        return self.frame.groupby('symbol')[field].transform(lambda x: x.rolling(period).mean())

show('claim: a registered accessor attaches named computations to every DataFrame, computed when called', lambda: prices.ta.sma('close', 20).tail(3))


# Composition

ohlcv = pd.DataFrame([
    {'symbol': 'BHP', 'exchange': 'ASX', 'date': pd.Timestamp('2025-03-31'), 'close': 42.5},
    {'symbol': 'BHP', 'exchange': 'ASX', 'date': pd.Timestamp('2025-07-01'), 'close': 44.0},
    {'symbol': 'RIO', 'exchange': 'ASX', 'date': pd.Timestamp('2025-07-01'), 'close': 118.3},
])
fundamentals = pd.DataFrame([
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter_end': pd.Timestamp('2024-12-31'), 'pe': 11.0},
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter_end': pd.Timestamp('2025-06-30'), 'pe': 12.0},
    {'symbol': 'RIO', 'exchange': 'ASX', 'quarter_end': pd.Timestamp('2025-06-30'), 'pe': 9.0},
])

show('Equi-join', lambda: pd.merge(ohlcv, fundamentals, on=['symbol', 'exchange']))
show('claim: merge with no on= uses the shared columns, and whether it warns', lambda: pd.merge(ohlcv[['symbol', 'exchange', 'close']], fundamentals[['symbol', 'exchange', 'pe']]))

show('Asof join', lambda: pd.merge_asof(ohlcv, fundamentals,
    left_on='date', right_on='quarter_end',
    by='symbol', direction='backward'
))
show('claim: merge_asof wants both sides sorted on the key', lambda: pd.merge_asof(ohlcv.iloc[::-1], fundamentals,
    left_on='date', right_on='quarter_end', by='symbol', direction='backward'))
show("claim: merge_asof's direction values", lambda: pd.merge_asof(ohlcv, fundamentals,
    left_on='date', right_on='quarter_end', by='symbol', direction='sideways'))

show('Cartesian product', lambda: pd.merge(ohlcv, fundamentals, how='cross'))

combined = pd.merge(ohlcv[['symbol', 'close']], fundamentals[['pe']], how='cross')
show('Decomposition', lambda: combined.drop(columns=ohlcv[['symbol', 'close']].columns).drop_duplicates())


# Aggregation

show('Group-by-aggregate', lambda: df.groupby('symbol')['close'].mean())

def score(pe):
    return pe < 10

show('Group by a derived Series', lambda: df.groupby(df['pe'].apply(score))['close'].mean())

def grouped_object():
    g = df.groupby('symbol')
    return (type(g).__name__, g['close'].mean().to_dict(), g['close'].max().to_dict(), g.get_group('BHP')['close'].tolist())
show('claim: the grouped object can be held and queried again', grouped_object)


# Set operators

a = pd.DataFrame([{'x': 1}, {'x': 2}])
b = pd.DataFrame([{'x': 2}, {'x': 3}])

show('Concatenation', lambda: pd.concat([a, b]))
show('Intersection (approximate)', lambda: pd.merge(a, b, how='inner'))
show('Union (approximate)', lambda: pd.concat([a, b]).drop_duplicates())
show('claim: DataFrame has no set-operator methods', lambda: sorted(m for m in dir(pd.DataFrame) if m in ('union', 'intersection', 'difference', 'symmetric_difference', 'symdiff', 'setdiff')))

today = pd.DataFrame([{'symbol': 'BHP'}, {'symbol': 'RIO'}, {'symbol': 'WES'}])
exclusions = pd.DataFrame([{'symbol': 'RIO'}])
show('Keyed anti-join', lambda: today[~today['symbol'].isin(exclusions['symbol'])])

yesterday = pd.DataFrame([{'symbol': 'BHP'}, {'symbol': 'RIO'}])

def worked_example():
    yesterday_rows = set(map(tuple, yesterday.itertuples(index=False)))
    today_rows     = set(map(tuple, today.itertuples(index=False)))

    if   today_rows == yesterday_rows: status = "no change"
    elif today_rows >= yesterday_rows: status = f"added {len(today_rows - yesterday_rows)} candidates"
    elif yesterday_rows >= today_rows: status = f"removed {len(yesterday_rows - today_rows)} candidates"
    else:                              status = f"churn: {len(today_rows ^ yesterday_rows)} differing"
    return status
show("Worked example: yesterday's screen against today's", worked_example)


# Type handling

def type_agnosticism():
    d = df.copy()
    d['label'] = d['symbol'] + ' (' + d['exchange'] + ')'
    d['status'] = d['volume'].apply(lambda v: 'active' if v > 0 else 'suspended')
    return d[d['status'] == 'active'][['label', 'status']]
show('Type agnosticism', type_agnosticism)


# Enumerable integration

def iterrows():
    d = df.copy()
    d['revenue'] = d['price'] * d['quantity']
    return [(type(idx).__name__, type(row).__name__, row['revenue']) for idx, row in d.iterrows()]
show('iterrows', iterrows)

def filtered_frame():
    filtered = df[df['close'] > 40]
    return filtered[filtered['symbol'] == 'BHP']
show('Filtering returns a DataFrame', filtered_frame)
show('Sorting', lambda: df.sort_values('close'))


# Comparison

c = pd.DataFrame([{'x': 1, 'y': 'a'}, {'x': 2, 'y': 'b'}])
c_reversed = c.iloc[::-1].reset_index(drop=True)
show('equals, same rows in another order', lambda: c.equals(c_reversed))
show('==, same rows in another order', lambda: (c == c_reversed).all().all())
show('claim: == returns a frame of booleans', lambda: c == c_reversed)

def schema_dispatch():
    def process_ohlcv(df): return 'ohlcv'
    def process_fundamentals(df): return 'fundamentals'
    incoming = pd.DataFrame([{'date': None, 'symbol': 'BHP', 'open': 0.0, 'high': 0.0, 'low': 0.0, 'close': 0.0, 'volume': 0}])

    ohlcv_cols        = {'date', 'symbol', 'open', 'high', 'low', 'close', 'volume'}
    fundamentals_cols = {'symbol', 'pe', 'book_value', 'dividend_yield'}

    incoming_cols = set(incoming.columns)

    if   incoming_cols == ohlcv_cols:        return process_ohlcv(incoming)
    elif incoming_cols == fundamentals_cols: return process_fundamentals(incoming)
    else: raise ValueError(f"unknown shape: {incoming.columns.tolist()}")
show('Schema dispatch', schema_dispatch)

def subset(a, b):
    return len(pd.merge(a, b, how='inner')) == len(a)
show('Subset, a <= b', lambda: subset(pd.DataFrame([{'x': 1}]), pd.DataFrame([{'x': 1}, {'x': 2}])))
show('claim: the merge test with duplicates in b', lambda: subset(pd.DataFrame([{'x': 1}]), pd.DataFrame([{'x': 1}, {'x': 1}])))

def matches_ohlcv(df):
    return all(col in df.columns for col in ['symbol', 'date', 'open', 'high', 'low', 'close', 'volume'])
show('Aspect classes: predicate function', lambda: matches_ohlcv(pd.DataFrame([{'symbol': 'BHP', 'date': None, 'open': 0.0, 'high': 0.0, 'low': 0.0, 'close': 0.0, 'volume': 0}])))


# Introspection

values = pd.DataFrame([{'symbol': 'BHP', 'close': 42.5}, {'symbol': 'RIO', 'close': 118.3}, {'symbol': 'BHP', 'close': 43.1}])
show('Dimensions', lambda: values.columns.tolist())
show('Coordinates', lambda: values['symbol'].unique())
show('Values', lambda: values['symbol'].tolist())
show("to_dict('list')", lambda: values.to_dict('list'))


# What Namo doesn't have

show('Reshaping methods', lambda: [m for m in ('pivot_table', 'melt', 'stack', 'unstack') if hasattr(pd.DataFrame, m)])
show('Missing-value methods', lambda: [m for m in ('fillna', 'dropna', 'isna') if hasattr(pd.DataFrame, m)])
show('Readers', lambda: [r for r in ('read_csv', 'read_excel', 'read_sql', 'read_parquet', 'read_json', 'read_html') if hasattr(pd, r)])
show('Column-level operations', lambda: (df['close'].mean(), df['close'].std(), df['close'].pct_change().tolist()))
