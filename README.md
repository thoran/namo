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

Create a Namo instance from an array of hashes:

```ruby
require 'namo'

sales = Namo.new([
  {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
  {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
  {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
  {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
])
```

Dimensions and coordinates are inferred:

```ruby
sales.dimensions
# => [:product, :quarter, :price, :quantity]

sales.coordinates[:product]
# => ['Widget', 'Gadget']

sales.coordinates[:quarter]
# => ['Q1', 'Q2']
```

### Selection

Select by named dimension using keyword arguments:

```ruby
# Single value
sales[product: 'Widget']
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
#   {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150}
# ]>

# Multiple dimensions
sales[product: 'Widget', quarter: 'Q1']
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100}
# ]>

# Range
sales[price: 10.0..20.0]
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
#   {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150}
# ]>

# Array of values
sales[quarter: ['Q1']]
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
#   {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40}
# ]>
```

### Projection

Project to specific dimensions:

```ruby
sales[:product, :price]
# => #<Namo [
#   {product: 'Widget', price: 10.0},
#   {product: 'Widget', price: 10.0},
#   {product: 'Gadget', price: 25.0},
#   {product: 'Gadget', price: 25.0}
# ]>
```

Selection and projection can be chained:

```ruby
sales[product: 'Widget'][:quarter, :price]
# => #<Namo [
#   {quarter: 'Q1', price: 10.0},
#   {quarter: 'Q2', price: 10.0}
# ]>
```

Or combined in a single call (names before selectors):

```ruby
sales[:quarter, :price, product: 'Widget']
# => #<Namo [
#   {quarter: 'Q1', price: 10.0},
#   {quarter: 'Q2', price: 10.0}
# ]>
```

### Contraction

Contraction is the complement of projection. Projection says "keep these dimensions"; contraction says "remove these dimensions, keep everything else":

```ruby
sales[-:price, -:quantity]
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1'},
#   {product: 'Widget', quarter: 'Q2'},
#   {product: 'Gadget', quarter: 'Q1'},
#   {product: 'Gadget', quarter: 'Q2'}
# ]>
```

The `-:price` syntax uses unary minus on Symbol to produce a negated dimension. Mixing projection and contraction in the same call is an error — the two modes are mutually exclusive:

```ruby
sales[:product, -:price]  # => ArgumentError
```

Selection and contraction can be chained:

```ruby
sales[product: 'Widget'][-:price, -:quantity]
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1'},
#   {product: 'Widget', quarter: 'Q2'}
# ]>
```

Or combined in a single call (names before selectors):

```ruby
sales[-:price, -:quantity, product: 'Widget']
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1'},
#   {product: 'Widget', quarter: 'Q2'}
# ]>
```

Selection, projection, and contraction always return a new Namo instance, so everything chains.

### Concatenation

`+` combines two Namo objects that share the same dimensions by appending the rows of the second to the first:

```ruby
q1_sales = Namo.new([
  {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
  {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40}
])

q2_sales = Namo.new([
  {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
  {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
])

all_sales = q1_sales + q2_sales
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
#   {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
#   {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
#   {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
# ]>
```

The dimensions must match — concatenating Namo objects with different dimensions raises an `ArgumentError`. Formulae carry through from the left-hand side.

### Row Removal

`-` removes from the first Namo any row that appears exactly in the second:

```ruby
sales = Namo.new([
  {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
  {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
  {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
  {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
])

discontinued = Namo.new([
  {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
  {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
])

sales - discontinued
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
#   {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150}
# ]>
```

Removal is exact — every dimension, every value must match. The dimensions must match; different dimensions raise an `ArgumentError`. Formulae carry through from the left-hand side.

### Formulae

Define computed dimensions using `[]=`:

```ruby
sales[:revenue] = proc{|row| row[:price] * row[:quantity]}

sales[:product, :quarter, :revenue]
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', revenue: 1000.0},
#   {product: 'Widget', quarter: 'Q2', revenue: 1500.0},
#   {product: 'Gadget', quarter: 'Q1', revenue: 1000.0},
#   {product: 'Gadget', quarter: 'Q2', revenue: 1500.0}
# ]>
```

Formulae compose:

```ruby
sales[:cost] = proc{|row| row[:quantity] * 4.0}
sales[:profit] = proc{|row| row[:revenue] - row[:cost]}

sales[:product, :quarter, :profit]
# => #<Namo [
#   {product: 'Widget', quarter: 'Q1', profit: 600.0},
#   {product: 'Widget', quarter: 'Q2', profit: 900.0},
#   {product: 'Gadget', quarter: 'Q1', profit: 840.0},
#   {product: 'Gadget', quarter: 'Q2', profit: 1260.0}
# ]>
```

Formulae work with selection and projection:

```ruby
sales[product: 'Widget'][:revenue, :quarter]
# => #<Namo [
#   {revenue: 1000.0, quarter: 'Q1'},
#   {revenue: 1500.0, quarter: 'Q2'}
# ]>
```

Formulae carry through selection — a filtered Namo instance remembers its formulae.

### Enumerable

Namo includes `Enumerable`, so `each`, `reduce`, `map`, `select`, `min_by`, and all the rest work out of the box. Rows are yielded as `Row` objects, so formulae are accessible during enumeration:

```ruby
sales.reduce(0){|sum, row| sum + row[:quantity]}
# => 350

sales[product: 'Widget'].reduce(0){|sum, row| sum + row[:quantity]}
# => 250

sales[:revenue] = proc{|row| row[:price] * row[:quantity]}

sales.reduce(0){|sum, row| sum + row[:revenue]}
# => 5000.0

sales[product: 'Widget'].reduce(0){|sum, row| sum + row[:revenue]}
# => 2500.0

sales.map{|row| row[:product]}
# => ['Widget', 'Widget', 'Gadget', 'Gadget']

sales.min_by{|row| row[:price]}[:product]
# => 'Widget'

sales.flat_map{|row| [row[:price]]}
# => [10.0, 10.0, 25.0, 25.0]
```

### Extracting data

`to_a` returns an array of hashes:

```ruby
sales[:product, :quarter, :revenue].to_a
# => [
#   {product: 'Widget', quarter: 'Q1', revenue: 1000.0},
#   {product: 'Widget', quarter: 'Q2', revenue: 1500.0},
#   {product: 'Gadget', quarter: 'Q1', revenue: 1000.0},
#   {product: 'Gadget', quarter: 'Q2', revenue: 1500.0}
# ]
```

## Why?

Every other multi-dimensional array library requires you to pre-shape your data before you can work with it. Namo takes it in the form it likely already comes in.

## Name

Namo: nam(ed) (dimensi)o(ns). A companion to Numo (numeric arrays for Ruby). And in Aussie culture 'o' gets added to the end of names.

## Contributing

1. Fork it (https://github.com/thoran/namo/fork)
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new pull request

## License

MIT
