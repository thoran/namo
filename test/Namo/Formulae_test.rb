require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../../lib/namo'

describe Namo::Formulae do
  let(:revenue) do
    proc{|r| r[:price] * r[:quantity]}
  end

  let(:cost) do
    proc{|r| r[:quantity] * 4.0}
  end

  let(:formulae) do
    Namo::Formulae.new({revenue: revenue})
  end

  describe "#[]" do
    it "returns the callable stored under a name" do
      _(formulae[:revenue]).must_be_same_as revenue
    end

    it "returns nil for an absent name" do
      _(formulae[:missing]).must_be_nil
    end
  end

  describe "#derive" do
    let(:row) do
      {price: 10.0, quantity: 100}
    end

    it "resolves a row-only formula to its value" do
      _(formulae.derive(:revenue, row, nil)).must_equal 1000.0
    end

    it "resolves a collection-scoped formula with the namo context" do
      namo = Object.new
      formulae[:context] = ->(r, n){n}
      _(formulae.derive(:context, row, namo)).must_be_same_as namo
    end

    it "raises ArgumentError naming the formula when a collection-scoped formula has no namo context" do
      formulae[:context] = ->(r, n){n}
      error = _(proc{formulae.derive(:context, row, nil)}).must_raise ArgumentError
      _(error.message).must_match(/context/)
    end

    it "resolves a parameterised formula with arguments" do
      formulae[:scaled] = ->(r, n, factor){r[:price] * factor}
      _(formulae.derive(:scaled, row, Object.new, 3)).must_equal 30.0
    end
  end

  describe "#required_parameter_count" do
    it "counts a row-only formula" do
      _(formulae.required_parameter_count(:revenue)).must_equal 1
    end

    it "counts a collection-scoped formula" do
      formulae[:context] = ->(r, n){n}
      _(formulae.required_parameter_count(:context)).must_equal 2
    end

    it "counts a parameterised formula" do
      formulae[:scaled] = ->(r, n, factor){r[:price] * factor}
      _(formulae.required_parameter_count(:scaled)).must_equal 3
    end

    it "excludes the splat when counting a variadic formula" do
      formulae[:variadic] = ->(r, n, *rest){rest}
      _(formulae.required_parameter_count(:variadic)).must_equal 2
    end
  end

  describe "#[]=" do
    it "stores a callable under a name" do
      formulae[:cost] = cost
      _(formulae[:cost]).must_be_same_as cost
    end
  end

  describe "#keys" do
    it "returns the stored names" do
      _(formulae.keys).must_equal [:revenue]
    end
  end

  describe "#key?" do
    it "is true for a stored name" do
      _(formulae.key?(:revenue)).must_equal true
    end

    it "is false for an absent name" do
      _(formulae.key?(:missing)).must_equal false
    end
  end

  describe "#empty?" do
    it "is true with no formulae" do
      _(Namo::Formulae.new).must_be_empty
    end

    it "is false with formulae" do
      _(formulae.empty?).must_equal false
    end
  end

  describe "#each" do
    it "yields name/callable pairs" do
      yielded = {}
      formulae.each{|name, callable| yielded[name] = callable}
      _(yielded).must_equal({revenue: revenue})
    end

    it "returns an enumerator with no block" do
      _(formulae.each).must_be_kind_of Enumerator
    end
  end

  describe "#delete" do
    it "removes a name" do
      formulae.delete(:revenue)
      _(formulae.key?(:revenue)).must_equal false
    end
  end

  describe "#merge" do
    it "returns a Formulae combining both sets" do
      merged = formulae.merge(Namo::Formulae.new({cost: cost}))
      _(merged).must_be_kind_of Namo::Formulae
      _(merged.keys.sort).must_equal [:cost, :revenue]
    end

    it "lets the argument win on a name conflict" do
      other = proc{|r| 0}
      merged = formulae.merge(Namo::Formulae.new({revenue: other}))
      _(merged[:revenue]).must_be_same_as other
    end

    it "does not mutate the receiver" do
      formulae.merge(Namo::Formulae.new({cost: cost}))
      _(formulae.keys).must_equal [:revenue]
    end
  end

  describe "#reject" do
    it "returns a Formulae without the rejected names" do
      formulae[:cost] = cost
      rejected = formulae.reject{|name, _| name == :cost}
      _(rejected).must_be_kind_of Namo::Formulae
      _(rejected.keys).must_equal [:revenue]
    end
  end

  describe "#dup" do
    it "returns an independent Formulae" do
      copy = formulae.dup
      copy[:cost] = cost
      _(formulae.key?(:cost)).must_equal false
    end
  end

  describe "#to_h" do
    it "returns a copy, not the live store" do
      hash = formulae.to_h
      hash[:cost] = cost
      _(formulae.key?(:cost)).must_equal false
    end
  end

  describe "Enumerable" do
    it "supports map over name/callable pairs" do
      _(formulae.map{|name, _| name}).must_equal [:revenue]
    end

    it "supports select returning name/callable pairs" do
      formulae[:cost] = cost
      _(formulae.select{|name, _| name == :cost}).must_equal [[:cost, cost]]
    end
  end

  describe "value semantics" do
    it "is == when names match, regardless of proc objects" do
      _(Namo::Formulae.new({revenue: revenue})).must_equal Namo::Formulae.new({revenue: proc{|r| 0}})
    end

    it "is not == when names differ" do
      _(formulae).wont_equal Namo::Formulae.new({cost: cost})
    end

    it "is not == to a bare Hash" do
      _(formulae).wont_equal({revenue: revenue})
    end

    it "is eql? on matching names with differing procs" do
      _(Namo::Formulae.new({revenue: revenue}).eql?(Namo::Formulae.new({revenue: proc{|r| 0}}))).must_equal true
    end

    it "hashes equal on matching names with differing procs" do
      _(Namo::Formulae.new({revenue: revenue}).hash).must_equal Namo::Formulae.new({revenue: proc{|r| 0}}).hash
    end
  end

  describe "constructor" do
    it "defaults to an empty store" do
      _(Namo::Formulae.new.keys).must_equal []
    end
  end
end
