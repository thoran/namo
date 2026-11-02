#!/usr/bin/env ruby
# namo_claims.rb

# 20261101
# 0.0.0

# The Namo snippets in COMPARISON.md, in the document's order, each run against
# small inline data, followed by the probes behind its claims about Namo.
#
# Each step prints its label and its result, or the exception it raised, so a claim
# that something fails is shown failing.

require 'date'
require_relative '../lib/namo'

def show(label)
  puts "## #{label}"
  begin
    result = yield
    puts(result.is_a?(String) ? result : result.inspect)
  rescue StandardError => e
    puts "raises #{e.class}: #{e.message}"
  end
  puts
end

def records
  [
    {symbol: 'BHP', exchange: 'ASX', quarter: 'Q1', close: 42.5, pe: 12.0, volume: 100, price: 10.0, quantity: 3, cost: 20.0},
    {symbol: 'RIO', exchange: 'ASX', quarter: 'Q1', close: 118.3, pe: nil, volume: 200, price: 20.0, quantity: 2, cost: 30.0},
    {symbol: 'BHP', exchange: 'ASX', quarter: 'Q2', close: 43.1, pe: 16.0, volume: 0, price: 11.0, quantity: 4, cost: 25.0},
    {symbol: 'WES', exchange: 'ASX', quarter: 'Q2', close: 15.0, pe: 9.0, volume: 50, price: 5.0, quantity: 10, cost: 40.0},
  ]
end

# Dates as day numbers: at 0.32.7 Row#match? tests a Range with include?, which
# raises TypeError for a beginless range of Dates or Strings.  Shown below.
def prices(start = 1)
  rows = [['BHP', 40.0], ['RIO', 110.0]].flat_map do |symbol, base|
    (0...25).map{|i| {symbol: symbol, date: start + i, close: base + i, volume: 1000 + 10 * i}}
  end
  Namo.new(rows)
end

puts "namo #{Namo::VERSION}"
puts

namo = Namo.new(records)


# Ingestion and schema

show('Schema-free instantiation'){Namo.new([{symbol: 'BHP', close: 42.5}, {symbol: 'RIO', close: 118.3}])}
show('No index/data distinction'){[namo[symbol: 'BHP'].count, namo[close: 42.5].count]}


# Selection

show('Keyword selection'){namo[symbol: 'BHP'].count}
show('Keyword selection, two dimensions'){namo[symbol: 'BHP', quarter: 'Q1'].count}
show('Array selection'){namo[quarter: ['Q1', 'Q2']].count}
show('Range selection'){namo[close: 10.0..20.0].values(:symbol)}
show('Proc selection'){namo[pe: ->(v){ v && v < 15 }].values(:symbol)}
show('Regex selection'){namo[symbol: /^BH/].count}
show('Mixed selection'){namo[symbol: /^BH/, close: 10.0..50.0, pe: ->(v){ v && v < 15 }, quarter: 'Q1'].values(:symbol)}


# Projection and contraction

show('Projection'){namo[:symbol, :close].dimensions}
show('Contraction'){namo[-:symbol, -:close].dimensions}
show('Projection and contraction in one call'){namo[:symbol, -:close]}
show('Combined selection and projection'){namo[:symbol, :close, quarter: 'Q1'].to_a}


# Formulae

show('Computed dimension, then a change to price') do
  n = Namo.new(records)
  n[:revenue] = proc{|row| row[:price] * row[:quantity]}
  n.data.first[:price] = 100.0
  n.values(:revenue)
end

show('Formula chain') do
  n = Namo.new(records)
  n[:revenue] = proc{|row| row[:price] * row[:quantity]}
  n[:profit] = proc{|row| row[:revenue] - row[:cost]}
  n[:margin] = proc{|row| row[:profit] / row[:revenue]}
  n.values(:margin)
end

show('Formula chain, defined out of order') do
  n = Namo.new(records)
  n[:margin] = proc{|row| row[:profit] / row[:revenue]}
  n[:profit] = proc{|row| row[:revenue] - row[:cost]}
  n[:revenue] = proc{|row| row[:price] * row[:quantity]}
  n.values(:margin)
end

show('Two-arity formulae') do
  n = prices
  n[:sma_20] = proc do |row, namo|
    window = namo[symbol: row[:symbol], date: ..row[:date]].last(20)
    window.sum{|r| r[:close]} / window.count.to_f
  end
  n[symbol: 'BHP'].values(:sma_20).last(3)
