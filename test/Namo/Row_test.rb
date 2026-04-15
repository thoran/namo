require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../../lib/namo'

describe Namo::Row do
  let(:row_data) do
    {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100}
  end

  let(:formulae) do
    {}
  end

  let(:row) do
    Namo::Row.new(row_data, formulae)
  end

  describe "#[]" do
    it "returns raw data by dimension name" do
      _(row[:product]).must_equal 'Widget'
      _(row[:price]).must_equal 10.0
    end

    it "returns nil for missing dimensions" do
      _(row[:missing]).must_be_nil
    end

    it "resolves formulae over raw data" do
      formulae[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(row[:revenue]).must_equal 1000.0
    end

    it "composes formulae" do
      formulae[:revenue] = proc{|r| r[:price] * r[:quantity]}
      formulae[:cost] = proc{|r| r[:quantity] * 4.0}
      formulae[:profit] = proc{|r| r[:revenue] - r[:cost]}
      _(row[:profit]).must_equal 600.0
    end
  end

  describe "#match?" do
    it "matches a single value" do
      _(row.match?(product: 'Widget')).must_equal true
      _(row.match?(product: 'Gadget')).must_equal false
    end

    it "matches an array of values" do
      _(row.match?(product: ['Widget', 'Gadget'])).must_equal true
      _(row.match?(product: ['Gadget'])).must_equal false
    end

    it "matches a range" do
      _(row.match?(price: 5.0..15.0)).must_equal true
      _(row.match?(price: 20.0..30.0)).must_equal false
    end

    it "matches multiple dimensions" do
      _(row.match?(product: 'Widget', quarter: 'Q1')).must_equal true
      _(row.match?(product: 'Widget', quarter: 'Q2')).must_equal false
    end
  end

  describe "#to_h" do
    it "returns the underlying row hash" do
      _(row.to_h).must_equal row_data
    end
  end
end
