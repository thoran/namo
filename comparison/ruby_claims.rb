#!/usr/bin/env ruby
# ruby_claims.rb

# 20261109
# 0.0.1

# The snippets in RUBY_COMPARISON.md, in the document's order, each run against
# small inline data, followed by the probes behind its claims. One script for the
# five libraries, since all are Ruby; comparison/setup builds the other four, and
# comparison/.tools/bin/ruby runs this with them.
#
# Each step prints its label and its result, or the exception it raised, so a claim
# that something fails is shown failing.

require 'date'
require_relative '../lib/namo'
require 'daru'
require 'rover'
require 'polars-df'
require 'red_amber'

def show(label)
  puts "## #{label}"
  begin
    result = yield
    puts(result.is_a?(String) ? result : result.inspect)
  rescue StandardError => e
    puts "raises #{e.class}: #{e.message.lines.first.strip}"
    cause = e.cause
    puts "  from #{cause.class}: #{cause.message.lines.first.strip}" if e.is_a?(Ractor::RemoteError) && cause
  end
  puts
end

def rows
  [
    {symbol: 'BHP', close: 42.5, date: '2025-01-01', eps: 3.0},
    {symbol: 'RIO', close: 118.3, date: '2025-01-01', eps: 9.0},
    {symbol: 'BXB', close: 20.0, date: '2025-01-02', eps: 1.0},
    {symbol: 'BHP', close: 43.1, date: '2025-01-02', eps: 3.0},
  ]
end

def sector_rows
  [{symbol: 'BHP', sector: 'Mining'}, {symbol: 'RIO', sector: 'Mining'}, {symbol: 'BXB', sector: 'Industrials'}]
end

def columns(rows)
  rows.first.keys.to_h{|key| [key, rows.map{|row| row[key]}]}
end

def mixed
  {a: [Date.new(2025, 1, 1), 'x', 1]}
end

puts "ruby #{RUBY_VERSION}; Namo #{Namo::VERSION}; Daru #{Daru::VERSION}; Rover #{Rover::VERSION}; Polars #{Polars::VERSION}; RedAmber #{RedAmber::VERSION}; Arrow #{Arrow::Version::STRING}"
puts

namo = Namo.new(rows)
daru = Daru::DataFrame.new(rows)
rover = Rover::DataFrame.new(rows)
polars = Polars::DataFrame.new(rows)
red_amber = RedAmber::DataFrame.new(columns(rows))


# Ingestion

show('Namo: array of hashes'){Namo.new(rows).count}
show('Daru: array of hashes'){Daru::DataFrame.new(rows).nrows}
show('Daru: columns'){Daru::DataFrame.new(columns(rows)).nrows}
show('Rover: array of hashes'){Rover::DataFrame.new(rows).size}
show('Rover: columns'){Rover::DataFrame.new(columns(rows)).size}
show('Polars: array of hashes'){Polars::DataFrame.new(rows).height}
show('Polars: columns'){Polars::DataFrame.new(columns(rows)).height}
show('RedAmber: columns'){RedAmber::DataFrame.new(columns(rows)).size}
show('RedAmber: array of hashes raises'){RedAmber::DataFrame.new(rows).size}
show('Namo holds the array it was given'){source = rows; Namo.new(source).data.equal?(source)}
show('Namo: a change to a source hash shows'){source = rows; held = Namo.new(source); source.first[:close] = 0.0; held.values(:close)}
show('Daru: a change to a source hash does not'){source = rows; held = Daru::DataFrame.new(source); source.first[:close] = 0.0; held[:close].to_a}
show('Rover: a change to a source hash does not'){source = rows; held = Rover::DataFrame.new(source); source.first[:close] = 0.0; held[:close].to_a}
show('Polars: a change to a source hash does not'){source = rows; held = Polars::DataFrame.new(source); source.first[:close] = 0.0; held['close'].to_a}
show('RedAmber: a change to a source column does not'){source = columns(rows); held = RedAmber::DataFrame.new(source); source[:close][0] = 0.0; held[:close].to_a}
show('Rover: names are stored as strings'){rover.keys}
show('Rover: df[:close] finds the column'){rover[:close].to_a}
show('Rover: each_row has string keys'){rover.each_row.first}
show('Rover: sort_by! reading a symbol sorts nothing, silently'){frame = Rover::DataFrame.new(rows); frame.sort_by!{|row| row[:close]}; frame[:close].to_a}
show('Rover: sort_by! reading a string sorts'){frame = Rover::DataFrame.new(rows); frame.sort_by!{|row| row['close']}; frame[:close].to_a}


# Selection

