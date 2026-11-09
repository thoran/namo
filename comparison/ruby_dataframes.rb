#!/usr/bin/env ruby
# ruby_dataframes

# 20261103
# 0.0.0

require_relative '../lib/namo'

# The figures in RUBY_COMPARISON.md's "Measured" section are this script's output.
# One workload, written idiomatically in each library: select the rows of one
# sector, derive a price-earnings ratio, sort by it, and read the ratios back as a
# Ruby Array.  The data is generated, from a fixed seed, so it runs on a clean
# clone given the libraries; comparison/setup builds them, and
# comparison/.tools/bin/ruby runs it with them.
#
# Two phases.  construct is the library taking the rows as they arrive, an Array of
# Hashes; RedAmber cannot take that shape, so its construct includes turning the
# rows into columns.  compute is the workload.  Every library's ratios are checked
# against plain Ruby's before any timing is printed, so a figure is never reported
# for a different answer.
#
# Process.clock_gettime, medians of five with a warm run first, as script/sizing.

ROW_COUNTS = [2_000, 100_000, 1_000_000]
RUNS = 5
SEED = 20261103
SECTORS = %w{Mining Energy Banks Retail}
SYMBOL_COUNT = 500

LIBRARIES = {
  'plain Ruby' => nil,
  'Namo' => nil,
  'Daru' => 'daru',
  'Rover' => 'rover',
  'Polars' => 'polars-df',
  'RedAmber' => 'red_amber',
}

def usage
  puts "ruby_dataframes - Time one workload in Namo and the other Ruby data libraries."
  puts
  puts "Usage: comparison/.tools/bin/ruby comparison/ruby_dataframes.rb [ROWS ...]"
  puts
  puts "Selects one sector's rows, derives a ratio, sorts by it, and reads the ratios back."
  puts "Reports the median of #{RUNS} runs of each phase at each size, after checking every"
  puts "library's answer against plain Ruby's. A library which will not load is skipped."
  puts "With no arguments, measures #{ROW_COUNTS.join(', ')}."
end

def row_counts
  @row_counts ||= ARGV.empty? ? ROW_COUNTS : ARGV.map{|count| Integer(count.delete('_'))}
end

def validate_args
  return unless ARGV.include?('-h') || ARGV.include?('--help') || row_counts.any?{|count| count < 1}
  usage
  exit
end

def libraries
  @libraries ||= LIBRARIES.select do |label, feature|
    begin
      require feature if feature
      true
    rescue LoadError => e
      $stderr.puts "skipping #{label}: #{e.message}"
      false
    end
  end.keys
end

def versions
  {
    'ruby' => "#{RUBY_VERSION}#{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? ' +YJIT' : ''}",
    'Namo' => Namo::VERSION,
    'Daru' => defined?(Daru::VERSION) && Daru::VERSION,
    'Rover' => defined?(Rover::VERSION) && Rover::VERSION,
    'Polars' => defined?(Polars::VERSION) && Polars::VERSION,
    'RedAmber' => defined?(RedAmber::VERSION) && "#{RedAmber::VERSION} (Arrow #{Arrow::Version::STRING})",
  }.select{|_, version| version}
end

def rows(count)
  random = Random.new(SEED)
  sectors = SYMBOL_COUNT.times.map{|i| SECTORS[i % SECTORS.length]}
  count.times.map do |i|
    symbol = i % SYMBOL_COUNT
    {symbol: format('S%04d', symbol), sector: sectors[symbol], close: (1 + random.rand * 199).round(2), eps: (0.5 + random.rand * 19.5).round(2)}
  end
end

def columns(rows)
  rows.first.keys.to_h{|key| [key, rows.map{|row| row[key]}]}
end

def construct(library, rows)
  case library
  when 'plain Ruby' then rows
  when 'Namo' then Namo.new(rows)
  when 'Daru' then Daru::DataFrame.new(rows)
  when 'Rover' then Rover::DataFrame.new(rows)
  when 'Polars' then Polars::DataFrame.new(rows)
  when 'RedAmber' then RedAmber::DataFrame.new(columns(rows))
  end
end

def compute(library, frame)
  case library
  when 'plain Ruby'
    frame.select{|row| row[:sector] == 'Mining'}.map{|row| row[:close] / row[:eps]}.sort
  when 'Namo'
    mining = frame[sector: 'Mining']
    mining[:pe] = proc{|row| row[:close] / row[:eps]}
    mining.sort_by{|row| row[:pe]}.values(:pe)
  when 'Daru'
    mining = frame.where(frame[:sector].eq('Mining'))
    mining[:pe] = mining[:close] / mining[:eps]
    mining.sort([:pe])[:pe].to_a
  when 'Rover'
    mining = frame[frame[:sector] == 'Mining']
    mining[:pe] = mining[:close] / mining[:eps]
    mining.sort_by{|row| row['pe']}[:pe].to_a
  when 'Polars'
    frame.filter(Polars.col('sector') == 'Mining').with_columns((Polars.col('close') / Polars.col('eps')).alias('pe')).sort('pe')['pe'].to_a
  when 'RedAmber'
    frame.filter{sector == 'Mining'}.assign(:pe){close / eps}.sort(:pe)[:pe].to_a
  end
end

def median(numbers)
  numbers.sort[numbers.length / 2]
end

def milliseconds
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
end

def timings(library, rows)
  frame = construct(library, rows)
  compute(library, frame)
  constructs = RUNS.times.map{milliseconds{construct(library, rows)}}
  computes = RUNS.times.map{milliseconds{compute(library, frame)}}
  [median(constructs), median(computes)]
end

def check(library, rows, expected)
  answer = compute(library, construct(library, rows))
  return if answer == expected
  abort "#{library} disagrees with plain Ruby at #{rows.length} rows: #{answer.length} ratios against #{expected.length}"
end

def report_versions
  puts versions.map{|library, version| "#{library} #{version}"}.join(', ')
end

def report(count)
  data = rows(count)
  expected = compute('plain Ruby', data)
  libraries.each{|library| check(library, data, expected)}
  puts
  puts "#{count} rows, #{expected.length} selected; all #{libraries.length} agree"
  puts format('  %-12s %12s %12s %12s', 'library', 'construct', 'compute', 'total')
  libraries.each do |library|
    construct_ms, compute_ms = timings(library, data)
    puts format('  %-12s %9.1f ms %9.1f ms %9.1f ms', library, construct_ms, compute_ms, construct_ms + compute_ms)
  end
end

def main
  validate_args
  libraries
  report_versions
  row_counts.each{|count| report(count)}
end

main
