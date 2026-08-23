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

  # Two specimens measured on two axes, for the uncertainty section: the areas
  # come out equal and the confidences do not, which is the whole of the point.
  def specimens
    "[
    {specimen: 'A', length: 50.0, width: 20.0},
    {specimen: 'B', length: 20.0, width: 50.0}]"
  end

  # Sensor calibrations, for the as-of match: each reading takes the most recent
  # calibration dated on or before it.
  def calibrations
    "[
    {station: 'Melbourne', calibrated: '2024-11-30', offset: 0.2},
    {station: 'Melbourne', calibrated: '2025-01-15', offset: 0.1},
    {station: 'Perth', calibrated: '2024-12-20', offset: -0.1}]"
  end

  # Sensor tolerances, for the conditional product: a sensor may stand in for a
  # reading whose range it covers.
  def tolerances
    "[{sensor: 'coarse', max_range: 30.0}, {sensor: 'fine', max_range: 40.0}]"
  end
end
