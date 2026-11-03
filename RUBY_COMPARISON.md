# Namo and the Ruby Data Libraries

Date: 20261103

Compared at Namo 0.32.11; Daru 0.3, Rover 1.1.0 with numo-narray-alt 0.12.0, Polars-ruby 0.27.1 (the `polars-df` gem), and RedAmber 0.5.2 with Red Arrow 26.0.0, on Ruby 4.0.7. Release dates, download counts, and stars are from RubyGems and GitHub on the date above.

Every snippet below, and the probes behind the claims, are run by `comparison/ruby_claims.rb`; the timings are `comparison/ruby_dataframes.rb`'s. See [comparison/](comparison/README.md).

[COMPARISON.md](COMPARISON.md) sets Namo against the tools people leave Ruby for: pandas, Polars, R/dplyr, xarray, and DataFrames.jl. This document answers the question someone already in Ruby asks first: why Namo, and not one of the Ruby options?

Namo feature status is marked as **shipped**, **planned** (with version), or **not planned**.


## The field

**Daru** (Data Analysis in RUby). SciRuby's DataFrame: Vectors and an Index, group-by, rolling statistics, plotting, and the container the statsample family expects. 0.3, May 2020, is the last release, and the SciRuby repository was last pushed to in August 2023. About 3.5 million downloads. `daru_lite` (0.3.4, July 2026) is a maintained fork with the same API, and loads where Daru does.

**Rover** (`rover-df`, Andrew Kane). A columnar DataFrame on numo-narray-alt, the same author's maintained fork of Numo::NArray. CSV and Parquet, ActiveRecord ingestion, column arithmetic and statistics, joins. 1.1.0, August 2026; 22 releases; about 4 million downloads.

**Polars-ruby** (`polars-df`, Andrew Kane). Bindings to the Rust Polars engine, following the Python API: lazy frames and query optimisation, expressions, window functions, joins including as-of and inequality joins, and I/O for CSV, Parquet, JSON, Arrow, and more. 0.27.1, August 2026; 254 releases; about 970,000 downloads and 1,000 stars. The most capable of the four.

**RedAmber** (Red Data Tools). A DataFrame on Apache Arrow through Red Arrow, with a block-based API. 0.5.2, August 2023, is the last release, and the repository was last pushed to in May 2025. About 18,000 downloads.


## Ingestion

```ruby
# Namo
namo = Namo.new([
  {symbol: 'BHP', close: 42.5, date: '2025-01-01'},
  {symbol: 'RIO', close: 118.3, date: '2025-01-01'}
])
```

```ruby
# Daru
df = Daru::DataFrame.new([
  {symbol: 'BHP', close: 42.5, date: '2025-01-01'},
  {symbol: 'RIO', close: 118.3, date: '2025-01-01'}
])
```

```ruby
# Rover
df = Rover::DataFrame.new([
  {symbol: 'BHP', close: 42.5, date: '2025-01-01'},
  {symbol: 'RIO', close: 118.3, date: '2025-01-01'}
])
```

```ruby
# Polars
df = Polars::DataFrame.new([
  {symbol: 'BHP', close: 42.5, date: '2025-01-01'},
  {symbol: 'RIO', close: 118.3, date: '2025-01-01'}
])
```

```ruby
# RedAmber
df = RedAmber::DataFrame.new(
  symbol: ['BHP', 'RIO'],
  close: [42.5, 118.3],
  date: ['2025-01-01', '2025-01-01']
)
```

Daru, Rover, and Polars take an array of hashes, as Namo does, and columns as well. RedAmber takes columns only: given an array of hashes it raises `RedAmber::DataFrameTypeError`.

After that they differ. The other four copy the data into their own storage — Vectors, Numo arrays, Polars Series, Arrow arrays — and from then on their copy is the data. Namo keeps the array it was given: `namo.data.equal?(rows)` is `true`, and a change to one of those hashes shows in the Namo. Anything that already produces hashes — Sequel, `JSON.parse`, a CSV reader — hands over without conversion.

