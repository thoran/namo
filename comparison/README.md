# comparison

Two sets of scripts: those which run the snippets in
[COMPARISON.md](../COMPARISON.md), [RUBY_COMPARISON.md](../RUBY_COMPARISON.md), and
the README's "Using Namo with other libraries", and those behind the figures in RUBY_COMPARISON.md and "Measured, at 0.31.0" in
[ROADMAP.md](../ROADMAP.md).

## The claims scripts

One per tool, each with its own small inline data, so they run on a clean clone
given the tool. Each runs every snippet COMPARISON.md shows for its tool, in the
document's order, and then the probes behind its claims: what raises, what warns,
what a call returns where the document says something about it. Every step prints
its label and its result, or the exception it raised.

| | |
| --- | --- |
| `namo_claims.rb` | Namo |
| `pandas_claims.py` | pandas |
| `polars_claims.py` | Polars |
| `xarray_claims.py` | xarray, with pandas and NumPy |
| `dplyr_claims.R` | R, with dplyr, tidyr, tibble and zoo |
| `dataframes_claims.jl` | Julia, with DataFrames.jl, RollingFunctions.jl and Tables.jl |
| `ruby_claims.rb` | RUBY_COMPARISON.md: Namo, Daru, Rover, Polars-ruby, and RedAmber |
| `other_libraries.rb` | the README's "Using Namo with other libraries": statistics.rb, terminal-table, vega, and Polars-ruby |

Each prints the versions it ran against first. `setup` builds the environments they
run in, inside this directory and ignored by git: `.venv/` for Python, with uv, and
`.tools/` for R, with micromamba from conda-forge, for Julia, from julialang.org's
tarball, its sha256 checked, and for the Ruby libraries and those `other_libraries.rb`
passes a Namo to, as gems in `.tools/ruby/` over Apache Arrow's GLib libraries from conda-forge in `.tools/arrow/`, which
RedAmber wants. It wants uv and Ruby, and nothing else installed.

```sh
comparison/setup
comparison/.venv/bin/python comparison/polars_claims.py
comparison/.tools/bin/Rscript comparison/dplyr_claims.R
comparison/.tools/bin/julia comparison/dataframes_claims.jl
comparison/.tools/bin/ruby comparison/ruby_claims.rb
comparison/.tools/bin/ruby comparison/other_libraries.rb
```

`.tools/bin/ruby` runs the Ruby which ran `setup`, with those gems and libraries.

By default it installs the versions the two comparisons and the README name, so a run reproduces
them as dated; `--latest` takes the newest releases of the packages, R, Julia, and
the gems instead, for checking them again, Red Arrow taking the version of the Arrow
installed. uv uses a Python of the version asked for where one is installed, and
otherwise downloads one into `.tools/`. Naming `python`, `r`, `julia`, or `ruby`
builds that one alone. Each is removed and built afresh, so it can be run again, and
the downloads and package caches are removed after. The whole is about 3.3 GB, of
which the Ruby environment is 1 GB, and can be deleted between runs.

`namo_claims.rb`, `ruby_claims.rb`, `other_libraries.rb`, and `ruby_dataframes.rb` load `lib/` from this
repository rather than an installed gem.

## The Ruby libraries timing script

`ruby_dataframes.rb` is behind the "Measured" section of RUBY_COMPARISON.md. It runs
on a clean clone given the `ruby` environment, since it generates its data from a
fixed seed:

```sh
comparison/.tools/bin/ruby comparison/ruby_dataframes.rb
comparison/.tools/bin/ruby comparison/ruby_dataframes.rb 5000 50000
```

One workload in each library, as idiomatically as that library writes it: select
one sector's rows, derive a price-earnings ratio, sort by it, and read the ratios
back as an Array. **construct** is the library taking the rows as an Array of
Hashes, and **compute** is the workload. Every library's ratios are compared with
plain Ruby's before anything is timed, and the script stops on a disagreement.
Medians of five, after a warm run. A library which will not load is skipped rather
than failing the run.

## The ROADMAP.md timing scripts

These do not run on a clean clone, which is why they are here rather than in
`script/`. They need a sqlite database that is not in this repository, and the
Python ones need NumPy or pandas. What they offer a reader without that database is
the thing prose cannot: whether the two sides were cut the same way.

### What they need

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

### The computation

Group by security, take the close at the earliest and at the latest date within
each group, and keep the securities whose last close exceeds their first. Every
script prints the count, and the securities themselves on stderr, so the outputs can
be diffed rather than compared by eye. All six agree at 1,622.

### The scripts

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

### Reading the phases

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

### Caveats

Medians of five, except the query, which is measured once because it is the phase
you cannot repeat honestly — the second run reads a warm cache. Namo's compute
moves by around fifteen percent run to run where NumPy's and the by-hand figures
hold within five, so its figures should be read to one significant digit. The query is by
far the largest term and the least stable — a cold run has measured over four
seconds against a warm one's second — and it compares database drivers rather than
libraries. Figures move with library versions: the pandas numbers in the ROADMAP
were taken against pandas 3.0.5 and numpy 2.5.2, and which of its three routes is
fastest is not stable across versions.
