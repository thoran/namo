#!/usr/bin/env ruby
# ruby_by_hand

# 20260825
# 0.0.0

require 'sqlite3'
require 'monotonic.rb'

# The same computation without Namo, to separate what Ruby costs from what Namo
# costs.  ROADMAP.md quotes the fastest of these three as "Ruby, the algorithm by
# hand" — the figure Namo's compute phase should be read against, since the gap
# between them is the library and the gap to NumPy is the language.
#
# Only the compute phase is timed here; the query and the mapping into hashes are
# the same code as namo.rb's and are measured there.

DATABASE = ENV.fetch('MARKET_DATA_DB', '~/data/market_data.db')
RUNS = 6

def median(numbers)
  sorted = numbers.sort
  sorted[sorted.length / 2]
end

def bench(label)
  timings = RUNS.times.map do
    count = nil
    elapsed = Monotonic::Timer.time{count = yield}
    [elapsed.nanoseconds / 1e6, count]
  end
  puts format('  %-28s median %5.0f ms   -> %d', label, median(timings.map(&:first)), timings.first.last)
end

def data
  @data ||= begin
    db = SQLite3::Database.new(File.expand_path(DATABASE))
    rows = db.execute(
      'SELECT security, date, close FROM prices WHERE exchange = ? AND date BETWEEN ? AND ?',
      ['AU', '2025-01-01', '2025-12-31'])
    rows.map{|security, date, close| {security: security, date: date, close: close}}
  end
end

def main
  bench('group_by + min_by/max_by') do
    data.group_by{|row| row[:security]}.count{|_, rows|
      rows.max_by{|row| row[:date]}[:close] > rows.min_by{|row| row[:date]}[:close]}
  end

  bench('sort_by then group_by') do
    sorted = data.sort_by{|row| [row[:security], row[:date]]}
    sorted.group_by{|row| row[:security]}.count{|_, rows| rows.last[:close] > rows.first[:close]}
  end

  bench('one pass, hash of first/last') do
    first = {}
    last = {}
    data.each do |row|
      security = row[:security]
      date = row[:date]
      earliest = first[security]
      first[security] = row if earliest.nil? || date < earliest[:date]
      latest = last[security]
      last[security] = row if latest.nil? || date > latest[:date]
    end
    first.count{|security, earliest| last[security][:close] > earliest[:close]}
  end
end

main
