#!/usr/bin/env python3
# python_by_hand.py

# 20260825
# 0.0.0

"""The same computation without NumPy or pandas, the counterpart to
ruby_by_hand.rb.

The pair of by-hand scripts is what separates the language from the library. The
ROADMAP's NumPy comparison invites the reading that plain Ruby beat vectorised C;
these two say how much of that is Ruby being quick at hashes rather than NumPy
being slow, and the pandas figure says the rest.

Only the compute phase is timed. The query is the same as the others'.
"""

import os
import sqlite3
import statistics
import sys
import time
from collections import defaultdict

DATABASE = os.environ.get('MARKET_DATA_DB', '~/data/market_data.db')
RUNS = 6


def compute(rows):
    by_security = defaultdict(list)
    for security, date, close in rows:
        by_security[security].append((date, close))
    return [security for security, entries in by_security.items()
            if max(entries)[1] > min(entries)[1]]


def main():
    conn = sqlite3.connect(os.path.expanduser(DATABASE))
    rows = conn.execute(
        'SELECT security, date, close FROM prices '
        'WHERE exchange = ? AND date BETWEEN ? AND ?',
        ('AU', '2025-01-01', '2025-12-31')).fetchall()

    timings = []
    for _ in range(RUNS):
        started = time.perf_counter()
        result = compute(rows)
        timings.append((time.perf_counter() - started) * 1000)
    print(f'  {"defaultdict, one pass":28} median {statistics.median(timings):5.0f} ms   -> {len(result)}')
    print('\n'.join(sorted(result)), file=sys.stderr)


main()