Rover stores names as strings. `df[:close]` finds the column, but `each_row` and the block of `sort_by` see `{"close" => 42.5}`, so a block reading `row[:close]` gets `nil`, and `sort_by!{|row| row[:pe]}` returns the frame unsorted without raising.


## Selection

```ruby
# Namo — shipped
namo[symbol: 'BHP']
namo[symbol: 'BHP', date: '2025-01-01']
namo[close: 40.0..45.0]
namo[symbol: ['BHP', 'RIO']]
namo[close: ->(v){v > 40}]
namo[symbol: /^B/]
```

```ruby
# Daru
df.where(df[:symbol].eq('BHP'))
df.where(df[:symbol].eq('BHP') & df[:date].eq('2025-01-01'))
df.where(df[:close].mteq(40.0) & df[:close].lteq(45.0))
df.where(df[:symbol].in(['BHP', 'RIO']))
df.filter_rows{|row| row[:close] > 40}
df.where(df[:symbol].match(/^B/))
```

```ruby
# Rover
df[df[:symbol] == 'BHP']
df[(df[:symbol] == 'BHP') & (df[:date] == '2025-01-01')]
df[(df[:close] >= 40.0) & (df[:close] <= 45.0)]
df[df[:symbol].in?(['BHP', 'RIO'])]
df[df[:close].map{|v| v > 40}]
df[df[:symbol].map{|v| v.match?(/^B/)}]
```

```ruby
# Polars
df.filter(symbol: 'BHP')
df.filter((Polars.col('symbol') == 'BHP') & (Polars.col('date') == '2025-01-01'))
df.filter(Polars.col('close').is_between(40.0, 45.0))
df.filter(Polars.col('symbol').is_in(['BHP', 'RIO']))
df.filter(Polars.col('close').map_elements(return_dtype: Polars::Boolean){|v| v > 40})
df.filter(Polars.col('symbol').str.contains('^B'))
```

```ruby
# RedAmber
df.filter{symbol == 'BHP'}
df.filter{(symbol == 'BHP') & (date == '2025-01-01')}
df.filter{(close >= 40.0) & (close <= 45.0)}
df.filter{symbol.is_in('BHP', 'RIO')}
df.filter{close.to_a.map{|v| v > 40}}
df.filter{symbol.match_substring?(/^B/)}
```

All five select by equality, range, membership, a Ruby predicate, and a pattern. They differ in how it is written. Namo takes the criterion itself as the value for the dimension, which can be a scalar, an Array, a Range, a Proc, or a Regexp, mixed freely in one call. The others first build a mask or an expression from the column: a comparison method (`eq`, `mteq`) in Daru, an operator on a Vector in Rover, an expression in Polars, and a block evaluated against the columns in RedAmber. Polars' keyword form of `filter` is the nearest to Namo's, and it is equality only.

A Ruby predicate in the others is a separate route: Daru's `filter_rows`, a `map` over Rover's Vector or RedAmber's array, or Polars' `map_elements`, which calls Ruby once per value.

Every Namo selection returns a Namo; the others return their own frame type.


## Projection and contraction

```ruby
# Namo — shipped
namo[:symbol, :close]
namo[-:date]
namo / template
```

```ruby
# Daru
df[:symbol]             # a Vector
df[:symbol, :close]     # a DataFrame
```

```ruby
# Rover
df[:symbol]             # a Vector
df[[:symbol, :close]]   # a DataFrame
df.except(:date)
```

```ruby
# Polars
df['symbol']            # a Series
df.select('symbol', 'close')
df.drop('date')
```

```ruby
# RedAmber
df[:symbol]             # a Vector
df.pick(:symbol, :close)
df.drop(:date)
```

Namo contracts in two ways: `-:date` inside `[]` removes named dimensions from one Namo, and `/` removes the dimensions a second Namo, the template, does not share. `/` is the inverse of `*`, and both operands are Namos. The others remove columns with a named method, and asking for one column leaves the frame for a Vector or Series.


## Composition

```ruby
# Namo — shipped
prices * sectors
```