end

show('Two-arity formulae, with Dates') do
  n = prices(Date.new(2025, 1, 1))
  n[:sma_20] = proc do |row, namo|
    window = namo[symbol: row[:symbol], date: ..row[:date]].last(20)
    window.sum{|r| r[:close]} / window.count.to_f
  end
  n.values(:sma_20)
end

show('Parameterised formulae') do
  n = prices
  n[:sma] = proc do |row, namo, field, period|
    window = namo[symbol: row[:symbol], date: ..row[:date]].last(period)
    window.sum{|r| r[field]} / window.count.to_f
  end
  row = n[symbol: 'BHP'].entries.last
  [row[:sma, :close, 20], row[:sma, :volume, 50]]
end

show('Parameterised formulae, wrong argument count') do
  n = prices
  n[:sma] = proc{|row, namo, field, period| period}
  n.entries.last[:sma, :close]
end

module Indicators
  include Namo::Formulary
  def signed_volume(row); row[:buys] - row[:sells]; end
  def cum_delta(row, namo); namo[date: ..row[:date]].values(:signed_volume).sum; end
end

show('Formularies') do
  flows = Namo.new([
    {date: 1, buys: 10, sells: 4},
    {date: 2, buys: 3, sells: 8},
    {date: 3, buys: 7, sells: 2},
  ])
  flows.attach(Indicators)
  flows.values(:cum_delta)
end


# Composition

def ohlcv
  Namo.new([
    {symbol: 'BHP', exchange: 'ASX', date: Date.new(2025, 3, 31), close: 42.5},
    {symbol: 'BHP', exchange: 'ASX', date: Date.new(2025, 7, 1), close: 44.0},
    {symbol: 'RIO', exchange: 'ASX', date: Date.new(2025, 7, 1), close: 118.3},
  ])
end

def fundamentals
  Namo.new([
    {symbol: 'BHP', exchange: 'ASX', quarter_end: Date.new(2024, 12, 31), pe: 11.0},
    {symbol: 'BHP', exchange: 'ASX', quarter_end: Date.new(2025, 6, 30), pe: 12.0},
    {symbol: 'RIO', exchange: 'ASX', quarter_end: Date.new(2025, 6, 30), pe: 9.0},
  ])
end

show('Equi-join'){(ohlcv * fundamentals).to_a}

show('Conditional join with block') do
  ohlcv.*(fundamentals) do |row, candidates|
    candidates[quarter_end: ->(qe){qe <= row[:date]}].sort_by{|f| f[:quarter_end]}.last(1)
  end.to_a
end

show('Cartesian product'){(ohlcv ** Namo.new([{pe: 11.0}, {pe: 12.0}])).count}
show('Cartesian product of operands sharing a dimension'){ohlcv ** fundamentals}

show('Decomposition') do
  a = Namo.new([{symbol: 'BHP'}, {symbol: 'RIO'}])
  b = Namo.new([{pe: 11.0}, {pe: 12.0}])
  c = Namo.new([{symbol: 'BHP', exchange: 'ASX'}, {symbol: 'RIO', exchange: 'ASX'}])
  d = Namo.new([{exchange: 'ASX', region: 'AU'}])
  [((a ** b) / b) == a, ((c * d) / d) == c[-:exchange], (a / b) == a, ((a / b) / b) == a / b]
end


# Aggregation

show('Bare Enumerable group_by'){namo.entries.group_by{|row| row[:symbol]}.transform_values{|rows| rows.sum{|r| r[:close]} / rows.length}}

show('Collection by assembly') do
  bhp_namo = namo[symbol: 'BHP']
  bhp_namo.name = 'BHP'
  rio_namo = namo[symbol: 'RIO']
  rio_namo.name = 'RIO'
  collection = Namo::Collection.new
  collection << bhp_namo
  collection << rio_namo
  [collection.summary(:close).to_a, collection.members.map{|n| n.values(:close).sum / n.count}]
end

show("summary with reducer: :mean, with no statistics library loaded"){namo.group_by(:symbol).summary(:close, reducer: :mean).to_a}
show('summary with a block'){namo.group_by(:symbol).summary{|member| {close: member.values(:close).sum / member.count}}.to_a}
show('group_by round-trips through as_detail'){namo.group_by(:symbol).as_detail(:symbol) == namo}

show('group_by a formula') do
  n = Namo.new(records)
  n[:value_score] = proc{|row| !row[:pe].nil? && row[:pe] < 10}
  n.group_by(:value_score).members.map{|m| [m.name, m.count]}
