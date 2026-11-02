#!/usr/bin/env python3
# xarray_claims.py

# 20261101
# 0.0.0

"""The xarray snippets in COMPARISON.md, in the document's order, each run against
small inline data, followed by the probes behind its claims about xarray.

Each step prints its label and its result, or the exception it raised, so a claim
that something fails is shown failing.
"""

import warnings

import numpy as np
import pandas as pd
import xarray as xr

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


print(f'xarray {xr.__version__}\n')

# The document's own construction: one dimension, obs, with symbol a coordinate along it.
ds = xr.Dataset(
    {'close': (['obs'], [42.5, 118.3])},
    coords={'symbol': (['obs'], ['BHP', 'RIO'])}
)

# Observations as the other snippets need them: symbol and quarter coordinates along obs,
# with an index on each so that sel can reach them.
obs = xr.Dataset(
    {
        'close': (['obs'], [42.5, 118.3, 43.1, 15.0]),
        'pe': (['obs'], [12.0, np.nan, 16.0, 9.0]),
        'price': (['obs'], [10.0, 20.0, 11.0, 5.0]),
        'quantity': (['obs'], [3, 2, 4, 10]),
        'cost': (['obs'], [20.0, 30.0, 25.0, 40.0]),
        'volume': (['obs'], [100, 200, 0, 50]),
        'exchange': (['obs'], ['ASX', 'ASX', 'ASX', 'ASX']),
    },
    coords={'symbol': (['obs'], ['BHP', 'RIO', 'BHP', 'WES']), 'quarter': (['obs'], ['Q1', 'Q1', 'Q2', 'Q2'])},
)
indexed = obs.set_xindex('symbol').set_xindex('quarter')


# Ingestion and schema

show('Schema-free instantiation, as the document constructs it', lambda: ds)
show('claim: from_dataframe takes the index as the dimension', lambda: xr.Dataset.from_dataframe(pd.DataFrame([{'symbol': 'BHP', 'close': 42.5}, {'symbol': 'RIO', 'close': 118.3}]).set_index('symbol')))

show("No index: ds.sel(symbol='BHP') on the document's ds", lambda: ds.sel(symbol='BHP'))
show("No index: ds.sel(symbol='BHP') once symbol has an index", lambda: ds.set_xindex('symbol').sel(symbol='BHP'))
show('No index: ds.sel(close=42.5)', lambda: ds.sel(close=42.5))
show("claim: where keeps every position and masks", lambda: ds.where(ds['close'] == 42.5))
show("No index: ds.where(ds['close'] == 42.5, drop=True)", lambda: ds.where(ds['close'] == 42.5, drop=True))


# Selection

show('Keyword selection', lambda: indexed.sel(symbol='BHP'))
show('Array selection', lambda: indexed.sel(quarter=['Q1', 'Q2']))
show('Range selection on a data variable', lambda: obs.sel(close=slice(10.0, 20.0)))
show('Range selection on an indexed coordinate', lambda: obs.set_coords('close').set_xindex('close').sortby('close').sel(close=slice(10.0, 20.0)))
show('claim: one sel call taking a scalar on one coordinate and a list on another, over duplicated labels', lambda: indexed.sel(symbol='BHP', quarter=['Q1', 'Q2']))

# The same observations with symbol, quarter and date as dimensions, each label once.
cube = xr.Dataset(
    {'close': (['symbol', 'quarter', 'date'], np.arange(2 * 2 * 3, dtype=float).reshape(2, 2, 3))},
    coords={'symbol': ['BHP', 'RIO'], 'quarter': ['Q1', 'Q2'], 'date': pd.date_range('2025-01-01', periods=3, freq='D')},
)
show('Array selection on a dimension coordinate', lambda: cube.sel(quarter=['Q1', 'Q2'])['close'].shape)
show('Mixed selection, one sel call taking a scalar, a list and a slice', lambda: cube.sel(symbol='BHP', quarter=['Q1'], date=slice('2025-01-02', '2025-01-03'))['close'])

show('Proc selection', lambda: obs.where(obs['pe'] < 15, drop=True))
show('Proc selection, where taking a callable', lambda: obs.where(lambda d: d['pe'] < 15, drop=True))

show('Regex selection, the .str accessor on a coordinate', lambda: obs.where(obs['symbol'].str.match('^BH'), drop=True))


# Projection and contraction

show('Projection', lambda: obs[['close']])
show('Contraction', lambda: obs.drop_vars(['symbol', 'close']))
show('Combined selection and projection', lambda: indexed.sel(quarter='Q1')[['close']])


# Formulae

def computed_dimension():
    d = obs.copy(deep=True)
    d['revenue'] = d['price'] * d['quantity']
    d['price'][0] = 100.0
    return d[['price', 'quantity', 'revenue']]
show('Computed dimension, then a change to price', computed_dimension)

def formula_chain():
    d = obs.copy()
    d['revenue'] = d['price'] * d['quantity']
    d['profit'] = d['revenue'] - d['cost']
    d['margin'] = d['profit'] / d['revenue']
    return d[['revenue', 'profit', 'margin']]
show('Formula chain', formula_chain)