show('Namo: equality'){namo[symbol: 'BHP'].count}
show('Namo: two dimensions'){namo[symbol: 'BHP', date: '2025-01-01'].count}
show('Namo: range'){namo[close: 40.0..45.0].count}
show('Namo: array'){namo[symbol: ['BHP', 'RIO']].count}
show('Namo: proc'){namo[close: ->(v){v > 40}].count}
show('Namo: regex'){namo[symbol: /^B/].count}
show('Namo: mixed in one call'){namo[symbol: /^B/, close: 40.0..45.0, date: ['2025-01-01']].count}
show('Namo: a selection is a Namo'){namo[symbol: 'BHP'].class}
show('Daru: equality'){daru.where(daru[:symbol].eq('BHP')).nrows}
show('Daru: two columns'){daru.where(daru[:symbol].eq('BHP') & daru[:date].eq('2025-01-01')).nrows}
show('Daru: range'){daru.where(daru[:close].mteq(40.0) & daru[:close].lteq(45.0)).nrows}
show('Daru: membership'){daru.where(daru[:symbol].in(['BHP', 'RIO'])).nrows}
show('Daru: predicate'){daru.filter_rows{|row| row[:close] > 40}.nrows}
show('Daru: pattern'){daru.where(daru[:symbol].match(/^B/)).nrows}
show('Rover: equality'){rover[rover[:symbol] == 'BHP'].size}
show('Rover: two columns'){rover[(rover[:symbol] == 'BHP') & (rover[:date] == '2025-01-01')].size}
show('Rover: range'){rover[(rover[:close] >= 40.0) & (rover[:close] <= 45.0)].size}
show('Rover: membership'){rover[rover[:symbol].in?(['BHP', 'RIO'])].size}
show('Rover: predicate'){rover[rover[:close].map{|v| v > 40}].size}
show('Rover: pattern'){rover[rover[:symbol].map{|v| v.match?(/^B/)}].size}
show('Polars: keyword equality'){polars.filter(symbol: 'BHP').height}
show('Polars: two columns'){polars.filter((Polars.col('symbol') == 'BHP') & (Polars.col('date') == '2025-01-01')).height}
show('Polars: range'){polars.filter(Polars.col('close').is_between(40.0, 45.0)).height}
show('Polars: membership'){polars.filter(Polars.col('symbol').is_in(['BHP', 'RIO'])).height}
show('Polars: predicate'){polars.filter(Polars.col('close').map_elements(return_dtype: Polars::Boolean){|v| v > 40}).height}
show('Polars: pattern'){polars.filter(Polars.col('symbol').str.contains('^B')).height}
show('Polars: keyword form with a range'){polars.filter(close: 40.0..45.0).height}
show('Polars: keyword form with an Array'){polars.filter(symbol: ['BHP', 'RIO']).height}
show('RedAmber: equality'){red_amber.filter{symbol == 'BHP'}.size}
show('RedAmber: two columns'){red_amber.filter{(symbol == 'BHP') & (date == '2025-01-01')}.size}
show('RedAmber: range'){red_amber.filter{(close >= 40.0) & (close <= 45.0)}.size}
show('RedAmber: membership'){red_amber.filter{symbol.is_in('BHP', 'RIO')}.size}
show('RedAmber: predicate'){red_amber.filter{close.to_a.map{|v| v > 40}}.size}
show('RedAmber: pattern'){red_amber.filter{symbol.match_substring?(/^B/)}.size}
show('Selections return their own types'){[daru.where(daru[:symbol].eq('BHP')).class, rover[rover[:symbol] == 'BHP'].class, polars.filter(symbol: 'BHP').class, red_amber.filter{symbol == 'BHP'}.class]}


# Projection and contraction

show('Namo: projection'){namo[:symbol, :close].dimensions}
show('Namo: contraction'){namo[-:date].dimensions}
show('Namo: contraction by a template'){(namo / Namo.new([{symbol: 'BHP'}])).dimensions}
show('Daru: one column'){daru[:symbol].class}
show('Daru: two columns'){daru[:symbol, :close].class}
show('Rover: one column'){rover[:symbol].class}
show('Rover: two columns'){rover[[:symbol, :close]].class}
show('Rover: except'){rover.except(:date).keys}
show('Polars: one column'){polars['symbol'].class}
show('Polars: select'){polars.select('symbol', 'close').columns}
show('Polars: drop'){polars.drop('date').columns}
show('RedAmber: one column'){red_amber[:symbol].class}
show('RedAmber: pick'){red_amber.pick(:symbol, :close).keys}
show('RedAmber: drop'){red_amber.drop(:date).keys}


# Composition

