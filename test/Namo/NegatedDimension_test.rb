require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../../lib/namo'

describe Namo::NegatedDimension do
  describe "#name" do
    it "returns the original symbol" do
      nd = Namo::NegatedDimension.new(:price)
      _(nd.name).must_equal :price
    end
  end
end
