# namo_test.rb

# 20260314
# 0.0.0

require 'minitest/autorun'
require_relative '../lib/namo'

describe Namo do
  let(:sample_data) do
    [
      {date: '2025-01-01', symbol: 'BHP', close: 42.5},
      {date: '2025-01-01', symbol: 'RIO', close: 118.3},
      {date: '2025-01-02', symbol: 'BHP', close: 43.1},
      {date: '2025-01-02', symbol: 'RIO', close: 117.8}
    ]
  end

  let(:namo){ Namo.new(sample_data) }

  describe '#dimensions' do
    it 'infers dimensions from hash keys' do
      _(namo.dimensions).must_equal [:date, :symbol, :close]
    end
  end

  describe '#coordinates' do
    it 'extracts unique values per dimension' do
      _(namo.coordinates[:date]).must_equal ['2025-01-01', '2025-01-02']
      _(namo.coordinates[:symbol]).must_equal ['BHP', 'RIO']
      _(namo.coordinates[:close]).must_equal [42.5, 118.3, 43.1, 117.8]
    end
  end

  describe '#[]' do
    it 'selects by single value' do
      result = namo[symbol: 'BHP']
      _(result.coordinates[:date]).must_equal ['2025-01-01', '2025-01-02']
      _(result.coordinates[:symbol]).must_equal ['BHP']
      _(result.coordinates[:close]).must_equal [42.5, 43.1]
    end

    it 'selects by multiple dimensions' do
      result = namo[date: '2025-01-01', symbol: 'BHP']
      _(result.coordinates[:date]).must_equal ['2025-01-01']
      _(result.coordinates[:symbol]).must_equal ['BHP']
      _(result.coordinates[:close]).must_equal [42.5]
    end

    it 'selects by range' do
      result = namo[close: 42.0..43.0]
      _(result.coordinates[:close]).must_equal [42.5]
    end

    it 'selects by array of values' do
      result = namo[symbol: ['BHP', 'RIO']]
      _(result.coordinates[:symbol]).must_equal ['BHP', 'RIO']
    end

    it 'returns a Namo' do
      result = namo[symbol: 'BHP']
      _(result).must_be_kind_of Namo
    end

    it 'returns all data when no selections given' do
      result = namo[]
      _(result.coordinates).must_equal namo.coordinates
    end
  end
end
