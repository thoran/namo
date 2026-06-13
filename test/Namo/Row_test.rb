require 'date'
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

  describe "constructor" do
    it "constructs from the two-argument form (namo defaults nil)" do
      _(Namo::Row.new(row_data, formulae)).must_be_kind_of Namo::Row
    end

    it "accepts a third namo argument" do
      namo = Namo.new([row_data])
      _(Namo::Row.new(row_data, formulae, namo)).must_be_kind_of Namo::Row
    end
  end

  describe "#[] arity dispatch" do
    it "calls an arity-1 formula with the Row only" do
      seen = nil
      formulae[:dim] = ->(r){seen = r; 1}
      row[:dim]
      _(seen).must_be_same_as row
    end

    it "calls an arity-2 formula with the Row and the yielding Namo" do
      namo = Namo.new([row_data])
      row = Namo::Row.new(row_data, formulae, namo)
      seen_row = nil
      seen_namo = nil
      formulae[:dim] = ->(r, n){seen_row = r; seen_namo = n; 1}
      row[:dim]
      _(seen_row).must_be_same_as row
      _(seen_namo.equal?(namo)).must_equal true
    end

    it "takes the one-arity path for an arity-0 proc" do
      formulae[:dim] = proc{42}
      _(row[:dim]).must_equal 42
    end

    it "takes the one-arity path for a negative-arity proc" do
      seen_rest = nil
      formulae[:dim] = proc{|r, *rest| seen_rest = rest; 1}
      row[:dim]
      _(seen_rest).must_equal []
    end

    it "raises ArgumentError naming the formula when an arity-2 formula has no Namo context" do
      formulae[:sma] = ->(r, n){n.count}
      error = _(proc{row[:sma]}).must_raise ArgumentError
      _(error.message).must_match(/sma/)
    end

    it "resolves an arity-1 formula on a Row with no Namo context" do
      formulae[:revenue] = ->(r){r[:price] * r[:quantity]}
      _(row[:revenue]).must_equal 1000.0
    end
  end

  describe "#[] parameterised formulae" do
    let(:namo) do
      Namo.new([row_data])
    end

    let(:contextual_row) do
      Namo::Row.new(row_data, formulae, namo)
    end

    it "calls an arity-3 formula with the Row, the yielding Namo, and one argument" do
      seen = nil
      formulae[:scaled] = ->(r, n, factor){seen = [r, n, factor]; r[:price] * factor}
      _(contextual_row[:scaled, 3]).must_equal 30.0
      _(seen[0]).must_be_same_as contextual_row
      _(seen[1].equal?(namo)).must_equal true
      _(seen[2]).must_equal 3
    end

    it "calls an arity-4 formula with two arguments" do
      formulae[:metric] = ->(r, n, field, factor){r[field] * factor}
      _(contextual_row[:metric, :quantity, 2]).must_equal 200
    end

    it "forwards a trailing splat's arguments past a required one (arity -4)" do
      formulae[:dim] = proc{|r, n, field, *rest| [field, rest]}
      _(contextual_row[:dim, :price]).must_equal [:price, []]
      _(contextual_row[:dim, :price, 1, 2]).must_equal [:price, [1, 2]]
    end

    it "treats a splat directly after namo as collection-scoped taking any number of arguments (arity -3)" do
      formulae[:dim] = proc{|r, n, *rest| rest}
      _(contextual_row[:dim]).must_equal []
      _(contextual_row[:dim, 1, 2, 3]).must_equal [1, 2, 3]
    end

    it "keeps a one-required-parameter proc row-scoped regardless of trailing optionals" do
      seen = :unset
      formulae[:dim] = ->(r, n = :fallback){seen = n; 1}
      contextual_row[:dim]
      _(seen).must_equal :fallback
    end

    it "lets a row-scoped formula call a parameterised formula with arguments" do
      formulae[:metric] = ->(r, n, field, factor){r[field] * factor}
      formulae[:double_quantity] = ->(r){r[:metric, :quantity, 2]}
      _(contextual_row[:double_quantity]).must_equal 200
    end

    it "raises ArgumentError naming the formula when a parameterised formula has no Namo context" do
      formulae[:metric] = ->(r, n, field){r[field]}
      error = _(proc{row[:metric, :price]}).must_raise ArgumentError
      _(error.message).must_match(/metric/)
    end
  end

  describe "#[] argument-count enforcement" do
    let(:namo) do
      Namo.new([row_data])
    end

    let(:contextual_row) do
      Namo::Row.new(row_data, formulae, namo)
    end

    it "raises when a parameterised formula is given too few arguments" do
      formulae[:metric] = ->(r, n, field, period){r[field] * period}
      error = _(proc{contextual_row[:metric, :price]}).must_raise ArgumentError
      _(error.message).must_equal "wrong number of arguments for :metric (given 1, expected 2)"
    end

    it "raises when a fixed-arity parameterised formula is given too many arguments" do
      formulae[:metric] = ->(r, n, field){r[field]}
      error = _(proc{contextual_row[:metric, :price, 20]}).must_raise ArgumentError
      _(error.message).must_equal "wrong number of arguments for :metric (given 2, expected 1)"
    end

    it "raises when a splatted parameterised formula is given fewer than its required arguments" do
      formulae[:metric] = proc{|r, n, field, *rest| r[field]}
      error = _(proc{contextual_row[:metric]}).must_raise ArgumentError
      _(error.message).must_equal "wrong number of arguments for :metric (given 0, expected 1+)"
    end

    it "raises when arguments are given for a data dimension" do
      error = _(proc{row[:price, 20]}).must_raise ArgumentError
      _(error.message).must_equal "wrong number of arguments for :price (given 1, expected 0)"
    end

    it "raises when arguments are given for a row-scoped formula" do
      formulae[:revenue] = proc{|r| r[:price] * r[:quantity]}
      error = _(proc{row[:revenue, 20]}).must_raise ArgumentError
      _(error.message).must_equal "wrong number of arguments for :revenue (given 1, expected 0)"
    end

    it "raises when arguments are given for a two-arity formula" do
      formulae[:row_count] = ->(r, n){n.count}
      error = _(proc{contextual_row[:row_count, 1]}).must_raise ArgumentError
      _(error.message).must_equal "wrong number of arguments for :row_count (given 1, expected 0)"
    end

    it "raises when arguments are given for a missing dimension" do
      error = _(proc{row[:missing, 1]}).must_raise ArgumentError
      _(error.message).must_equal "wrong number of arguments for :missing (given 1, expected 0)"
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

    it "resolves a two-arity derived dimension when the Row carries a Namo" do
      namo = Namo.new([row_data])
      formulae[:row_count] = ->(r, n){n.count}
      row = Namo::Row.new(row_data, formulae, namo)
      _(row.match?(row_count: 1)).must_equal true
      _(row.match?(row_count: 2)).must_equal false
    end

    describe "Proc predicates" do
      it "matches when the proc returns true" do
        _(row.match?(price: ->(v){v < 15.0})).must_equal true
      end

      it "doesn't match when the proc returns false" do
        _(row.match?(price: ->(v){v > 100.0})).must_equal false
      end

      it "doesn't match when the proc returns nil" do
        _(row.match?(price: ->(v){nil})).must_equal false
      end

      it "matches when the proc returns a truthy non-boolean" do
        _(row.match?(price: ->(v){"truthy"})).must_equal true
      end

      it "passes nil to the proc when the dimension is missing" do
        seen = nil
        row.match?(missing: ->(v){seen = v; true})
        _(seen).must_be_nil
      end

      it "lets the proc decide what to do with a nil value" do
        _(row.match?(missing: ->(v){v.nil?})).must_equal true
        _(row.match?(missing: ->(v){!v.nil?})).must_equal false
      end

      it "composes with an exact value on another dimension" do
        _(row.match?(price: ->(v){v < 15.0}, product: 'Widget')).must_equal true
        _(row.match?(price: ->(v){v < 15.0}, product: 'Gadget')).must_equal false
      end

      it "composes with an array on another dimension" do
        _(row.match?(price: ->(v){v < 15.0}, product: ['Widget', 'Gadget'])).must_equal true
        _(row.match?(price: ->(v){v < 15.0}, product: ['Gadget'])).must_equal false
      end

      it "composes with a range on another dimension" do
        _(row.match?(price: ->(v){v < 15.0}, quantity: 50..150)).must_equal true
        _(row.match?(price: ->(v){v < 15.0}, quantity: 200..300)).must_equal false
      end

      it "composes with a regex on another dimension" do
        _(row.match?(price: ->(v){v < 15.0}, product: /^W/)).must_equal true
        _(row.match?(price: ->(v){v < 15.0}, product: /^G/)).must_equal false
      end

      it "composes multiple proc predicates across dimensions" do
        _(row.match?(
          price: ->(v){v < 15.0},
          quantity: ->(v){v >= 100}
        )).must_equal true
        _(row.match?(
          price: ->(v){v < 15.0},
          quantity: ->(v){v >= 200}
        )).must_equal false
      end

      it "carries through to a formula-defined dimension" do
        formulae[:revenue] = proc{|r| r[:price] * r[:quantity]}
        _(row.match?(revenue: ->(v){v == 1000.0})).must_equal true
        _(row.match?(revenue: ->(v){v > 5000.0})).must_equal false
      end
    end

    describe "Regexp predicates" do
      it "matches against a String value" do
        _(row.match?(product: /Widget/)).must_equal true
      end

      it "doesn't match when the regex doesn't apply" do
        _(row.match?(product: /Gadget/)).must_equal false
      end

      it "supports case-insensitive matching" do
        _(row.match?(product: /widget/i)).must_equal true
        _(row.match?(product: /widget/)).must_equal false
      end

      it "supports anchored patterns" do
        _(row.match?(product: /^Wid/)).must_equal true
        _(row.match?(product: /^Gad/)).must_equal false
      end

      it "coerces Integer values via to_s" do
        _(row.match?(quantity: /100/)).must_equal true
        _(row.match?(quantity: /^1/)).must_equal true
        _(row.match?(quantity: /^9/)).must_equal false
      end

      it "coerces Float values via to_s" do
        _(row.match?(price: /^10\./)).must_equal true
        _(row.match?(price: /\.0$/)).must_equal true
        _(row.match?(price: /^99/)).must_equal false
      end

      it "coerces Date values via to_s" do
        row_data[:date] = Date.new(2026, 5, 21)
        _(row.match?(date: /^2026/)).must_equal true
        _(row.match?(date: /-05-/)).must_equal true
        _(row.match?(date: /^2025/)).must_equal false
      end

      it "coerces Symbol values via to_s" do
        row_data[:tag] = :priority
        _(row.match?(tag: /priority/)).must_equal true
        _(row.match?(tag: /^pri/)).must_equal true
        _(row.match?(tag: /xyz/)).must_equal false
      end

      it "coerces nil to an empty string" do
        _(row.match?(missing: //)).must_equal true
        _(row.match?(missing: /./)).must_equal false
      end

      it "composes with an exact value on another dimension" do
        _(row.match?(product: /^W/, quarter: 'Q1')).must_equal true
        _(row.match?(product: /^W/, quarter: 'Q2')).must_equal false
      end

      it "composes with an array on another dimension" do
        _(row.match?(product: /^W/, quarter: ['Q1', 'Q2'])).must_equal true
        _(row.match?(product: /^W/, quarter: ['Q3'])).must_equal false
      end

      it "composes with a range on another dimension" do
        _(row.match?(product: /^W/, price: 5.0..15.0)).must_equal true
        _(row.match?(product: /^W/, price: 20.0..30.0)).must_equal false
      end

      it "composes with a proc on another dimension" do
        _(row.match?(product: /^W/, quantity: ->(v){v >= 100})).must_equal true
        _(row.match?(product: /^W/, quantity: ->(v){v >= 200})).must_equal false
      end

      it "composes multiple regex predicates across dimensions" do
        _(row.match?(product: /^W/, quarter: /^Q/)).must_equal true
        _(row.match?(product: /^W/, quarter: /^X/)).must_equal false
      end

      it "carries through to a formula-defined dimension" do
        formulae[:label] = proc{|r| "#{r[:product]}-#{r[:quarter]}"}
        _(row.match?(label: /Widget-Q1/)).must_equal true
        _(row.match?(label: /Gadget/)).must_equal false
      end
    end
  end

  describe "#to_h" do
    it "returns the underlying row hash" do
      _(row.to_h).must_equal row_data
    end
  end

  describe "#==" do
    it "is true for two Rows with equal @row" do
      a = Namo::Row.new({product: 'Widget', price: 10.0}, {})
      b = Namo::Row.new({product: 'Widget', price: 10.0}, {})
      _(a == b).must_equal true
    end

    it "is false for two Rows with different @row" do
      a = Namo::Row.new({product: 'Widget', price: 10.0}, {})
      b = Namo::Row.new({product: 'Gadget', price: 10.0}, {})
      _(a == b).must_equal false
    end

    it "is false for a non-Row operand" do
      a = Namo::Row.new({product: 'Widget'}, {})
      _(a == {product: 'Widget'}).must_equal false
      _(a == 'Widget').must_equal false
      _(a == nil).must_equal false
    end

    it "ignores formulae" do
      a = Namo::Row.new({price: 10.0, quantity: 100}, {})
      b = Namo::Row.new({price: 10.0, quantity: 100}, {revenue: proc{|r| r[:price] * r[:quantity]}})
      _(a == b).must_equal true
    end
  end

  describe "#eql?" do
    it "is true for two Rows with eql? @row" do
      a = Namo::Row.new({product: 'Widget', price: 10.0}, {})
      b = Namo::Row.new({product: 'Widget', price: 10.0}, {})
      _(a.eql?(b)).must_equal true
    end

    it "is false for a non-Row operand" do
      a = Namo::Row.new({product: 'Widget'}, {})
      _(a.eql?({product: 'Widget'})).must_equal false
      _(a.eql?(nil)).must_equal false
    end

    it "distinguishes numeric types the way Hash#eql? does" do
      a = Namo::Row.new({n: 1}, {})
      b = Namo::Row.new({n: 1.0}, {})
      _(a == b).must_equal true
      _(a.eql?(b)).must_equal false
    end

    it "ignores formulae" do
      a = Namo::Row.new({price: 10.0, quantity: 100}, {})
      b = Namo::Row.new({price: 10.0, quantity: 100}, {revenue: proc{|r| r[:price] * r[:quantity]}})
      _(a.eql?(b)).must_equal true
    end
  end

  describe "#hash" do
    it "is equal for two Rows that are eql?" do
      a = Namo::Row.new({product: 'Widget', price: 10.0}, {})
      b = Namo::Row.new({product: 'Widget', price: 10.0}, {})
      _(a.hash).must_equal b.hash
    end

    it "lets Rows work as Hash keys" do
      a = Namo::Row.new({product: 'Widget'}, {})
      b = Namo::Row.new({product: 'Gadget'}, {})
      lookup = Namo::Row.new({product: 'Widget'}, {})
      h = {a => :x, b => :y}
      _(h[lookup]).must_equal :x
    end

    it "lets Array#uniq dedupe equal Rows" do
      a = Namo::Row.new({product: 'Widget'}, {})
      b = Namo::Row.new({product: 'Gadget'}, {})
      duplicate_of_a = Namo::Row.new({product: 'Widget'}, {})
      _([a, b, duplicate_of_a].uniq.length).must_equal 2
    end
  end
end
