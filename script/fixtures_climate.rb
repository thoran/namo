# script/fixtures_climate.rb
# FixturesClimate

# 20260824
# 0.0.0

# The alternative fixture set, in the shape the RSAA26 deck uses: stations,
# months, a measured temperature against its historical mean, and rainfall.
# Same structure as the default set — two labels, two measures, one derived
# dimension — so every section reads without alteration.
#
# The numbers are chosen so the beats which depend on them still work: the range
# selection takes two rows, the two reducers disagree, the per-member extremum
# picks a different month for each station, and the live mutation visibly moves.

module FixturesClimate
  module_function

  def sales
    "[
    {station: 'Melbourne', month: '2025-01', temp: 26.4, mean_temp: 25.9, rainfall: 48.2},
    {station: 'Melbourne', month: '2025-02', temp: 25.6, mean_temp: 24.1, rainfall: 52.1},
    {station: 'Perth', month: '2025-01', temp: 32.0, mean_temp: 30.0, rainfall: 8.4},
    {station: 'Perth', month: '2025-02', temp: 29.5, mean_temp: 30.0, rainfall: 12.0}]"
  end

  def revenue
    'proc{|row| (row[:temp] - row[:mean_temp]).round(1)}'
  end

  def symbols
    "[{station: 'Melbourne'}, {station: 'Perth'}]"
  end

  def quarters
    "[{month: '2025-01'}, {month: '2025-02'}]"
  end
end