sectors = Namo.new(sector_rows)
daru_sectors = Daru::DataFrame.new(sector_rows)
rover_sectors = Rover::DataFrame.new(sector_rows)
polars_sectors = Polars::DataFrame.new(sector_rows)
red_amber_sectors = RedAmber::DataFrame.new(columns(sector_rows))
quarters = Polars::DataFrame.new([{symbol: 'BHP', quarter_end: '2024-12-31', eps: 2.9}, {symbol: 'RIO', quarter_end: '2024-12-31', eps: 8.8}])

show('Namo: *'){(namo * sectors).dimensions}
show('Daru: join'){daru.join(daru_sectors, on: [:symbol], how: :inner).nrows}
show('Daru: join without on'){daru.join(daru_sectors, how: :inner).nrows}
show('Rover: inner_join, no key'){rover.inner_join(rover_sectors).keys}
show('Rover: inner_join'){rover.inner_join(rover_sectors, on: :symbol).size}
show('Rover: left_join'){rover.left_join(rover_sectors, on: :symbol).size}
show('Polars: join'){polars.join(polars_sectors, on: 'symbol', how: 'inner').height}
show('Polars: join without on'){polars.join(polars_sectors).height}
show('Polars: join_asof'){polars.sort('date').join_asof(quarters.sort('quarter_end'), left_on: 'date', right_on: 'quarter_end', by: 'symbol').columns}
show('Polars: join_where'){polars.respond_to?(:join_where)}
show('Polars: semi join'){polars.join(polars_sectors.head(1), on: 'symbol', how: 'semi').height}
show('RedAmber: join, no key'){red_amber.join(red_amber_sectors).keys}
show('RedAmber: join'){red_amber.join(red_amber_sectors, :symbol).size}


# Formulae and computed columns

show('Namo: a formula'){frame = Namo.new(rows); frame[:pe] = proc{|row| row[:close] / row[:eps]}; frame.values(:pe)}
show('Namo: a two-arity window'){
  frame = Namo.new(rows)
  frame[:sma] = ->(row, namo){
    closes = namo[symbol: row[:symbol], date: ..row[:date]].values(:close).last(20)
    closes.sum / closes.length
  }
  frame.values(:sma)
}
show('Namo: a formula follows its data'){source = rows; frame = Namo.new(source); frame[:pe] = proc{|row| row[:close] / row[:eps]}; source.first[:close] = 30.0; frame.values(:pe).first}
show('Namo: a forward reference'){frame = Namo.new(rows); frame[:double_pe] = proc{|row| row[:pe] * 2}; frame[:pe] = proc{|row| row[:close] / row[:eps]}; frame.values(:double_pe).first}
show('Namo: bare names are not shipped'){frame = Namo.new(rows); frame[:ey] = proc{eps / close}; frame.values(:ey)}
show('Daru: a column'){frame = Daru::DataFrame.new(rows); frame[:pe] = frame[:close] / frame[:eps]; frame[:pe].to_a}
show('Daru: rolling_mean'){daru[:close].rolling_mean(2).to_a}
show('Daru: stored, not live'){frame = Daru::DataFrame.new(rows); frame[:pe] = frame[:close] / frame[:eps]; frame[:close] = Daru::Vector.new([30.0, 118.3, 20.0, 43.1]); frame[:pe].to_a.first}
show('Rover: a column'){frame = Rover::DataFrame.new(rows); frame[:pe] = frame[:close] / frame[:eps]; frame[:pe].to_a}
show('Rover: stored, not live'){frame = Rover::DataFrame.new(rows); frame[:pe] = frame[:close] / frame[:eps]; frame[:close] = [30.0, 118.3, 20.0, 43.1]; frame[:pe].to_a.first}
show('Rover: rolling methods'){Rover::Vector.instance_methods.grep(/roll|window/)}
show('Polars: with_columns'){polars.with_columns((Polars.col('close') / Polars.col('eps')).alias('pe'), Polars.col('close').rolling_mean(2).alias('sma')).columns}
show('Polars: stored, not live'){frame = polars.with_columns((Polars.col('close') / Polars.col('eps')).alias('pe')); frame = frame.with_columns(Polars.lit(30.0).alias('close')); frame['pe'].to_a.first}
show('RedAmber: assign'){red_amber.assign(:pe){close / eps}[:pe].to_a}
show('RedAmber: stored, not live'){frame = red_amber.assign(:pe){close / eps}; frame = frame.assign(:close){[30.0, 118.3, 20.0, 43.1]}; frame[:pe].to_a.first}
show('RedAmber: window methods'){RedAmber::Vector.instance_methods.grep(/roll|window|cum|shift/).sort}