```ruby
# Daru
df.join(other, on: [:symbol], how: :inner)
```

```ruby
# Rover
df.inner_join(other)
df.inner_join(other, on: :symbol)
df.left_join(other, on: :symbol)
```

```ruby
# Polars
df.join(other, on: 'symbol', how: 'inner')
df.join_asof(other, left_on: 'date', right_on: 'quarter_end', by: 'symbol')
```

```ruby
# RedAmber
df.join(other)
df.join(other, :symbol)
```

Namo's `*` pairs rows on the dimensions the two Namos share, so no key is named. Rover's `inner_join` and RedAmber's `join` do the same when given none, joining on the common columns. Daru and Polars want the key: Polars raises `ArgumentError` without `on`.

Where Namo differs is that the join is one operator in an algebra: `*` and `**` compose, `/` decomposes, and `+`, `-`, `&`, `|`, and `^` combine, each taking Namos and returning one. Polars has the richest join vocabulary — as-of, inequality (`join_where`), semi, and anti — and Namo has neither as-of nor inequality joins as operators; a block on `*` refines matching instead.


## Formulae and computed columns

```ruby
# Namo — shipped
namo[:pe] = proc{|row| row[:close] / row[:eps]}
namo[:sma] = ->(row, namo){
  closes = namo[symbol: row[:symbol], date: ..row[:date]].values(:close).last(20)
  closes.sum / closes.length
}
```

```ruby
# Daru
df[:pe] = df[:close] / df[:eps]
df[:sma] = df[:close].rolling_mean(20)
```

```ruby
# Rover
df[:pe] = df[:close] / df[:eps]
```

```ruby
# Polars
df = df.with_columns(
  (Polars.col('close') / Polars.col('eps')).alias('pe'),
  Polars.col('close').rolling_mean(20).alias('sma')
)
```

```ruby
# RedAmber
df = df.assign(:pe){close / eps}
```

In the four others a computed column is computed once and stored: change `close` afterwards and `pe` keeps the old quotient. A Namo formula is resolved when it is read, so it always reflects the current data, and formulae may refer to formulae defined later. A formula is any Ruby callable over any Ruby values. One taking `(row, namo)` is collection-scoped, which is how windows are written; one taking further parameters receives them at access time; and a formulary attaches a module of them at once.

Daru and Polars have built-in rolling statistics, and Polars a great deal besides. Rover has none. RedAmber has cumulative sums and shifts but no rolling windows. Namo has no built-in statistics: the window is a selection, and the reduction is the caller's Ruby.

Namo's formulae are written `row[:close]`. Bare names, `proc{eps / close}`, are **planned (2.x)**.


## Type handling

Namo holds any Ruby object in any dimension, with no declaration, schema, or coercion. A Date, a String, and an Integer in one dimension select and compute as readily as Floats.

Given that column, Daru holds it. Rover stores it as an `:object` column, outside Numo's typed arithmetic. Polars raises `TypeError`, its columns being strictly typed. RedAmber raises `TypeError`.


## Set operations

```ruby
# Namo — shipped
a & b
a | b
a - b
a ^ b
a < b
a <= b
a > b
a >= b
a == b
```

```ruby
# Daru
df.union(other)
df.concat(other)
```

```ruby
# Rover
df + other
df.concat(other)
df == other
```

```ruby
# Polars
Polars.concat([df, other])
df.join(other, on: 'symbol', how: 'anti')
df.equals(other)
```

```ruby
# RedAmber
df.union(other)
df.intersect(other)
df.difference(other)
df.concatenate(other)
df == other
```

RedAmber has union, intersection, and difference; Daru has union; Rover and Polars concatenate, and Polars subtracts by an anti join. None has a symmetric difference or subset and superset tests: Polars' `<` and `>=` compare frames element by element. Rover's `concat` appends to its receiver, where `+` returns a new frame. Namo has the whole set as operators, with comparison modelled on Ruby's `Set`: `<` and `>` are subset and superset, a partial order, so there is no `<=>`.


## Enumerable

