#!/usr/bin/env ruby
# other_libraries.rb

# 20261104
# 0.0.0

# The snippets in the README's "Using Namo with other libraries", in order, each on
# the README's own sales data, followed by the probe behind its caveat.
# comparison/setup builds the gems they pass a Namo to, and comparison/.tools/bin/ruby runs this with them.
#
# Each step prints its label and its result, or the exception it raised, so a claim
# that something fails is shown failing.

require_relative '../lib/namo'
require 'statistics-enumerable'
require 'terminal-table'
require 'vega'
require 'polars-df'

def show(label)
  puts "## #{label}"
  begin
    result = yield
    puts(result.is_a?(String) ? result : result.inspect)
  rescue StandardError => e
    puts "raises #{e.class}: #{e.message.lines.first.strip}"
  end
  puts
end

def version(name)
  Gem.loaded_specs[name].version
end

puts "ruby #{RUBY_VERSION}; Namo #{Namo::VERSION}; statistics.rb #{version('statistics.rb')}; terminal-table #{version('terminal-table')}; vega #{version('vega')}; Polars #{Polars::VERSION}"
puts

sales = Namo.new([
  {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
  {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
  {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
  {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
])
sales[:revenue] = proc{|row| row[:price] * row[:quantity]}

show('statistics.rb: mean of a column'){sales.values(:revenue).mean}
show('statistics.rb: standard_deviation of a column'){sales.values(:revenue).standard_deviation}
show('statistics.rb: in a two-arity formula'){
  sales[:revenue_z] = proc{|row, namo| (row[:revenue] - namo.values(:revenue).mean) / namo.values(:revenue).standard_deviation}
  sales.values(:revenue_z)
}
show('statistics.rb: as a summary reducer'){sales.group_by(:product).summary(:revenue, reducer: :mean).to_a}
show('statistics.rb: mean of the Namo itself, over Rows'){sales.mean}
show('terminal-table: from values'){
  columns = sales.values(:product, :quarter, :revenue)
  Terminal::Table.new(headings: columns.keys, rows: columns.values.transpose).to_s
}
show('vega: a bar chart from to_a'){
  Vega.lite
    .data(sales.to_a)
    .mark(type: 'bar')
    .encoding(x: {field: 'quarter'}, y: {field: 'revenue', type: 'quantitative'}, color: {field: 'product'})
    .to_json
}
show('Polars: a pivot from values'){
  Polars::DataFrame.new(sales.values(:product, :quarter, :revenue)).pivot('quarter', index: 'product', values: 'revenue').to_s
}