# Type handling

show('Namo: mixed values'){Namo.new(mixed[:a].map{|a| {a: a}})[a: ->(v){v.is_a?(String)}].count}
show('Daru: mixed values'){Daru::DataFrame.new(mixed)[:a].to_a}
show('Rover: mixed values'){Rover::DataFrame.new(mixed)[:a].type}
show('Polars: mixed values'){Polars::DataFrame.new(mixed)}
show('RedAmber: mixed values'){RedAmber::DataFrame.new(mixed)}


# Set operations

show('Namo: & | - ^'){[(namo & namo[symbol: 'BHP']).count, (namo | namo).count, (namo - namo[symbol: 'BHP']).count, (namo ^ namo[symbol: 'BHP']).count]}
show('Namo: < <= > >= =='){[namo[symbol: 'BHP'] < namo, namo <= namo, namo > namo[symbol: 'BHP'], namo >= namo, namo == Namo.new(rows)]}
show('Namo: no <=> of its own'){[Namo.instance_method(:<=>).owner, namo[symbol: 'BHP'] <=> namo]}
show('Daru: union'){Daru::DataFrame.new(rows).union(Daru::DataFrame.new(rows)).nrows}
show('Daru: concat'){Daru::DataFrame.new(rows).concat(Daru::DataFrame.new(rows)).nrows}
show('Rover: +'){(Rover::DataFrame.new(rows) + Rover::DataFrame.new(rows)).size}
show('Rover: concat'){Rover::DataFrame.new(rows).concat(Rover::DataFrame.new(rows)).size}
show('Rover: concat changes its receiver, + does not'){frame = Rover::DataFrame.new(rows); frame + Rover::DataFrame.new(rows); sum = frame.size; frame.concat(Rover::DataFrame.new(rows)); [sum, frame.size]}
show('Rover: =='){Rover::DataFrame.new(rows) == Rover::DataFrame.new(rows)}
show('Polars: concat'){Polars.concat([polars, polars]).height}
show('Polars: anti join'){polars.join(polars_sectors, on: 'symbol', how: 'anti').height}
show('Polars: equals'){polars.equals(Polars::DataFrame.new(rows))}
show('Polars: < compares elements, not sets'){closes = polars.select('close'); (closes < closes)['close'].to_a}
show('RedAmber: union'){red_amber.union(red_amber).size}
show('RedAmber: intersect'){red_amber.intersect(red_amber.filter{symbol == 'BHP'}).size}
show('RedAmber: difference'){red_amber.difference(red_amber.filter{symbol == 'BHP'}).size}
show('RedAmber: concatenate'){red_amber.concatenate(red_amber).size}
show('RedAmber: =='){red_amber == RedAmber::DataFrame.new(columns(rows))}
show('Symmetric difference and subset tests elsewhere'){
  names = /symmetric|subset|superset|xor|\A\^\z|\A<=?\z|\A>=?\z/
  [Daru::DataFrame, Rover::DataFrame, Polars::DataFrame, RedAmber::DataFrame].to_h{|klass| [klass.name, klass.public_instance_methods.grep(names)]}
}


# Enumerable

show('Namo includes Enumerable'){Namo.ancestors.include?(Enumerable)}
show('Namo: subset methods return Namos'){[namo.select{|row| row[:close] > 40}, namo.reject{|row| row[:close] > 40}, namo.sort_by{|row| row[:close]}, namo.first(2), namo.last(2), namo.take(2), namo.drop(2), namo.take_while{|row| row[:close] < 100}, namo.drop_while{|row| row[:close] < 100}, namo.uniq{|row| row[:symbol]}].map(&:class).uniq}
show('Namo: partition returns Namos'){namo.partition{|row| row[:close] > 40}.map(&:class)}
show('Namo: group_by(:symbol)'){namo.group_by(:symbol).class}
show('Namo: group_by with a block raises'){namo.group_by{|row| row[:symbol]}}
show('The others include Enumerable'){[Daru::DataFrame, Rover::DataFrame, Polars::DataFrame, RedAmber::DataFrame].map{|klass| klass.ancestors.include?(Enumerable)}}
show('Daru: each_row'){daru.each_row.first.class}
show('Rover: each_row'){rover.each_row.first}
show('Polars: iter_rows'){polars.iter_rows(named: true).first}
show('RedAmber: each_row'){red_amber.each_row.first}


# Interactive exploration