Namo includes `Enumerable`, yielding Rows. The subset-returning methods — `select`, `reject`, `sort_by`, `first`, `last`, `take`, `drop`, `take_while`, `drop_while`, `uniq`, `partition` — return Namos, so a chain stays a Namo. `group_by(:sector)` returns a `Namo::Collection`; the block form raises, saying that `entries.group_by{|row| ...}` partitions by a computed key.

None of the other four includes `Enumerable`. Each iterates rows on request: Daru's `each_row` yields Vectors, Rover's and Polars' (`iter_rows(named: true)`) yield Hashes with string keys, and RedAmber's yields Hashes with symbol keys. Row-by-row iteration works against a columnar engine, and Polars' documentation says so; Namo makes the opposite trade: Ruby's iteration methods, at the cost of speed on large data.


## Interactive exploration

In `irb`, short queries save typing: `namo[symbol: 'BHP']` against `df.filter(Polars.col('symbol') == 'BHP')` or `df[df[:symbol] == 'BHP']`, fifty times in a session.

The drill-down is three methods, each returning a plain Array or Hash:

```ruby
namo.dimensions             # => [:symbol, :close, :date]
namo.coordinates(:symbol)   # => ['BHP', 'RIO']
namo.values(:close)         # => [42.5, 118.3]
```

against `df.columns`, `df['symbol'].unique.to_a`, and `df['close'].to_a` in Polars, or `df.keys`, `df[:symbol].uniq.to_a`, and `df[:close].to_a` in Rover.

What the others do better is display. Polars prints a table with types and borders, RedAmber a table with types, and Daru and Rover tables with aligned columns. Namo's `inspect` (0.31.0) prints its rows as hashes, including derived values, ten at most, with a count of the rest: complete within that limit, but not a table.


## Parallelism and concurrency

```ruby
snapshot = Ractor.make_shareable(Namo.new(rows))
mining = Ractor.new(snapshot){|data| data[sector: 'Mining'].values(:close)}
mining.value
```

A Namo of plain data can be made shareable and read from other Ractors in parallel, without copying. A formula must be a shareable proc, `Ractor.shareable_proc{|row| ...}`, since an ordinary block's `self` is not shareable.

One limit at 0.32.11: `freeze` alone is shallow, guarding neither the stored hashes nor `[]=`. Freezing as a supported state, and the caching it permits, is **planned (2.x)**.

None of the other four can be queried from a Ractor. A Polars frame cannot be made shareable, nor can a Rover frame with an object column. A Rover frame of numbers only can, as can Daru's and RedAmber's. Inside a Ractor, Daru and that Rover frame return a column, but selecting from either raises, as does reading a RedAmber column: their methods are defined from procs which are not shareable.

Polars parallelises internally instead, across cores in Rust, which is faster than Ractors iterating Ruby hashes will be. What it does not offer is parallelism over your own Ruby: Namo's is coarse-grained and yours to partition, by selection, by predicate, or by slice.


## Storage and speed

Namo stores an array of Hashes: no conversion in, and every row an object on the Ruby heap. Daru stores Ruby Arrays per column, Rover typed Numo arrays, Polars Rust Series, and RedAmber Arrow arrays.

### Measured

One workload, written idiomatically in each library: select one sector's rows, a quarter of them, derive a price-earnings ratio, sort by it, and read the ratios back as an Array. The rows arrive as an Array of Hashes, generated from a fixed seed. **construct** is the library taking them, and **compute** the workload; every library's answer is checked against plain Ruby's before anything is timed. Milliseconds, medians of five after a warm run, on one machine.

| | 2,000 rows | | 100,000 rows | | 1,000,000 rows | |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| | construct | compute | construct | compute | construct | compute |
| plain Ruby | — | 0.3 | — | 21 | — | 254 |
| Namo | 0.0 | 3.8 | 0.0 | 155 | 0.0 | 1,436 |
| Daru | 0.7 | 10.5 | 64 | 507 | 844 | 6,243 |
| Rover | 1.4 | 0.9 | 83 | 40 | 1,010 | 460 |
| Polars | 2.3 | 0.4 | 80 | 1.0 | 775 | 6.0 |
| RedAmber | 13.1 | 0.9 | 615 | 14 | 6,342 | 143 |

