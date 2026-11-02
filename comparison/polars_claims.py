#!/usr/bin/env python3
# polars_claims.py

# 20261101
# 0.0.0

"""The Polars snippets in COMPARISON.md, in the document's order, each run against
small inline data, followed by the probes behind its claims about Polars.

Each step prints its label and its result, or the exception it raised, so a claim
that something fails is shown failing.
"""

import datetime
import warnings

import polars as pl
from polars.testing import assert_frame_equal

warnings.simplefilter('always')
pl.Config.set_tbl_formatting('ASCII_MARKDOWN')
pl.Config.set_tbl_hide_column_data_types(True)
pl.Config.set_tbl_hide_dataframe_shape(True)
pl.Config.set_tbl_cols(-1)


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
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter': 'Q1', 'close': 42.5, 'pe': 12.0, 'volume': 100, 'price': 10.0, 'quantity': 3, 'cost': 20.0},
    {'symbol': 'RIO', 'exchange': 'ASX', 'quarter': 'Q1', 'close': 118.3, 'pe': None, 'volume': 200, 'price': 20.0, 'quantity': 2, 'cost': 30.0},
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter': 'Q2', 'close': 43.1, 'pe': 16.0, 'volume': 0, 'price': 11.0, 'quantity': 4, 'cost': 25.0},
    {'symbol': 'WES', 'exchange': 'ASX', 'quarter': 'Q2', 'close': 15.0, 'pe': 9.0, 'volume': 50, 'price': 5.0, 'quantity': 10, 'cost': 40.0},
]
df = pl.DataFrame(records)

print(f'polars {pl.__version__}\n')


# Ingestion and schema

show('Schema-free instantiation', lambda: pl.DataFrame([{'symbol': 'BHP', 'close': 42.5}, {'symbol': 'RIO', 'close': 118.3}]))
show('claim: an explicit schema', lambda: pl.DataFrame([{'symbol': 'BHP', 'close': 42}], schema={'symbol': pl.String, 'close': pl.Float32}).schema)
show('claim: no index', lambda: [m for m in ('index', 'set_index', 'reset_index', 'loc') if hasattr(pl.DataFrame, m)])

show('No index', lambda: df.filter(pl.col('symbol') == 'BHP'))
show('No index, another column', lambda: df.filter(pl.col('close') == 42.5))


# Selection

show('Keyword selection', lambda: df.filter(pl.col('symbol') == 'BHP'))
show('Keyword selection, two columns', lambda: df.filter((pl.col('symbol') == 'BHP') & (pl.col('quarter') == 'Q1')))
show('claim: filter also takes keyword equality', lambda: df.filter(symbol='BHP', quarter='Q1'))

show('Array selection', lambda: df.filter(pl.col('quarter').is_in(['Q1', 'Q2'])))
show('Range selection', lambda: df.filter(pl.col('close').is_between(10.0, 20.0)))

show('Proc selection, expressions', lambda: df.filter(pl.col('pe').is_not_null() & (pl.col('pe') < 15)))
show('Proc selection, map_elements', lambda: df.filter(pl.col('pe').map_elements(lambda v: v is not None and v < 15)))
show('Proc selection, map_elements with return_dtype', lambda: df.filter(pl.col('pe').map_elements(lambda v: v is not None and v < 15, return_dtype=pl.Boolean)))
show('claim: map_elements in a LazyFrame', lambda: df.lazy().filter(pl.col('pe').map_elements(lambda v: v < 15, return_dtype=pl.Boolean)).collect())
show('claim: map_elements docstring on cost', lambda: '\n'.join(line for line in pl.Expr.map_elements.__doc__.splitlines() if 'slow' in line or 'optimi' in line or 'parallel' in line))

show('Regex selection', lambda: df.filter(pl.col('symbol').str.contains(r'^BH')))
show('claim: pl.col with a regex picks columns by name', lambda: df.select(pl.col('^c.*$')))

show('Mixed selection', lambda: df.filter(
    (pl.col('symbol').str.contains(r'^BH')) &
    (pl.col('close').is_between(10.0, 50.0)) &
    (pl.col('pe').map_elements(lambda v: v is not None and v < 15, return_dtype=pl.Boolean)) &
    (pl.col('quarter') == 'Q1')
))


# Projection and contraction

show('Projection', lambda: df.select(['symbol', 'close']))
show('Projection, brackets', lambda: df[['symbol', 'close']])
show('Contraction', lambda: df.drop(['symbol', 'close']))
show('Contraction, pl.exclude', lambda: df.select(pl.exclude('symbol', 'close')))
show('Combined selection and projection', lambda: df.filter(pl.col('quarter') == 'Q1').select(['symbol', 'close']))


# Formulae

show('Computed dimension', lambda: df.with_columns((pl.col('price') * pl.col('quantity')).alias('revenue')))