prices = xr.Dataset(
    {
        'close': (['symbol', 'date'], np.array([[40.0 + i for i in range(25)], [110.0 + i for i in range(25)]])),
        'volume': (['symbol', 'date'], np.array([[1000 + 10 * i for i in range(25)]] * 2)),
    },
    coords={'symbol': ['BHP', 'RIO'], 'date': pd.date_range('2025-01-01', periods=25, freq='D')},
)

def two_arity():
    p = prices.copy()
    p['sma_20'] = p['close'].rolling(date=20).mean()
    return p['sma_20'].isel(date=slice(18, 21))
show('Two-arity formulae, rolling along date', two_arity)

def parameterised():
    p = prices.copy()
    p['sma_close_20'] = p['close'].rolling(date=20).mean()
    p['sma_volume_50'] = p['volume'].rolling(date=50).mean()
    return p[['sma_close_20', 'sma_volume_50']].isel(date=-1)
show('Parameterised formulae', parameterised)

@xr.register_dataset_accessor('ta')
class TechnicalAnalysis:
    def __init__(self, dataset):
        self.dataset = dataset
    def sma(self, field, period):
        return self.dataset[field].rolling(date=period).mean()
show('claim: a registered accessor attaches named computations to every Dataset, computed when called', lambda: prices.ta.sma('close', 20).isel(date=-1))


# Composition

ds1 = xr.Dataset({'close': (['symbol'], [42.5, 118.3])}, coords={'symbol': ['BHP', 'RIO']})
ds2 = xr.Dataset({'pe': (['symbol'], [12.0, 9.0])}, coords={'symbol': ['BHP', 'RIO']})
show('Equi-join, merge', lambda: xr.merge([ds1, ds2]))

fundamentals = xr.Dataset(
    {'pe': (['symbol', 'quarter_end'], [[11.0, 12.0], [np.nan, 9.0]])},
    coords={'symbol': ['BHP', 'RIO'], 'quarter_end': pd.to_datetime(['2024-12-31', '2025-06-30'])},
)
show('Asof lookup, sel with method=ffill: the most recent quarter_end on or before each date', lambda: fundamentals.sel(
    quarter_end=pd.to_datetime(['2025-03-31', '2025-07-01']), method='ffill'))

other = xr.Dataset({'pe': (['quarter_end'], [11.0, 12.0])}, coords={'quarter_end': pd.to_datetime(['2024-12-31', '2025-06-30'])})
show('claim: datasets on different dimensions broadcast against each other', lambda: xr.merge([ds1, other]))

show('Concatenation along a dimension', lambda: xr.concat([ds1, ds1], dim='symbol'))


# Aggregation

show('Group-by-aggregate', lambda: obs.groupby('symbol').mean())

def grouped_object():
    g = obs.groupby('symbol')
    return (type(g).__name__, g.mean()['close'].values.tolist(), g.max()['close'].values.tolist())
show('claim: the grouped object can be held and queried again', grouped_object)


# Type handling

def type_handling():
    d = obs.copy()
    d['label'] = d['symbol'] + ' (' + d['exchange'] + ')'
    return d['label'].values, d['label'].dtype, d['label'].str.upper().values
show('claim: string-valued data variables', type_handling)


# Enumerable integration

show('claim: iterating a Dataset yields its variable names', lambda: list(obs))
show('Filtering returns a Dataset', lambda: type(obs.where(obs['close'] > 40)).__name__)
show('Sorting by a data variable', lambda: obs.sortby('close')['close'].values)


# Comparison

e = xr.Dataset({'x': (['obs'], [1, 2])}, coords={'obs': [0, 1]}, attrs={'source': 'feed'})
show('equals', lambda: e.equals(e.copy()))
show('claim: equals, identical and broadcast_equals answer different questions', lambda: (
    e.equals(e.assign_attrs(source='other')),
    e.identical(e.assign_attrs(source='other')),
    e.equals(e.expand_dims('k')),
    e.broadcast_equals(e.expand_dims('k')),
))
show('equals, same values in another order', lambda: e.equals(e.isel(obs=[1, 0])))

show("Schema dispatch: dims and data_vars", lambda: (dict(obs.sizes), list(obs.data_vars)))
show('Subset: comparing variable by variable', lambda: all(ds1[var].equals(ds1[var]) for var in ds1.data_vars))


# Introspection

intro = xr.Dataset({'close': (['obs'], [42.5, 118.3, 43.1])}, coords={'symbol': (['obs'], ['BHP', 'RIO', 'BHP'])})
show('Dimensions', lambda: intro.dims)
show("Coordinates: ds.coords['symbol'].values", lambda: intro.coords['symbol'].values)
show('Values', lambda: intro['close'].values)
show('to_dict', lambda: intro.to_dict())


# What Namo doesn't have

show('Reshaping methods', lambda: [m for m in ('pivot', 'stack', 'unstack') if hasattr(xr.Dataset, m)])
show('Missing-value methods', lambda: [m for m in ('fillna', 'dropna', 'isnull') if hasattr(xr.Dataset, m)])
show('Column-level operations', lambda: float(obs['close'].mean()))