end


# Set operators

show('Row-level set algebra') do
  a = Namo.new([{x: 1}, {x: 2}])
  b = Namo.new([{x: 2}, {x: 3}])
  [(a + b).values(:x), (a - b).values(:x), (a & b).values(:x), (a | b).values(:x), (a ^ b).values(:x)]
end

show('Set operators carry formulae') do
  a = Namo.new([{x: 1}, {x: 2}])
  a[:double] = proc{|row| row[:x] * 2}
  (a | Namo.new([{x: 3}])).values(:double)
end

show('Keyed anti-join') do
  today = Namo.new([{symbol: 'BHP'}, {symbol: 'RIO'}, {symbol: 'WES'}])
  exclusions = Namo.new([{symbol: 'RIO'}])
  excluded = exclusions.values(:symbol)
  today[symbol: ->(s){ !excluded.include?(s) }].values(:symbol)
end

show("Worked example: yesterday's screen against today's") do
  today = Namo.new([{symbol: 'BHP'}, {symbol: 'RIO'}, {symbol: 'WES'}])
  yesterday = Namo.new([{symbol: 'BHP'}, {symbol: 'RIO'}])
  status = if today == yesterday; "no change"
        elsif today >= yesterday; "added #{(today - yesterday).count} candidates"
        elsif yesterday >= today; "removed #{(yesterday - today).count} candidates"
        else;                     "churn: #{(today ^ yesterday).count} differing"
  end
  status
end


# Type handling

show('Type agnosticism') do
  n = Namo.new(records)
  n[:label] = proc{|row| "#{row[:symbol]} (#{row[:exchange]})"}
  n[:status] = proc{|row| row[:volume] > 0 ? 'active' : 'suspended'}
  n[status: 'active'].values(:label)
end


# Enumerable integration

show('Yields formula-aware objects') do
  n = Namo.new(records)
  n[:revenue] = proc{|row| row[:price] * row[:quantity]}
  n.reduce(0){|sum, row| sum + row[:revenue]}
end

show('Enumerable methods return Namos') do
  filtered = namo.select{|row| row[:close] > 40.0}
  [filtered.class, filtered[symbol: 'BHP'].count, namo.reject{|row| row[:close] > 40.0}.class, namo.sort_by{|row| row[:close]}.class]
end


# Comparison

show('Equality hierarchy') do
  a = Namo.new([{x: 1}, {x: 2}])
  b = Namo.new([{x: 2}, {x: 1}])
  analysis = Class.new(Namo)
  [a.equal?(b), a.eql?(b), a == b, a === b,
    Namo.new([{x: 1}, {x: 1}]) == Namo.new([{x: 1}]),
    analysis.new([{x: 1}]).eql?(Namo.new([{x: 1}])), analysis.new([{x: 1}]) == Namo.new([{x: 1}]),
    a.hash == b.hash]
end

show('Schema dispatch') do
  ohlcv_shape        = Namo.new([{date: nil, symbol: nil, open: 0.0, high: 0.0, low: 0.0, close: 0.0, volume: 0}])
  fundamentals_shape = Namo.new([{symbol: nil, pe: 0.0, book_value: 0.0, dividend_yield: 0.0}])
  dispatch = lambda do |incoming|
    case incoming
    when ohlcv_shape        then 'ohlcv'
    when fundamentals_shape then 'fundamentals'
    else raise ArgumentError, "unknown shape: #{incoming.dimensions}"
    end
  end
  [
    dispatch.call(Namo.new([{symbol: 'BHP', pe: 12.0, book_value: 3.0, dividend_yield: 0.04}])),
    (dispatch.call(Namo.new([{symbol: 'BHP', pe: 12.0, book_value: 3.0, dividend_yield: 0.04, sector: 'Materials'}])) rescue $!.message),
  ]
end

show('Subset/superset') do
  one = Namo.new([{x: 1}])
  two = Namo.new([{x: 1}, {x: 1}])
  [one < two, one <= two, two > one, two >= one, (one & two) == one]
end


# Introspection

show('Dimensions, coordinates, values') do
  n = Namo.new([{symbol: 'BHP', close: 42.5}, {symbol: 'RIO', close: 118.3}, {symbol: 'BHP', close: 43.1}])
  [n.dimensions, n.coordinates[:symbol], n.values[:symbol], n.values, n.to_h == n.values]
end