def formula_chain():
    d = df
    d = d.with_columns((pl.col('price') * pl.col('quantity')).alias('revenue'))
    d = d.with_columns((pl.col('revenue') - pl.col('cost')).alias('profit'))
    d = d.with_columns((pl.col('profit') / pl.col('revenue')).alias('margin'))
    return d.select('revenue', 'profit', 'margin')
show('Formula chain', formula_chain)

show('claim: one with_columns, each referring to the one before', lambda: df.with_columns(
    (pl.col('price') * pl.col('quantity')).alias('revenue'),
    (pl.col('revenue') - pl.col('cost')).alias('profit'),
))
show('claim: with_columns_seq, each referring to the one before', lambda: df.with_columns_seq(
    (pl.col('price') * pl.col('quantity')).alias('revenue'),
    (pl.col('revenue') - pl.col('cost')).alias('profit'),
))

start = datetime.date(2025, 1, 1)
prices = pl.DataFrame([
    {'symbol': symbol, 'date': start + datetime.timedelta(days=i), 'close': base + i, 'volume': 1000 + 10 * i}
    for symbol, base in [('BHP', 40.0), ('RIO', 110.0)]
    for i in range(25)
])

show('Two-arity formulae, rolling', lambda: prices.with_columns(
    pl.col('close').rolling_mean(20).over('symbol').alias('sma_20')
).tail(7))

def parameterised():
    p = prices
    p = p.with_columns(pl.col('close').rolling_mean(20).over('symbol').alias('sma_close_20'))
    p = p.with_columns(pl.col('volume').rolling_mean(50).over('symbol').alias('sma_volume_50'))
    return p.tail(3)
show('Parameterised formulae', parameterised)

def sma(field, period):
    return pl.col(field).rolling_mean(period).over('symbol')
show('claim: a function returning an expression', lambda: prices.with_columns(sma('close', 20).alias('sma_close_20')).tail(3))

@pl.api.register_dataframe_namespace('ta')
class TechnicalAnalysis:
    def __init__(self, frame):
        self.frame = frame
    def sma(self, field, period):
        return self.frame.with_columns(pl.col(field).rolling_mean(period).over('symbol').alias(f'sma_{field}_{period}'))
show('claim: a registered namespace attaches named computations to every DataFrame, computed when called', lambda: prices.ta.sma('close', 20).tail(3))


# Composition

ohlcv = pl.DataFrame([
    {'symbol': 'BHP', 'exchange': 'ASX', 'date': datetime.date(2025, 3, 31), 'close': 42.5},
    {'symbol': 'BHP', 'exchange': 'ASX', 'date': datetime.date(2025, 7, 1), 'close': 44.0},
    {'symbol': 'RIO', 'exchange': 'ASX', 'date': datetime.date(2025, 7, 1), 'close': 118.3},
])
fundamentals = pl.DataFrame([
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter_end': datetime.date(2024, 12, 31), 'pe': 11.0},
    {'symbol': 'BHP', 'exchange': 'ASX', 'quarter_end': datetime.date(2025, 6, 30), 'pe': 12.0},
    {'symbol': 'RIO', 'exchange': 'ASX', 'quarter_end': datetime.date(2025, 6, 30), 'pe': 9.0},
])

show('Equi-join', lambda: ohlcv.join(fundamentals, on=['symbol', 'exchange']))
show('claim: join with no on=', lambda: ohlcv.join(fundamentals))

show('Asof join', lambda: ohlcv.join_asof(fundamentals,
    left_on='date', right_on='quarter_end',
    by='symbol', strategy='backward'
))
show("claim: join_asof's strategy values", lambda: ohlcv.join_asof(fundamentals,
    left_on='date', right_on='quarter_end', by='symbol', strategy='sideways'))
show('claim: join_where takes inequality predicates', lambda: ohlcv.join_where(fundamentals,
    pl.col('symbol') == pl.col('symbol_right'), pl.col('quarter_end') <= pl.col('date')))

show('Cartesian product', lambda: ohlcv.join(fundamentals, how='cross'))

combined = ohlcv.select('symbol', 'close').join(fundamentals.select('pe'), how='cross')
show('Decomposition', lambda: combined.drop(ohlcv.select('symbol', 'close').columns).unique(maintain_order=True))


# Aggregation

show('Group-by-aggregate', lambda: df.group_by('symbol', maintain_order=True).agg(pl.col('close').mean()))
show('Group by an expression', lambda: df.group_by((pl.col('pe') < 10).alias('value_score'), maintain_order=True).agg(pl.col('close').mean()))

def grouped_object():
    g = df.group_by('symbol', maintain_order=True)
    return (type(g).__name__, g.agg(pl.col('close').mean()), g.agg(pl.col('close').max()))
show('claim: the grouped object can be held and queried again', grouped_object)


# Set operators

a = pl.DataFrame([{'x': 1}, {'x': 2}])
b = pl.DataFrame([{'x': 2}, {'x': 3}])

