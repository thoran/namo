require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../lib/namo'

describe Symbol do
  describe "#-@" do
    it "returns a NegatedDimension" do
      _(-:price).must_be_kind_of Namo::NegatedDimension
    end

    it "preserves the symbol name" do
      _((-:price).name).must_equal :price
    end
  end
end