RedAmber's construct includes turning the rows into columns, the only shape it takes. Under YJIT no figure moved by more than it moves from run to run. Plain Ruby's figures move the most, by up to a third, depending on when garbage collection runs, and Namo's 100,000-row figure by up to a fifth, so read those to one significant digit.

### What the figures mean

At 2,000 rows every library answers within fifteen milliseconds.

Where the data arrives as hashes and is asked one question, construction is most of a columnar library's cost, and Namo, having none, is level with Rover at a million rows and within a factor of two of Polars. Daru and RedAmber take four to five times as long.

Where one frame is asked many questions, construction is paid once and compute is what counts. There, at a million rows, Polars is about 240 times faster than Namo, RedAmber ten times, and Rover three times; Daru is four times slower.

Namo takes six to thirteen times as long as plain Ruby on the same work, the distance narrowing as the rows grow. That is Namo's own machinery, the Row objects and intermediate Namos, and not Ruby: ROADMAP.md finds a distance of the same order, in allocations, on a different workload.

For how Namo's time divides, and the sizes it is for, see "Measured, at 0.31.0" in [ROADMAP.md](ROADMAP.md): comfortable to a couple of hundred thousand rows, workable to about a million. Columnar storage and C acceleration are **planned (3.x)**, and DuckDB as a backend **planned (4.x)**.


## Dependencies

Namo has no runtime dependencies.

Daru depends on `packable` and on `matrix`, which Ruby ships as a bundled gem since 3.1; where gems are isolated, `matrix` must be installed for Daru to load.

Rover depends on numo-narray-alt, a C extension compiled on install.

Polars-ruby ships precompiled native gems for the common platforms, and otherwise builds with the Rust toolchain through `rb_sys`. Installed, the arm64-darwin gem is 411 MB.

RedAmber depends on Red Arrow, which wants Apache Arrow's C++ and GLib libraries from the system, and the GLib and GObject Introspection gems. Here they came from conda-forge, 540 MB with their dependencies, and Red Arrow's major version must match Arrow's.


## Maintenance

| | latest | released | releases | downloads |
| --- | --- | --- | --- | --- |
| Polars-ruby | 0.27.1 | 2026-08-12 | 254 | ~970,000 |
| Rover | 1.1.0 | 2026-08-15 | 22 | ~4,000,000 |
| RedAmber | 0.5.2 | 2023-08-31 | 19 | ~18,000 |
| Daru | 0.3 | 2020-05-30 | 22 | ~3,500,000 |
| daru_lite | 0.3.4 | 2026-07-20 | 13 | ~25,000 |

Polars-ruby and Rover are actively maintained by Andrew Kane, Polars-ruby tracking the Python API. RedAmber has not released in over two years. Daru has not released in over five; its statsample dependants keep it installed, and daru_lite carries it on.

Namo is pre-1.0 and actively developed. It is compared with established libraries because it takes a different approach, not because it has comparable adoption.


## Where they sit

Polars-ruby is a performance engine: Ruby is the interface and Rust the execution. Use it for speed on large data.

Rover is a light columnar DataFrame. Use it for something simpler than Polars, with a smaller feature set and an easier install.

RedAmber is an Arrow DataFrame with a block-based Ruby API. Use it for Arrow interoperability, given its pace of maintenance.

Daru is the legacy DataFrame of the statsample family. Use it, or daru_lite, where that family is already in use.

Namo is a dimension-symmetric query engine over arrays of hashes. Use it to work with data in the form it arrives in, without copying it into a container or declaring a schema, with formulae that stay live and an algebra of operators over whole datasets.

If you need speed, use Polars. If you need a light table, use Rover. If you need Ruby's expressiveness, dimension symmetry, and an operator algebra over data in its own shape, use Namo. They are not competing for the same job.