show('Concatenation', lambda: pl.concat([a, b]))
show('claim: DataFrame has no set-operator methods', lambda: sorted(m for m in dir(pl.DataFrame) if m in ('union', 'intersect', 'intersection', 'difference', 'except_', 'symmetric_difference', 'symdiff', 'setdiff')))
show('Intersection by semi-join', lambda: a.join(b, on='x', how='semi'))
show('Difference by anti-join', lambda: a.join(b, on='x', how='anti'))

today = pl.DataFrame([{'symbol': 'BHP'}, {'symbol': 'RIO'}, {'symbol': 'WES'}])
exclusions = pl.DataFrame([{'symbol': 'RIO'}])
show('Keyed anti-join', lambda: today.join(exclusions, on='symbol', how='anti'))
show('claim: join on= takes expressions as well as names', lambda: today.join(
    pl.DataFrame([{'symbol': 'rio'}]), on=pl.col('symbol').str.to_lowercase(), how='anti'))


# Type handling

show('Type agnosticism', lambda: df.with_columns(
    (pl.col('symbol') + ' (' + pl.col('exchange') + ')').alias('label')
).select('label'))


# Enumerable integration

show('iter_rows(named=True)', lambda: next(df.iter_rows(named=True)))
show('iter_rows()', lambda: next(df.iter_rows()))
show('Filtering returns a DataFrame', lambda: type(df.filter(pl.col('close') > 40)).__name__)
show('Sorting', lambda: df.sort('close'))


# Comparison

c = pl.DataFrame([{'x': 1, 'y': 'a'}, {'x': 2, 'y': 'b'}])
c_reversed = c.reverse()
show('equals, same rows in another order', lambda: c.equals(c_reversed))
show('claim: frame_equal', lambda: c.frame_equal(c_reversed))

def order_insensitive():
    assert_frame_equal(c, c_reversed, check_row_order=False)
    return 'assert_frame_equal(check_row_order=False) passes'
show('claim: an order-insensitive comparison in polars.testing', order_insensitive)

class Schemas:
    ohlcv = pl.Schema({'date': pl.Date, 'symbol': pl.String, 'close': pl.Float64})
    fundamentals = pl.Schema({'symbol': pl.String, 'pe': pl.Float64})

def schema_match(incoming):
    match incoming.schema:
        case Schemas.ohlcv:        return 'ohlcv'
        case Schemas.fundamentals: return 'fundamentals'
        case _:                    return 'unknown'
show("claim: a Schema is a value, and Python's match dispatches on it by equality", lambda: (
    type(df.schema).__name__,
    schema_match(pl.DataFrame({'symbol': ['BHP'], 'pe': [12.0]})),
    schema_match(pl.DataFrame({'symbol': ['BHP'], 'pe': [12]})),
))

def subset():
    a = pl.DataFrame([{'x': 1}])
    b = pl.DataFrame([{'x': 1}, {'x': 2}])
    is_subset = a.join(b, on=a.columns, how='anti').height == 0
    is_equal = is_subset and b.join(a, on=b.columns, how='anti').height == 0
    return is_subset, is_equal
show('Subset by anti-join', subset)

incoming = pl.DataFrame([{'symbol': 'BHP', 'date': None, 'open': 0.0, 'high': 0.0, 'low': 0.0, 'close': 0.0, 'volume': 0}])
show('Aspect classes: subset of columns', lambda: {'symbol', 'date', 'open', 'high', 'low', 'close', 'volume'}.issubset(incoming.columns))


# Introspection

values = pl.DataFrame([{'symbol': 'BHP', 'close': 42.5}, {'symbol': 'RIO', 'close': 118.3}, {'symbol': 'BHP', 'close': 43.1}])
show('Dimensions', lambda: values.columns)
show('Coordinates', lambda: values['symbol'].unique().to_list())
show('Coordinates, maintain_order', lambda: values['symbol'].unique(maintain_order=True).to_list())
show('Values', lambda: values['symbol'].to_list())
show('to_dict(as_series=False)', lambda: values.to_dict(as_series=False))
show('to_dict()', lambda: values.to_dict())


# What Namo doesn't have

show('Reshaping methods', lambda: [m for m in ('pivot', 'melt', 'unpivot') if hasattr(pl.DataFrame, m)])
show('melt', lambda: values.melt(id_vars='symbol'))
show('Missing-value methods', lambda: ([m for m in ('fill_null', 'drop_nulls') if hasattr(pl.DataFrame, m)], hasattr(pl.Expr, 'is_null')))
show('Readers', lambda: [r for r in ('read_csv', 'read_parquet', 'read_json', 'read_ndjson', 'read_ipc', 'read_excel', 'read_database', 'read_avro', 'read_delta', 'read_iceberg') if hasattr(pl, r)])
show('Column-level operations', lambda: (df['close'].mean(), df['close'].std()))