show('Namo: dimensions'){namo.dimensions}
show('Namo: coordinates(:symbol)'){namo.coordinates(:symbol)}
show('Namo: values(:close)'){namo.values(:close)}
show('Polars: columns, unique, to_a'){[polars.columns, polars['symbol'].unique.to_a, polars['close'].to_a]}
show('Rover: keys, uniq, to_a'){[rover.keys, rover[:symbol].uniq.to_a, rover[:close].to_a]}
show('Namo: inspect'){Namo.new(rows * 4).inspect}
show('Daru: inspect'){daru.inspect}
show('Rover: inspect'){rover.inspect}
show('Polars: inspect'){polars.inspect}
show('RedAmber: inspect'){red_amber.inspect}


# Parallelism and concurrency

show('Namo: a shareable Namo read in a Ractor'){
  snapshot = Ractor.make_shareable(Namo.new(rows))
  Ractor.new(snapshot){|data| data[symbol: 'BHP'].values(:close)}.value
}
show('Namo: an ordinary formula cannot be made shareable'){frame = Namo.new(rows); frame[:pe] = proc{|row| row[:close] / row[:eps]}; Ractor.make_shareable(frame)}
show('Namo: a shareable_proc formula, in a Ractor'){
  frame = Namo.new(rows)
  frame[:pe] = Ractor.shareable_proc{|row| row[:close] / row[:eps]}
  snapshot = Ractor.make_shareable(frame)
  Ractor.new(snapshot){|data| data[pe: 14.0..].values(:symbol)}.value
}
show('Namo: values on a frozen Namo'){Namo.new(rows).freeze.values(:close)}
show('Namo: to_a on a frozen Namo'){Namo.new(rows).freeze.to_a}
show('Namo: values on a shareable Namo itself, in a Ractor'){Ractor.new(Ractor.make_shareable(Namo.new(rows))){|data| data.values(:close)}.value}
show('Namo: []= on a frozen Namo'){frame = Namo.new(rows).freeze; frame[:flag] = true; frame.data.first}
show('Polars: cannot be made shareable'){Ractor.make_shareable(Polars::DataFrame.new(rows))}
show('Rover: an object column cannot be made shareable'){Ractor.make_shareable(Rover::DataFrame.new(rows))}
show('Rover: numbers only, read in a Ractor'){Ractor.new(Ractor.make_shareable(Rover::DataFrame.new(close: [42.5, 118.3]))){|data| data[:close].to_a}.value}
show('Rover: numbers only, selected from in a Ractor'){Ractor.new(Ractor.make_shareable(Rover::DataFrame.new(close: [42.5, 118.3]))){|data| data[data[:close] > 50][:close].to_a}.value}
show('Daru: read in a Ractor'){Ractor.new(Ractor.make_shareable(Daru::DataFrame.new(rows))){|data| data[:close].to_a}.value}
show('Daru: selected from in a Ractor'){Ractor.new(Ractor.make_shareable(Daru::DataFrame.new(rows))){|data| data.where(data[:close].mt(50))[:close].to_a}.value}
show('RedAmber: read in a Ractor'){Ractor.new(Ractor.make_shareable(RedAmber::DataFrame.new(columns(rows)))){|data| data[:close].to_a}.value}
show('Namo: built and selected from inside a Ractor'){Ractor.new{Namo.new([{close: 42.5}, {close: 118.3}])[close: 50..].count}.value}
show('Daru: built and selected from inside a Ractor'){Ractor.new{frame = Daru::DataFrame.new(close: [42.5, 118.3]); frame.where(frame[:close].mt(50)).nrows}.value}
show('Rover: built and selected from inside a Ractor'){Ractor.new{frame = Rover::DataFrame.new(close: [42.5, 118.3]); frame[frame[:close] > 50].size}.value}
show('Polars: built and filtered inside a Ractor'){Ractor.new{Polars::DataFrame.new([{close: 42.5}, {close: 118.3}]).filter(Polars.col('close') > 50).height}.value}
show('RedAmber: built and read inside a Ractor'){Ractor.new{RedAmber::DataFrame.new(close: [42.5, 118.3])[:close].to_a}.value}


# Dependencies

show('Runtime dependencies'){
  %w{namo daru rover-df polars-df red_amber}.to_h do |name|
    spec = Gem.loaded_specs[name]
    [name, spec ? spec.runtime_dependencies.map(&:to_s) : 'loaded from lib/, none in its gemspec']
  end
}


# Where they sit

show('Polars: built from a Namo\'s to_h'){Polars::DataFrame.new(namo.to_h)['close'].to_a}
show('Rover: built from a Namo\'s to_h'){Rover::DataFrame.new(namo.to_h)[:close].to_a}
show('RedAmber: built from a Namo\'s to_h'){RedAmber::DataFrame.new(namo.to_h)[:close].to_a}
