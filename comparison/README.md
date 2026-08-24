# comparison

The scripts behind "Measured, at 0.31.0" in [ROADMAP.md](../ROADMAP.md).

These do not run on a clean clone, which is why they are here rather than in
`script/`. They need a sqlite database that is not in this repository, and the
Python ones need NumPy or pandas. What they offer a reader without that database is
the thing prose cannot: whether the two sides were cut the same way.

## What they need

A sqlite table of daily prices:

```sql
CREATE TABLE prices (security TEXT, exchange TEXT, date TEXT, close REAL, ...);
```

queried as

```sql
SELECT security, date, close FROM prices
  WHERE exchange = 'AU' AND date BETWEEN '2025-01-01' AND '2025-12-31'
```

which over the data the figures were taken from returns 344,697 rows for 2,641
securities. The path defaults to `~/data/market_data.db` and is overridden with
`MARKET_DATA_DB`.

## The computation

Group by security, take the close at the earliest and at the latest date within
each group, and keep the securities whose last close exceeds their first. Every
script prints the count, and the securities themselves on stderr, so the outputs can
be diffed rather than compared by eye. All six agree at 1,622.

## The scripts

| | |
| --- | --- |
| `namo.rb` | Namo, `group_by` and `summary` with a block |
| `ruby_by_hand.rb` | the same in plain Ruby, three ways |
| `numpy_vectorised.py` | NumPy: `lexsort`, `unique`, boolean masking, no Python in the loop |
| `pandas_grouped.py` | pandas, three routes to the same answer |
| `python_by_hand.py` | plain Python, `defaultdict` in one pass |

The Ruby and Python files are named for their approach rather than their library
because `numpy.py` and `pandas.py` shadow the modules they import, and the failure
is a confusing one.

## Reading the phases

`namo.rb`, `numpy_vectorised.py` and `pandas_grouped.py` cut at the same places:
**query** is the database driver alone, **construct** is the library taking the rows,
and **compute** is the work. `namo.rb` has a fourth, **to_hashes**, mapping the
driver's arrays into hashes; Python's driver already returns the tuples `np.array`
and `pd.DataFrame` consume, so there is no counterpart, and that difference is in
the drivers rather than in where the clock was started.

An earlier generation of these scripts timed two phases and put `np.array` inside
NumPy's fetch while leaving `PriceData.new` inside Namo's compute. The figures
favoured Namo until that was corrected, which is the argument for this directory
existing.

## Caveats

Medians where a script takes them, single runs where it does not. The query is by
far the largest term and the least stable — a cold run has measured over four
seconds against a warm one's second — and it compares database drivers rather than
libraries. Figures move with library versions: the pandas numbers in the ROADMAP
were taken against pandas 3.0.5 and numpy 2.5.2, and which of its three routes is
fastest is not stable across versions.
