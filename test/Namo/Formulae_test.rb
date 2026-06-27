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

  describe "formulary tier" do
    let(:delta) do
      Module.new do
        include Namo::Formulary
        def signed_volume(row); row[:buys] - row[:sells]; end
        def echo_namo(row, namo); namo; end
        def scaled(row, namo, factor); row[:buys] * factor; end
        def windowed(row, namo, *rest); rest; end
        private
        def helper(row); row[:buys]; end
      end
    end

    let(:untagged) do
      Module.new do
        def signed_volume(row); 0; end
      end
    end

    let(:attached) do
      Namo::Formulae.new.attach(delta)
    end

    describe "#attach" do
      it "returns self" do
        formulae = Namo::Formulae.new
        _(formulae.attach(delta)).must_be_same_as formulae
      end

      it "raises ArgumentError for a module not tagged Namo::Formulary" do
        _(proc{Namo::Formulae.new.attach(untagged)}).must_raise ArgumentError
      end

      it "copies the formulary's public methods into the callable store" do
        _(attached.keys.sort).must_equal [:echo_namo, :scaled, :signed_volume, :windowed]
      end

      it "excludes a private helper" do
        _(attached.keys).wont_include :helper
      end

      it "binds every attached formulary to a single shared host" do
        other = Module.new do
          include Namo::Formulary
          def momentum(row); row[:buys]; end
        end
        formulae = Namo::Formulae.new.attach(delta).attach(other)
        _(formulae[:signed_volume].receiver).must_be_same_as formulae[:momentum].receiver
      end
    end

    describe "#<<" do
      it "attaches a formulary, the same as #attach" do
        formulae = Namo::Formulae.new
        formulae << delta
        _(formulae.keys).must_include :signed_volume
      end

      it "returns self for chaining" do
        formulae = Namo::Formulae.new
        _(formulae << delta).must_be_same_as formulae
      end
    end

    describe "#key?" do
      it "is true for a formulary method name" do
        _(attached.key?(:signed_volume)).must_equal true
      end

      it "is false for a private helper" do
        _(attached.key?(:helper)).must_equal false
      end

      it "is false for an absent name" do
        _(attached.key?(:missing)).must_equal false
      end
    end

    describe "#required_parameter_count" do
      it "counts a row-scoped formulary method" do
        _(attached.required_parameter_count(:signed_volume)).must_equal 1
      end

      it "counts a two-arity formulary method" do
        _(attached.required_parameter_count(:echo_namo)).must_equal 2
      end

      it "counts a parameterised formulary method" do
        _(attached.required_parameter_count(:scaled)).must_equal 3
      end

      it "excludes the splat for a variadic formulary method" do
        _(attached.required_parameter_count(:windowed)).must_equal 2
      end
    end

    describe "#derive" do
      it "resolves a row-scoped formulary method to its value" do
        _(attached.derive(:signed_volume, {buys: 60, sells: 40}, nil)).must_equal 20
      end

      it "resolves a two-arity formulary method with the namo context" do
        namo = Object.new
        _(attached.derive(:echo_namo, {buys: 60, sells: 40}, namo)).must_be_same_as namo
      end

      it "raises when a two-arity formulary method has no namo context" do
        error = _(proc{attached.derive(:echo_namo, {buys: 60, sells: 40}, nil)}).must_raise ArgumentError
        _(error.message).must_match(/echo_namo/)
      end

      it "resolves the most-recently attached formulary on a name collision" do
        alt = Module.new do
          include Namo::Formulary
          def signed_volume(row); 999; end
        end
        formulae = Namo::Formulae.new.attach(delta).attach(alt)
        _(formulae.derive(:signed_volume, {buys: 60, sells: 40}, nil)).must_equal 999
      end
    end

    describe "carry-through" do
      it "preserves attached formularies through #dup" do
        _(attached.dup.keys).must_include :signed_volume
      end

      it "preserves attached formularies through #reject" do
        _(attached.reject{|_name, _| false}.keys).must_include :signed_volume
      end

      it "carries both sides' formularies through #merge" do
        other_delta = Module.new do
          include Namo::Formulary
          def momentum(row); row[:buys]; end
        end
        merged = attached.merge(Namo::Formulae.new.attach(other_delta))
        _(merged.keys).must_include :momentum
        _(merged.keys).must_include :signed_volume
      end
    end
  end
end
