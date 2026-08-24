#!/usr/bin/env python3
# numpy_vectorised.py

# 20260825
# 0.0.0

"""The NumPy side of the comparison in ROADMAP.md's "Measured, at 0.31.0".

Fully vectorised: lexsort, unique, boolean masking, no Python in the loop. The
phases are cut where namo.rb cuts them, so np.array sits in its own construct
phase against PriceData.new rather than inside the query. namo.rb has a fourth
phase, to_hashes, which has no counterpart here because the sqlite3 driver already
hands Python the tuples np.array consumes; that asymmetry is in the data returned,
not in where the clock was started, and it is why the ROADMAP reports the phases
rather than only the total.
"""

import os
import sqlite3
import sys
import time

import numpy as np

DATABASE = os.environ.get('MARKET_DATA_DB', '~/data/market_data.db')


def main():
    conn = sqlite3.connect(os.path.expanduser(DATABASE))

    started = time.perf_counter()
    rows = conn.execute(
        'SELECT security, date, close FROM prices '
        'WHERE exchange = ? AND date BETWEEN ? AND ?',
        ('AU', '2025-01-01', '2025-12-31')).fetchall()
    query = time.perf_counter() - started

    started = time.perf_counter()
    data = np.array(
        rows, dtype=[('security', 'U32'), ('date', 'U10'), ('close', 'f8')])
    construct = time.perf_counter() - started

    started = time.perf_counter()
    order = np.lexsort((data['date'], data['security']))
    data = data[order]
    securities, starts = np.unique(data['security'], return_index=True)
    ends = np.append(starts[1:], len(data)) - 1
    higher = data['close'][ends] > data['close'][starts]
    result = securities[higher]
    compute = time.perf_counter() - started

    print(f'query={query * 1000:.0f}ms construct={construct * 1000:.0f}ms '
          f'compute={compute * 1000:.0f}ms rows={len(result)}')
    print('\n'.join(sorted(result)), file=sys.stderr)


main()
