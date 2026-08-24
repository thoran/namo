#!/usr/bin/env python3
# pandas_grouped.py

# 20260825
# 0.0.0

"""The pandas side of the comparison in ROADMAP.md's "Against pandas, which is
built for it".

Three routes to the same answer, because the first one written was not pandas' best
and quoting it would have flattered Namo by three and a half times. The ROADMAP
quotes the median of `sort_values + agg`; `idxmin/idxmax` is kept here so the
difference between them stays visible rather than being a claim in prose.

The query and construct phases are cut where namo.rb and numpy_vectorised.py cut them.
"""

import os
import sqlite3
import statistics
import sys
import time

import pandas as pd

DATABASE = os.environ.get('MARKET_DATA_DB', '~/data/market_data.db')
RUNS = 6


def idx_based(frame):
    grouped = frame.groupby('security')['date']
    first = frame.loc[grouped.idxmin()].set_index('security')['close']
    last = frame.loc[grouped.idxmax()].set_index('security')['close']
    higher = last > first
    return higher[higher].index


def sort_then_agg(frame):
    ordered = frame.sort_values('date')
    aggregated = ordered.groupby('security', sort=False)['close'].agg(['first', 'last'])
    higher = aggregated['last'] > aggregated['first']
    return higher[higher].index


def sort_both_then_agg(frame):
    ordered = frame.sort_values(['security', 'date'])
    aggregated = ordered.groupby('security', sort=False)['close'].agg(['first', 'last'])
    higher = aggregated['last'] > aggregated['first']
    return higher[higher].index


def main():
    conn = sqlite3.connect(os.path.expanduser(DATABASE))

    started = time.perf_counter()
    rows = conn.execute(
        'SELECT security, date, close FROM prices '
        'WHERE exchange = ? AND date BETWEEN ? AND ?',
        ('AU', '2025-01-01', '2025-12-31')).fetchall()
    query = time.perf_counter() - started

    started = time.perf_counter()
    frame = pd.DataFrame(rows, columns=['security', 'date', 'close'])
    construct = time.perf_counter() - started

    print(f'query={query * 1000:.0f}ms construct={construct * 1000:.0f}ms')
    for name, route in (('idxmin/idxmax', idx_based),
                        ('sort_values + agg', sort_then_agg),
                        ('sort both + agg', sort_both_then_agg)):
        timings = []
        for _ in range(RUNS):
            started = time.perf_counter()
            result = route(frame)
            timings.append((time.perf_counter() - started) * 1000)
        print(f'  {name:20} median {statistics.median(timings):5.0f} ms   -> {len(result)} securities')
    print('\n'.join(sorted(sort_then_agg(frame))), file=sys.stderr)


main()
