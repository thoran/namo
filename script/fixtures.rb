# script/fixtures.rb
# Fixtures

# 20260823
# 0.0.0

# The data script/demo shows and script/console hands you, in one place so the
# two cannot drift.  They are held as source text rather than as objects: the
# demo prints these lines before evaluating them, so what the audience reads and
# what runs are necessarily the same string, and the console evaluates the same
# string to arrive at the same names.
#
# Two stations over two months, a measured temperature against its historical
# mean, and rainfall.  The numbers are chosen so that the beats which turn upon
# them still work: the anomalies are exact binary fractions and so sum without
# drift, the two reducers disagree, and each station peaks in a different month.

module Fixtures
  module_function

  def readings
    "[
    {station: 'Melbourne', month: '2025-01', temp: 26.4, mean_temp: 25.9, rainfall: 48.2},
    {station: 'Melbourne', month: '2025-02', temp: 25.6, mean_temp: 24.1, rainfall: 52.1},
    {station: 'Perth', month: '2025-01', temp: 32.0, mean_temp: 30.0, rainfall: 8.4},
    {station: 'Perth', month: '2025-02', temp: 29.5, mean_temp: 30.0, rainfall: 12.0}]"
  end

  def anomaly
    'proc{|row| (row[:temp] - row[:mean_temp]).round(1)}'
  end

  def stations
    "[{station: 'Melbourne'}, {station: 'Perth'}]"
  end

  def months
    "[{month: '2025-01'}, {month: '2025-02'}]"
  end
end
