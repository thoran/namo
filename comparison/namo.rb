#!/usr/bin/env ruby
# namo

# 20260825
# 0.0.0

require 'sqlite3'
require 'monotonic.rb'
require_relative '../lib/namo'

# The Ruby side of the comparison in ROADMAP.md's "Measured, at 0.31.0".
#
# Four phases, and the boundaries are the point: the query is the database driver,
# to_hashes is the shape the library is handed, construct is the library taking it,
# and compute is the work.  numpy_vectorised.py and pandas_grouped.py cut at the same places, so that
# np.array and pd.DataFrame are weighed against PriceData.new rather than hidden in
# whichever phase flatters the side they are on.  An earlier pair of scripts had
# them misaligned, and the figures were wrong in Namo's favour until they were not.
#
# nanoseconds, not the Measurement itself: Monotonic::Measurement's arithmetic
# operators return a rescaled Measurement rather than a number, so dividing before
# formatting reports a figure two to three times too low.

DATABASE = ENV.fetch('MARKET_DATA_DB', '~/data/market_data.db')
EXCHANGE = 'AU'
BEGIN_DATE = '2025-01-01'
END_DATE = '2025-12-31'

class PriceData < Namo
  def summary
    group_by(:security).summary(by: :security) do |security|
      earliest = security.min_by{|row| row[:date]}
      latest = security.max_by{|row| row[:date]}
      {
        first_date: earliest[:date], last_date: latest[:date],
        starting_price: earliest[:close], finishing_price: latest[:close]
      }
    end
  end
end

RUNS = 5

def milliseconds(&block)
  Monotonic::Timer.time(&block).nanoseconds / 1e6
end

def median(numbers)
  sorted = numbers.sort
  sorted[sorted.length / 2]
end

# The whole of the compute phase: the summary, the formula which compares the two
# prices, and the projection which selects on it.  ROADMAP.md's three-phase table
# reports this.
def compute(namo)
  summary = namo.summary
  summary[:higher] = proc{|row| row[:finishing_price] > row[:starting_price]}
  summary[:security, :higher, higher: true]
end

def main
  db = SQLite3::Database.new(File.expand_path(DATABASE))
  rows = nil
  price_data = nil
  namo = nil
  result = nil

  query = milliseconds do
    rows = db.execute(
      'SELECT security, date, close FROM prices WHERE exchange = ? AND date BETWEEN ? AND ?',
      [EXCHANGE, BEGIN_DATE, END_DATE])
  end
  to_hashes = milliseconds{price_data = rows.map{|security, date, close| {security: security, date: date, close: close}}}
  construct = milliseconds{namo = PriceData.new(price_data)}
  # Medians, as the published figures are: the query moves by a factor of four
  # between cold and warm, and compute by a fifth run to run.  summary_only is
  # reported beside compute because ROADMAP.md's allocation and pandas tables quote
  # the summary alone where its three-phase table quotes the whole phase.
  compute = median(RUNS.times.map{milliseconds{result = compute(namo)}})
  summary_only = median(RUNS.times.map{milliseconds{namo.summary}})

  puts format('query=%.0fms to_hashes=%.0fms construct=%.0fms compute=%.0fms summary_only=%.0fms rows=%d',
    query, to_hashes, construct, compute, summary_only, result.count)
  $stderr.puts result.values(:security).sort.join("\n")
end

main
