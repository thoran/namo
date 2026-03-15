# Namo

Named dimensional data for Ruby.

Namo is a Ruby library for working with multi-dimensional data using named dimensions. It infers dimensions and coordinates from plain arrays of hashes — the same shape you get from databases, CSV files, JSON, and YAML — so there's no reshaping step.

## Installation

```
gem install namo
```

Or in your Gemfile:

```ruby
gem 'namo'
```

## Usage

Create a Namo from an array of hashes:

```ruby
require 'namo'

prices = Namo.new([
  {date: '2025-01-01', symbol: 'BHP', close: 42.5},
  {date: '2025-01-01', symbol: 'RIO', close: 118.3},
  {date: '2025-01-02', symbol: 'BHP', close: 43.1},
  {date: '2025-01-02', symbol: 'RIO', close: 117.8}
])
```

Dimensions and coordinates are inferred:

```ruby
prices.dimensions
# => [:date, :symbol, :close]

prices.coordinates[:date]
# => ['2025-01-01', '2025-01-02']

prices.coordinates[:symbol]
# => ['BHP', 'RIO']
```

Select by named dimension using keyword arguments:

```ruby
# Single value
prices[symbol: 'BHP']

# Multiple dimensions
prices[date: '2025-01-01', symbol: 'BHP']

# Range
prices[close: 42.0..43.0]

# Array of values
prices[symbol: ['BHP', 'RIO']]

# All data
prices[]
```

Selection always returns a new Namo. Omitting a dimension means "all values along that dimension."

## Why?

Every other multi-dimensional array library requires you to pre-shape your data before you can work with it. Namo takes it in the form it already comes in.

## Name

Namo: na(med) (di)m(ensi)o(ns). A companion to Numo (numeric arrays for Ruby).

## Contributing

1. Fork it (https://github.com/thoran/namo/fork)
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new pull request

## License

MIT
