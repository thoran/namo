require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../lib/namo'

describe Namo do
  let(:sample_data) do
    [
      {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
      {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
      {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
      {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
    ]
  end

  let(:sales) do
    Namo.new(sample_data)
  end

  describe "empty Namo" do
    it "has empty dimensions" do
      _(Namo.new.dimensions).must_equal []
    end

    it "has empty data_dimensions" do
      _(Namo.new.data_dimensions).must_equal []
    end

    it "exposes formulae even with no data" do
      namo = Namo.new
      namo[:x] = proc{|r| 42}
      _(namo.dimensions).must_equal [:x]
    end
  end

  describe "construction" do
    it "accepts positional data" do
      _(Namo.new([{x: 1}]).data).must_equal [{x: 1}]
    end

    it "accepts positional data with keyword formulae" do
      namo = Namo.new([{x: 1}], formulae: {y: proc{|r| r[:x] * 2}})
      _(namo.data).must_equal [{x: 1}]
      _(namo.values(:y)).must_equal [2]
    end

    it "produces an empty Namo with no arguments" do
      namo = Namo.new
      _(namo.data).must_equal []
      _(namo.formulae).must_equal({})
    end

    it "accepts keyword formulae with no data" do
      namo = Namo.new(formulae: {y: proc{|r| r[:x] * 2}})
      _(namo.data).must_equal []
      _(namo.derived_dimensions).must_equal [:y]
    end

    it "honours an explicit empty positional array over the nil sentinel" do
      _(Namo.new([]).data).must_equal []
    end

    it "accepts data by keyword" do
      _(Namo.new(data: [{x: 1}]).data).must_equal [{x: 1}]
    end

    it "lets positional data win when both positional and keyword data are given" do
      _(Namo.new([{x: 1}], data: [{x: 2}]).data).must_equal [{x: 1}]
    end

    it "survives a round-trip through a set operator" do
      a = Namo.new([{x: 1}])
      b = Namo.new([{x: 2}])
      _((a + b).data).must_equal [{x: 1}, {x: 2}]
    end

    it "survives a round-trip through an Enumerable method" do
      namo = Namo.new([{x: 1}, {x: 2}])
      _(namo.select{|row| row[:x] > 1}.data).must_equal [{x: 2}]
    end
  end

  describe "#name" do
    it "stores a name passed by keyword" do
      _(Namo.new([{x: 1}], name: :foo).name).must_equal :foo
    end

    it "defaults to nil when no name is passed" do
      _(Namo.new([{x: 1}]).name).must_be_nil
    end

    it "is settable post-construction" do
      namo = Namo.new([{x: 1}])
      namo.name = :bar
      _(namo.name).must_equal :bar
    end

    it "is nil on a Namo derived from a set operator" do
      a = Namo.new([{x: 1}], name: :a)
      b = Namo.new([{x: 2}], name: :b)
      _((a + b).name).must_be_nil
    end

    it "is nil on a Namo derived from an Enumerable method" do
      namo = Namo.new([{x: 1}, {x: 2}], name: :original)
      _(namo.select{|row| row[:x] > 1}.name).must_be_nil
    end
  end

  describe "subclass side-effect guard" do
    before do
      @guard_class = Class.new(Namo) do
        def self.fired
          @fired ||= []
        end
        def initialize(positional_data = nil, data: [], formulae: {}, name: nil)
          super
          return unless name
          self.class.fired << name
        end
      end
    end

    it "fires guarded side effects for an explicitly named construction" do
      @guard_class.new(data: [{x: 1}], name: :foo)
      _(@guard_class.fired).must_equal [:foo]
    end

    it "skips guarded side effects for an unnamed construction" do
      @guard_class.new(data: [{x: 1}])
      _(@guard_class.fired).must_equal []
    end

    it "skips guarded side effects for an operator result" do
      a = @guard_class.new(data: [{x: 1}], name: :a)
      b = @guard_class.new(data: [{x: 2}], name: :b)
      @guard_class.fired.clear
      _((a + b).name).must_be_nil
      _(@guard_class.fired).must_equal []
    end
  end

  describe "#dimensions" do
    it "infers dimensions from hash keys" do
      _(sales.dimensions).must_equal [:product, :quarter, :price, :quantity]
    end

    it "includes derived dimensions after storage dimensions" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      sales[:label] = proc{|r| "#{r[:product]}-#{r[:quarter]}"}
      _(sales.dimensions).must_equal [:product, :quarter, :price, :quantity, :revenue, :label]
    end

    it "reflects mutation on the next call" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.dimensions).must_include :revenue
      sales.formulae.delete(:revenue)
      _(sales.dimensions).wont_include :revenue
    end
  end

  describe "#data_dimensions" do
    it "returns only the storage keys" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.data_dimensions).must_equal [:product, :quarter, :price, :quantity]
    end
  end

  describe "#derived_dimensions" do
    it "returns only the formula keys" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.derived_dimensions).must_equal [:revenue]
    end

    it "is empty when no formulae are defined" do
      _(sales.derived_dimensions).must_equal []
    end
  end

  describe "#coordinates" do
    it "with no args returns a Hash of unique values for each dimension" do
      _(sales.coordinates).must_equal ({
        product: ['Widget', 'Gadget'],
        quarter: ['Q1', 'Q2'],
        price: [10.0, 25.0],
        quantity: [100, 150, 40, 60]
      })
    end

    it "0.6.0-style indexing still works" do
      _(sales.coordinates[:product]).must_equal ['Widget', 'Gadget']
      _(sales.coordinates[:quarter]).must_equal ['Q1', 'Q2']
    end

    it "with one arg returns just that column's unique values as an Array" do
      _(sales.coordinates(:product)).must_equal ['Widget', 'Gadget']
    end

    it "with one arg returns [nil] for an unknown dimension (nil values uniqued)" do
      _(sales.coordinates(:missing)).must_equal [nil]
    end

    it "with one arg evaluates a derived dimension" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.coordinates(:revenue)).must_equal [1000.0, 1500.0]
    end

    it "with multiple args returns a subset Hash" do
      _(sales.coordinates(:product, :quarter)).must_equal({
        product: ['Widget', 'Gadget'],
        quarter: ['Q1', 'Q2']
      })
    end

    it "with multiple args includes unknown dimensions as [nil]" do
      _(sales.coordinates(:product, :missing)).must_equal({
        product: ['Widget', 'Gadget'],
        missing: [nil]
      })
    end

    it "covers derived dimensions in the no-arg form" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.coordinates[:revenue]).must_equal [1000.0, 1500.0]
    end
  end

  describe "#values" do
    it "with no args returns a Hash of full sequences for each dimension" do
      _(sales.values).must_equal({
        product: ['Widget', 'Widget', 'Gadget', 'Gadget'],
        quarter: ['Q1', 'Q2', 'Q1', 'Q2'],
        price: [10.0, 10.0, 25.0, 25.0],
        quantity: [100, 150, 40, 60]
      })
    end

    it "with one arg returns just that column as an Array, preserving duplicates and order" do
      _(sales.values(:product)).must_equal ['Widget', 'Widget', 'Gadget', 'Gadget']
      _(sales.values(:price)).must_equal [10.0, 10.0, 25.0, 25.0]
    end

    it "with one arg returns an Array of nils for an unknown dimension (one nil per row)" do
      _(sales.values(:missing)).must_equal [nil, nil, nil, nil]
    end

    it "with one arg evaluates a derived dimension across all rows" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.values(:revenue)).must_equal [1000.0, 1500.0, 1000.0, 1500.0]
    end

    it "with multiple args returns a subset Hash" do
      _(sales.values(:product, :quarter)).must_equal({
        product: ['Widget', 'Widget', 'Gadget', 'Gadget'],
        quarter: ['Q1', 'Q2', 'Q1', 'Q2']
      })
    end

    it "with multiple args includes unknown dimensions as Arrays of nils" do
      _(sales.values(:product, :missing)).must_equal({
        product: ['Widget', 'Widget', 'Gadget', 'Gadget'],
        missing: [nil, nil, nil, nil]
      })
    end

    it "covers derived dimensions in the no-arg form" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.values[:revenue]).must_equal [1000.0, 1500.0, 1000.0, 1500.0]
    end
  end

  describe "#to_h" do
    it "returns the full values Hash" do
      _(sales.to_h).must_equal sales.values
    end
  end

  describe "aspect consistency" do
    it "satisfies coordinates(dim) == values(dim).uniq for each dimension" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      sales.dimensions.each do |dim|
        _(sales.coordinates(dim)).must_equal sales.values(dim).uniq
      end
    end
  end

  describe "live-view semantics" do
    it "reflects added rows on next call" do
      _(sales.values(:product)).must_equal ['Widget', 'Widget', 'Gadget', 'Gadget']
      sales.data << {product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}
      _(sales.values(:product)).must_equal ['Widget', 'Widget', 'Gadget', 'Gadget', 'Thingo']
    end

    it "reflects added formulae on next call" do
      _(sales.derived_dimensions).must_equal []
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.derived_dimensions).must_equal [:revenue]
      _(sales.coordinates(:revenue)).must_equal [1000.0, 1500.0]
    end
  end

  describe "#[]" do
    context "selection" do
      it "selects by single coordinate" do
        result = sales[product: 'Widget']
        _(result.coordinates[:product]).must_equal ['Widget']
        _(result.to_a.count).must_equal 2
        _(result.to_a.map{|row| row[:product]}).must_equal ['Widget', 'Widget']
      end

      it "selects by array of coordinates" do
        result = sales[quarter: ['Q1']]
        _(result.coordinates[:quarter]).must_equal ['Q1']
        _(result.to_a.count).must_equal 2
      end

      it "selects by multiple dimensions" do
        result = sales[product: 'Widget', quarter: 'Q1']
        _(result.to_a.count).must_equal 1
        _(result.to_a).must_equal [{product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100}]
      end

      it "returns a Namo instance" do
        result = sales[product: 'Widget']
        _(result.coordinates[:product]).must_equal ['Widget']
      end
    end

    context "projection" do
      it "projects to named dimensions" do
        result = sales[:product, :price]
        _(result.dimensions).must_equal [:product, :price]
        _(result.coordinates[:product]).must_equal ['Widget', 'Gadget']
        _(result.to_a.count).must_equal 4
      end
    end

    context "selection and projection" do
      it "can use them together" do
        result = sales[:price, product: 'Widget']
        _(result.to_a.count).must_equal 2
        _(result.to_a).must_equal [{price: 10.0}, {price: 10.0}]
      end

      it "can chain them" do
        result = sales[product: 'Widget'][:price]
        _(result.to_a.count).must_equal 2
        _(result.to_a).must_equal [{price: 10.0}, {price: 10.0}]
      end
    end

    context "contraction" do
      it "removes named dimensions" do
        result = sales[-:price, -:quantity]
        _(result.dimensions).must_equal [:product, :quarter]
        _(result.to_a.count).must_equal 4
        _(result.to_a.first).must_equal({product: 'Widget', quarter: 'Q1'})
      end

      it "removes a single dimension" do
        result = sales[-:price]
        _(result.dimensions).must_equal [:product, :quarter, :quantity]
        _(result.to_a.count).must_equal 4
      end

      it "raises when mixing projection and contraction" do
        _ { sales[:product, -:price] }.must_raise ArgumentError
      end

      it "carries formulae through contraction" do
        sales[:label] = proc{|r| "#{r[:product]}-#{r[:quarter]}"}
        result = sales[-:price, -:quantity]
        _(result.map{|row| row[:label]}).must_equal [
          'Widget-Q1', 'Widget-Q2', 'Gadget-Q1', 'Gadget-Q2'
        ]
      end
    end

    context "selection and contraction" do
      it "can use them together" do
        result = sales[-:price, -:quantity, product: 'Widget']
        _(result.to_a.count).must_equal 2
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q1'},
          {product: 'Widget', quarter: 'Q2'}
        ]
      end

      it "can chain them" do
        result = sales[product: 'Widget'][-:price, -:quantity]
        _(result.to_a.count).must_equal 2
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q1'},
          {product: 'Widget', quarter: 'Q2'}
        ]
      end
    end

    context "proc selection" do
      it "selects rows where the proc returns truthy" do
        result = sales[price: ->(v){v < 15.0}]
        _(result.to_a.count).must_equal 2
        _(result.to_a.map{|row| row[:product]}).must_equal ['Widget', 'Widget']
      end

      it "selects on multiple proc dimensions" do
        result = sales[price: ->(v){v < 30.0}, quantity: ->(v){v > 50}]
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
          {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
          {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
        ]
      end

      it "composes with projection in a single call" do
        result = sales[:product, :price, price: ->(v){v < 15.0}]
        _(result.to_a).must_equal [
          {product: 'Widget', price: 10.0},
          {product: 'Widget', price: 10.0}
        ]
      end

      it "composes with contraction in a single call" do
        result = sales[-:quantity, price: ->(v){v < 15.0}]
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q1', price: 10.0},
          {product: 'Widget', quarter: 'Q2', price: 10.0}
        ]
      end

      it "selects on a formula-defined dimension" do
        sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
        result = sales[revenue: ->(v){v >= 1500.0}]
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
          {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
        ]
      end
    end

    context "regex selection" do
      it "selects by regex against String values" do
        result = sales[product: /^W/]
        _(result.to_a.count).must_equal 2
        _(result.to_a.map{|row| row[:product]}).must_equal ['Widget', 'Widget']
      end

      it "supports case-insensitive matching" do
        result = sales[product: /widget/i]
        _(result.to_a.count).must_equal 2
      end

      it "supports alternation" do
        result = sales[product: /Widget|Gadget/]
        _(result.to_a.count).must_equal 4
      end

      it "coerces non-String values via to_s" do
        result = sales[quantity: /^1/]
        _(result.to_a.map{|row| row[:quantity]}).must_equal [100, 150]
      end

      it "composes with an exact value on another dimension" do
        result = sales[product: /^W/, quarter: 'Q1']
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100}
        ]
      end

      it "composes with projection in a single call" do
        result = sales[:product, :quarter, product: /^W/]
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q1'},
          {product: 'Widget', quarter: 'Q2'}
        ]
      end

      it "composes with contraction in a single call" do
        result = sales[-:price, -:quantity, product: /^W/]
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q1'},
          {product: 'Widget', quarter: 'Q2'}
        ]
      end

      it "selects on a formula-defined dimension" do
        sales[:label] = proc{|r| "#{r[:product]}-#{r[:quarter]}"}
        result = sales[label: /Widget/]
        _(result.to_a.count).must_equal 2
        _(result.map{|row| row[:label]}).must_equal ['Widget-Q1', 'Widget-Q2']
      end
    end

    context "mixed proc and regex selection" do
      it "combines a proc and a regex across dimensions" do
        result = sales[product: /^W/, quantity: ->(v){v > 100}]
        _(result.to_a).must_equal [
          {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150}
        ]
      end
    end
  end

  describe "#[]= formulae" do
    it "defines a formula" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales[:product, :quarter, :revenue].to_a).must_equal [
        {product: "Widget", quarter: "Q1", revenue: 1000.0},
        {product: "Widget", quarter: "Q2", revenue: 1500.0},
        {product: "Gadget", quarter: "Q1", revenue: 1000.0},
        {product: "Gadget", quarter: "Q2", revenue: 1500.0}
      ]
    end

    it "composes formulae" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      sales[:cost] = proc{|r| r[:quantity] * 4.0}
      sales[:profit] = proc{|r| r[:revenue] - r[:cost]}
      _(sales[:product, :quarter, :profit].to_a).must_equal [
        {product: "Widget", quarter: "Q1", profit: 600.0},
        {product: "Widget", quarter: "Q2", profit: 900.0},
        {product: "Gadget", quarter: "Q1", profit: 840.0},
        {product: "Gadget", quarter: "Q2", profit: 1260.0}
      ]
    end

    it "works with chained selection and projection" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales[product: 'Widget'][:product, :quarter, :revenue]
      _(result.to_a).must_equal [
        {product: "Widget", quarter: "Q1", revenue: 1000.0},
        {product: "Widget", quarter: "Q2", revenue: 1500.0}
      ]
    end

    it "works with single-call selection and projection" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales[:product, :revenue, product: 'Widget']
      _(result.to_a).must_equal [
        {product: "Widget", revenue: 1000.0},
        {product: "Widget", revenue: 1500.0}
      ]
    end

    it "carries formulae through selection" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      widgets = sales[product: 'Widget']
      _(widgets[:revenue].to_a).must_equal [{revenue: 1000.0}, {revenue: 1500.0}]
    end

    it "projects formula with context dimensions" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales[:product, :quarter, :revenue]
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1', revenue: 1000.0},
        {product: 'Widget', quarter: 'Q2', revenue: 1500.0},
        {product: 'Gadget', quarter: 'Q1', revenue: 1000.0},
        {product: 'Gadget', quarter: 'Q2', revenue: 1500.0}
      ]
    end
  end

  describe "#[]= polymorphic dispatch" do
    it "registers a formula when assigned a proc (existing behaviour preserved)" do
      namo = Namo.new([{price: 10.0, quantity: 100}])
      namo[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(namo.derived_dimensions).must_include :revenue
      _(namo.values(:revenue)).must_equal [1000.0]
    end

    it "clears any data column of the same name when assigned a proc" do
      namo = Namo.new([{x: 1}, {x: 2}])
      _(namo.data_dimensions).must_include :x
      namo[:x] = proc{|r| 99}
      _(namo.data_dimensions).wont_include :x
      _(namo.derived_dimensions).must_include :x
      _(namo.values(:x)).must_equal [99, 99]
    end

    it "broadcasts a scalar to every row" do
      namo = Namo.new([{a: 1}, {a: 2}, {a: 3}])
      namo[:status] = 'active'
      _(namo.values(:status)).must_equal ['active', 'active', 'active']
    end

    it "clears any formula of the same name when assigned a scalar" do
      namo = Namo.new([{price: 10.0, quantity: 100}])
      namo[:revenue] = proc{|r| r[:price] * r[:quantity]}
      namo[:revenue] = 0
      _(namo.derived_dimensions).wont_include :revenue
      _(namo.data_dimensions).must_include :revenue
      _(namo.values(:revenue)).must_equal [0]
    end

    it "broadcasts an array as the value (array is not a proc)" do
      namo = Namo.new([{a: 1}, {a: 2}])
      namo[:weights] = [1, 2, 3]
      _(namo.values(:weights)).must_equal [[1, 2, 3], [1, 2, 3]]
    end

    it "is last-write-wins: scalar then proc leaves a formula only" do
      namo = Namo.new([{y: 7}])
      namo[:x] = 5
      namo[:x] = proc{|r| r[:y]}
      _(namo.derived_dimensions).must_include :x
      _(namo.data_dimensions).wont_include :x
      _(namo.values(:x)).must_equal [7]
    end

    it "is last-write-wins: proc then scalar leaves a broadcast value only" do
      namo = Namo.new([{y: 7}])
      namo[:x] = proc{|r| r[:y]}
      namo[:x] = 5
      _(namo.data_dimensions).must_include :x
      _(namo.derived_dimensions).wont_include :x
      _(namo.values(:x)).must_equal [5]
    end

    it "surfaces a proc-assigned name as derived, not data, exactly once in dimensions" do
      namo = Namo.new([{x: 1}, {x: 2}])
      namo[:x] = proc{|r| 99}
      _(namo.data_dimensions).wont_include :x
      _(namo.derived_dimensions).must_include :x
      _(namo.dimensions.count(:x)).must_equal 1
    end

    it "surfaces a scalar-assigned name as data, not derived, exactly once in dimensions" do
      namo = Namo.new([{x: 1}])
      namo[:rev] = proc{|r| r[:x]}
      namo[:rev] = 5
      _(namo.data_dimensions).must_include :rev
      _(namo.derived_dimensions).wont_include :rev
      _(namo.dimensions.count(:rev)).must_equal 1
    end

    it "does not walk rows to clear when no data column of that name exists" do
      namo = Namo.new([{a: 1}])
      namo[:b] = proc{|r| r[:a]}
      _(namo.derived_dimensions).must_include :b
      _(namo.values(:b)).must_equal [1]
    end

    it "handles an empty Namo without error" do
      namo = Namo.new([])
      namo[:x] = proc{|r| 1}
      _(namo.derived_dimensions).must_include :x
    end
  end

  describe "#each" do
    it "yields Row objects" do
      rows = []
      sales.each{|row| rows << row}
      _(rows.first).must_be_kind_of Namo::Row
      _(rows.length).must_equal 4
    end

    it "yields rows with access to data" do
      products = sales.map{|row| row[:product]}
      _(products).must_equal ['Widget', 'Widget', 'Gadget', 'Gadget']
    end

    it "yields rows with access to formulae" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      revenues = sales.map{|row| row[:revenue]}
      _(revenues).must_equal [1000.0, 1500.0, 1000.0, 1500.0]
    end

    it "returns an enumerator without a block" do
      _(sales.each).must_be_kind_of Enumerator
    end
  end

  describe "Enumerable" do
    it "supports reduce" do
      total_quantity = sales.reduce(0){|sum, row| sum + row[:quantity]}
      _(total_quantity).must_equal 350
    end

    it "supports reduce with selection" do
      widget_quantity = sales[product: 'Widget'].reduce(0){|sum, row| sum + row[:quantity]}
      _(widget_quantity).must_equal 250
    end

    it "supports reduce with formulae" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      total_revenue = sales.reduce(0){|sum, row| sum + row[:revenue]}
      _(total_revenue).must_equal 5000.0
    end

    it "supports reduce with selection and formulae" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      widget_revenue = sales[product: 'Widget'].reduce(0){|sum, row| sum + row[:revenue]}
      _(widget_revenue).must_equal 2500.0
    end

    it "supports min_by" do
      cheapest = sales.min_by{|row| row[:price]}
      _(cheapest[:product]).must_equal 'Widget'
    end

    it "supports flat_map" do
      prices = sales.flat_map{|row| [row[:price]]}
      _(prices).must_equal [10.0, 10.0, 25.0, 25.0]
    end
  end

  describe "#select" do
    it "returns a Namo of matching rows" do
      result = sales.select{|row| row[:price] < 20.0}
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150}
      ]
    end

    it "selects using formula references in the block" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales.select{|row| row[:revenue] >= 1500.0}
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
      ]
    end

    it "preserves formulae through to the returned Namo" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales.select{|row| row[:price] < 20.0}
      _(result.values(:revenue)).must_equal [1000.0, 1500.0]
    end

    it "returns an empty Namo when nothing matches" do
      result = sales.select{|row| row[:price] > 1000.0}
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal []
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      result = subclass.new(sample_data).select{|row| row[:price] < 20.0}
      _(result.class).must_equal subclass
    end

    it "is aliased as filter, returning a Namo" do
      result = sales.filter{|row| row[:price] < 20.0}
      _(result).must_be_kind_of Namo
      _(result.values(:product)).must_equal ['Widget', 'Widget']
    end

    it "is aliased as find_all, returning a Namo" do
      result = sales.find_all{|row| row[:price] < 20.0}
      _(result).must_be_kind_of Namo
      _(result.values(:product)).must_equal ['Widget', 'Widget']
    end
  end

  describe "#reject" do
    it "returns the complement of select" do
      result = sales.reject{|row| row[:price] < 20.0}
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal [
        {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
      ]
    end

    it "together with select sums to the original" do
      selected = sales.select{|row| row[:price] < 20.0}
      rejected = sales.reject{|row| row[:price] < 20.0}
      _((selected.to_a + rejected.to_a).length).must_equal sample_data.length
    end

    it "preserves formulae through to the returned Namo" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales.reject{|row| row[:price] < 20.0}
      _(result.values(:revenue)).must_equal [1000.0, 1500.0]
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      result = subclass.new(sample_data).reject{|row| row[:price] < 20.0}
      _(result.class).must_equal subclass
    end
  end

  describe "#sort_by" do
    it "returns rows in the specified order" do
      result = sales.sort_by{|row| row[:quantity]}
      _(result).must_be_kind_of Namo
      _(result.values(:quantity)).must_equal [40, 60, 100, 150]
    end

    it "sorts using formula references in the block" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales.sort_by{|row| row[:revenue]}
      _(result.values(:revenue)).must_equal [1000.0, 1000.0, 1500.0, 1500.0]
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      result = subclass.new(sample_data).sort_by{|row| row[:quantity]}
      _(result.class).must_equal subclass
    end
  end

  describe "#first" do
    it "with an argument returns a Namo of the first n rows" do
      result = sales.first(2)
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150}
      ]
    end

    it "with an argument of 0 returns an empty Namo" do
      result = sales.first(0)
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal []
    end

    it "without an argument returns a Row" do
      result = sales.first
      _(result).must_be_kind_of Namo::Row
      _(result[:product]).must_equal 'Widget'
    end

    it "without an argument on an empty Namo returns nil" do
      _(Namo.new.first).must_be_nil
    end

    it "preserves formulae through to the returned Namo" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.first(2).values(:revenue)).must_equal [1000.0, 1500.0]
    end

    it "returns an instance of self's class with an argument" do
      subclass = Class.new(Namo)
      _(subclass.new(sample_data).first(2).class).must_equal subclass
    end
  end

  describe "#last" do
    it "with an argument returns a Namo of the last n rows" do
      result = sales.last(2)
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal [
        {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
      ]
    end

    it "with an argument of 0 returns an empty Namo" do
      result = sales.last(0)
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal []
    end

    it "without an argument returns a Row" do
      result = sales.last
      _(result).must_be_kind_of Namo::Row
      _(result[:product]).must_equal 'Gadget'
      _(result[:quarter]).must_equal 'Q2'
    end

    it "without an argument on an empty Namo returns nil" do
      _(Namo.new.last).must_be_nil
    end

    it "preserves formulae through to the returned Namo" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      _(sales.last(2).values(:revenue)).must_equal [1000.0, 1500.0]
    end

    it "returns an instance of self's class with an argument" do
      subclass = Class.new(Namo)
      _(subclass.new(sample_data).last(2).class).must_equal subclass
    end
  end

  describe "#take" do
    it "returns a Namo of the first n rows" do
      result = sales.take(2)
      _(result).must_be_kind_of Namo
      _(result.values(:quantity)).must_equal [100, 150]
    end

    it "returns an empty Namo for n of 0" do
      _(sales.take(0).to_a).must_equal []
    end

    it "returns all rows when n exceeds the length" do
      _(sales.take(10).to_a).must_equal sample_data
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      _(subclass.new(sample_data).take(2).class).must_equal subclass
    end
  end

  describe "#drop" do
    it "returns a Namo of all rows past the first n" do
      result = sales.drop(2)
      _(result).must_be_kind_of Namo
      _(result.values(:quantity)).must_equal [40, 60]
    end

    it "returns all rows for n of 0" do
      _(sales.drop(0).to_a).must_equal sample_data
    end

    it "returns an empty Namo when n exceeds the length" do
      _(sales.drop(10).to_a).must_equal []
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      _(subclass.new(sample_data).drop(2).class).must_equal subclass
    end
  end

  describe "#take_while" do
    it "returns a Namo of leading rows while the predicate holds" do
      result = sales.take_while{|row| row[:price] < 20.0}
      _(result).must_be_kind_of Namo
      _(result.values(:product)).must_equal ['Widget', 'Widget']
    end

    it "evaluates the predicate against formula references" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales.take_while{|row| row[:revenue] < 1500.0}
      _(result.values(:revenue)).must_equal [1000.0]
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      _(subclass.new(sample_data).take_while{|row| row[:price] < 20.0}.class).must_equal subclass
    end
  end

  describe "#drop_while" do
    it "returns a Namo of rows from the first predicate failure" do
      result = sales.drop_while{|row| row[:price] < 20.0}
      _(result).must_be_kind_of Namo
      _(result.values(:product)).must_equal ['Gadget', 'Gadget']
    end

    it "evaluates the predicate against formula references" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales.drop_while{|row| row[:revenue] < 1500.0}
      _(result.values(:revenue)).must_equal [1500.0, 1000.0, 1500.0]
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      _(subclass.new(sample_data).drop_while{|row| row[:price] < 20.0}.class).must_equal subclass
    end
  end

  describe "#uniq" do
    let(:dup_data) do
      [
        {product: 'Widget', quarter: 'Q1'},
        {product: 'Widget', quarter: 'Q1'},
        {product: 'Gadget', quarter: 'Q1'},
        {product: 'Widget', quarter: 'Q2'}
      ]
    end

    it "without a block dedupes rows on full-row equality" do
      result = Namo.new(dup_data).uniq
      _(result).must_be_kind_of Namo
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1'},
        {product: 'Gadget', quarter: 'Q1'},
        {product: 'Widget', quarter: 'Q2'}
      ]
    end

    it "distinguishes numeric types, matching Row#eql? semantics" do
      result = Namo.new([{n: 1}, {n: 1.0}]).uniq
      _(result.to_a).must_equal [{n: 1}, {n: 1.0}]
    end

    it "with a block dedupes on the block's return value" do
      result = Namo.new(dup_data).uniq{|row| row[:product]}
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1'},
        {product: 'Gadget', quarter: 'Q1'}
      ]
    end

    it "preserves formulae through to the returned Namo" do
      namo = Namo.new(dup_data)
      namo[:label] = proc{|r| "#{r[:product]}-#{r[:quarter]}"}
      result = namo.uniq
      _(result.values(:label)).must_equal ['Widget-Q1', 'Gadget-Q1', 'Widget-Q2']
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      _(subclass.new(dup_data).uniq.class).must_equal subclass
    end
  end

  describe "#partition" do
    it "returns a two-element Array of Namos" do
      result = sales.partition{|row| row[:price] < 20.0}
      _(result).must_be_kind_of Array
      _(result.length).must_equal 2
      _(result[0]).must_be_kind_of Namo
      _(result[1]).must_be_kind_of Namo
    end

    it "splits into matches and non-matches summing to the original" do
      matches, non_matches = sales.partition{|row| row[:price] < 20.0}
      _(matches.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150}
      ]
      _(non_matches.to_a).must_equal [
        {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
      ]
      _((matches.to_a + non_matches.to_a).length).must_equal sample_data.length
    end

    it "partitions using formula references in the block" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      matches, non_matches = sales.partition{|row| row[:revenue] >= 1500.0}
      _(matches.values(:revenue)).must_equal [1500.0, 1500.0]
      _(non_matches.values(:revenue)).must_equal [1000.0, 1000.0]
    end

    it "preserves formulae through to both returned Namos" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      matches, non_matches = sales.partition{|row| row[:price] < 20.0}
      _(matches.values(:revenue)).must_equal [1000.0, 1500.0]
      _(non_matches.values(:revenue)).must_equal [1000.0, 1500.0]
    end

    it "returns instances of self's class" do
      subclass = Class.new(Namo)
      matches, non_matches = subclass.new(sample_data).partition{|row| row[:price] < 20.0}
      _(matches.class).must_equal subclass
      _(non_matches.class).must_equal subclass
    end
  end

  describe "subset methods on an empty Namo" do
    let(:empty) { Namo.new }

    it "select returns an empty Namo" do
      _(empty.select{|row| true}.to_a).must_equal []
    end

    it "reject returns an empty Namo" do
      _(empty.reject{|row| true}.to_a).must_equal []
    end

    it "sort_by returns an empty Namo" do
      _(empty.sort_by{|row| row[:x]}.to_a).must_equal []
    end

    it "first(n) returns an empty Namo" do
      _(empty.first(2).to_a).must_equal []
    end

    it "last(n) returns an empty Namo" do
      _(empty.last(2).to_a).must_equal []
    end

    it "take and drop return empty Namos" do
      _(empty.take(2).to_a).must_equal []
      _(empty.drop(2).to_a).must_equal []
    end

    it "take_while and drop_while return empty Namos" do
      _(empty.take_while{|row| true}.to_a).must_equal []
      _(empty.drop_while{|row| true}.to_a).must_equal []
    end

    it "uniq returns an empty Namo" do
      _(empty.uniq.to_a).must_equal []
    end

    it "partition returns two empty Namos" do
      matches, non_matches = empty.partition{|row| true}
      _(matches.to_a).must_equal []
      _(non_matches.to_a).must_equal []
    end
  end

  describe "unchanged Enumerable methods" do
    it "map still returns an Array" do
      _(sales.map{|row| row[:product]}).must_be_kind_of Array
    end

    it "flat_map still returns an Array" do
      _(sales.flat_map{|row| [row[:price]]}).must_be_kind_of Array
    end

    it "reduce still returns a scalar" do
      _(sales.reduce(0){|sum, row| sum + row[:quantity]}).must_equal 350
    end
  end

  describe "Namo::Enumerable module" do
    it "is a Module supplying the subset methods" do
      _(Namo::Enumerable).must_be_kind_of Module
    end

    it "is included in Namo, transitively including stdlib Enumerable" do
      _(Namo.include?(Namo::Enumerable)).must_equal true
      _(Namo.include?(Enumerable)).must_equal true
    end

    it "sits above stdlib Enumerable so its overrides win" do
      ancestors = Namo.ancestors
      _(ancestors.index(Namo::Enumerable) < ancestors.index(::Enumerable)).must_equal true
    end
  end

  describe "#+" do
    let(:more_data) do
      [
        {product: 'Widget', quarter: 'Q3', price: 10.0, quantity: 200},
        {product: 'Gadget', quarter: 'Q3', price: 25.0, quantity: 80}
      ]
    end

    let(:more_sales) do
      Namo.new(more_data)
    end

    it "concatenates rows" do
      result = sales + more_sales
      _(result.to_a.count).must_equal 6
      _(result.to_a).must_equal(sample_data + more_data)
    end

    it "preserves dimensions" do
      result = sales + more_sales
      _(result.dimensions).must_equal [:product, :quarter, :price, :quantity]
    end

    it "carries formulae through from self" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales + more_sales
      _(result.map{|row| row[:revenue]}).must_equal [1000.0, 1500.0, 1000.0, 1500.0, 2000.0, 2000.0]
    end

    it "merges formulae from other" do
      more_sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales + more_sales
      _(result.map{|row| row[:revenue]}).must_equal [1000.0, 1500.0, 1000.0, 1500.0, 2000.0, 2000.0]
    end

    it "prefers self's formulae on conflict" do
      sales[:label] = proc{|r| "self: #{r[:product]}"}
      more_sales[:label] = proc{|r| "other: #{r[:product]}"}
      result = sales + more_sales
      _(result.map{|row| row[:label]}).must_equal [
        'self: Widget', 'self: Widget', 'self: Gadget', 'self: Gadget',
        'self: Widget', 'self: Gadget'
      ]
    end

    it "raises when dimensions differ" do
      other = Namo.new([{product: 'Widget', quarter: 'Q1'}])
      _ { sales + other }.must_raise ArgumentError
    end
  end

  describe "#-" do
    let(:to_remove) do
      Namo.new([
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
      ])
    end

    it "removes matching rows" do
      result = sales - to_remove
      _(result.to_a.count).must_equal 2
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
        {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40}
      ]
    end

    it "preserves non-matching rows" do
      other = Namo.new([{product: 'Thingo', quarter: 'Q4', price: 99.0, quantity: 1}])
      result = sales - other
      _(result.to_a).must_equal sample_data
    end

    it "carries formulae through from self" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales - to_remove
      _(result.map{|row| row[:revenue]}).must_equal [1500.0, 1000.0]
    end

    it "raises when dimensions differ" do
      other = Namo.new([{product: 'Widget', quarter: 'Q1'}])
      _ { sales - other }.must_raise ArgumentError
    end
  end

  describe "#&" do
    let(:other) do
      Namo.new([
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60},
        {product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}
      ])
    end

    it "returns rows present in both" do
      result = sales & other
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60}
      ]
    end

    it "returns empty when nothing overlaps" do
      other = Namo.new([{product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}])
      result = sales & other
      _(result.to_a).must_equal []
    end

    it "preserves dimensions" do
      result = sales & other
      _(result.dimensions).must_equal [:product, :quarter, :price, :quantity]
    end

    it "carries formulae through from self" do
      sales[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales & other
      _(result.map{|row| row[:revenue]}).must_equal [1000.0, 1500.0]
    end

    it "raises when dimensions differ" do
      other = Namo.new([{product: 'Widget', quarter: 'Q1'}])
      _ { sales & other }.must_raise ArgumentError
    end
  end

  describe "#|" do
    let(:other) do
      Namo.new([
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}
      ])
    end

    it "returns all rows deduplicated" do
      result = sales | other
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
        {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60},
        {product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}
      ]
    end

    it "preserves dimensions" do
      result = sales | other
      _(result.dimensions).must_equal [:product, :quarter, :price, :quantity]
    end

    it "merges formulae from other" do
      other[:revenue] = proc{|r| r[:price] * r[:quantity]}
      result = sales | other
      _(result.map{|row| row[:revenue]}).must_equal [1000.0, 1500.0, 1000.0, 1500.0, 50.0]
    end

    it "prefers self's formulae on conflict" do
      sales[:label] = proc{|r| "self: #{r[:product]}"}
      other[:label] = proc{|r| "other: #{r[:product]}"}
      result = sales | other
      _(result.map{|row| row[:label]}).must_equal [
        'self: Widget', 'self: Widget', 'self: Gadget', 'self: Gadget', 'self: Thingo'
      ]
    end

    it "raises when dimensions differ" do
      other = Namo.new([{product: 'Widget', quarter: 'Q1'}])
      _ { sales | other }.must_raise ArgumentError
    end
  end

  describe "#^" do
    let(:other) do
      Namo.new([
        {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
        {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 60},
        {product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}
      ])
    end

    it "returns rows in one but not both" do
      result = sales ^ other
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
        {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 40},
        {product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}
      ]
    end

    it "returns empty when both are identical" do
      result = sales ^ sales
      _(result.to_a).must_equal []
    end

    it "returns all rows when nothing overlaps" do
      other = Namo.new([{product: 'Thingo', quarter: 'Q3', price: 5.0, quantity: 10}])
      result = sales ^ other
      _(result.to_a.count).must_equal 5
    end

    it "merges formulae with self winning on conflict" do
      sales[:label] = proc{|r| "self: #{r[:product]}"}
      other[:label] = proc{|r| "other: #{r[:product]}"}
      result = sales ^ other
      _(result.map{|row| row[:label]}).must_equal [
        'self: Widget', 'self: Gadget', 'self: Thingo'
      ]
    end

    it "raises when dimensions differ" do
      other = Namo.new([{product: 'Widget', quarter: 'Q1'}])
      _ { sales ^ other }.must_raise ArgumentError
    end
  end

  describe "#*" do
    let(:ohlcv) do
      Namo.new([
        {symbol: 'BHP', date: '2025-01-01', close: 42.5},
        {symbol: 'RIO', date: '2025-01-01', close: 118.3}
      ])
    end

    let(:fundamentals) do
      Namo.new([
        {symbol: 'BHP', pe: 14.5},
        {symbol: 'RIO', pe: 9.2}
      ])
    end

    it "joins on a single shared dimension" do
      result = ohlcv * fundamentals
      _(result.to_a).must_equal [
        {symbol: 'BHP', date: '2025-01-01', close: 42.5, pe: 14.5},
        {symbol: 'RIO', date: '2025-01-01', close: 118.3, pe: 9.2}
      ]
    end

    it "joins on multiple shared dimensions" do
      a = Namo.new([
        {symbol: 'BHP', date: '2025-01-01', close: 42.5},
        {symbol: 'BHP', date: '2025-01-02', close: 43.0}
      ])
      b = Namo.new([
        {symbol: 'BHP', date: '2025-01-01', volume: 1000},
        {symbol: 'BHP', date: '2025-01-02', volume: 1500}
      ])
      result = a * b
      _(result.to_a).must_equal [
        {symbol: 'BHP', date: '2025-01-01', close: 42.5, volume: 1000},
        {symbol: 'BHP', date: '2025-01-02', close: 43.0, volume: 1500}
      ]
    end

    it "preserves non-shared dimensions from both sides" do
      result = ohlcv * fundamentals
      _(result.dimensions).must_equal [:symbol, :date, :close, :pe]
    end

    it "drops unmatched rows from both sides (inner-join symmetry)" do
      left = Namo.new([
        {symbol: 'BHP', close: 42.5},
        {symbol: 'CBA', close: 100.0}
      ])
      right = Namo.new([
        {symbol: 'BHP', pe: 14.5},
        {symbol: 'RIO', pe: 9.2}
      ])
      result = left * right
      _(result.to_a).must_equal [{symbol: 'BHP', close: 42.5, pe: 14.5}]
    end

    it "produces multiplicative duplicates when inputs have duplicates on shared dimensions" do
      left = Namo.new([
        {symbol: 'BHP', close: 42.5},
        {symbol: 'BHP', close: 43.0}
      ])
      right = Namo.new([
        {symbol: 'BHP', pe: 14.5},
        {symbol: 'BHP', pe: 14.7}
      ])
      result = left * right
      _(result.to_a.length).must_equal 4
      _(result.to_a).must_equal [
        {symbol: 'BHP', close: 42.5, pe: 14.5},
        {symbol: 'BHP', close: 42.5, pe: 14.7},
        {symbol: 'BHP', close: 43.0, pe: 14.5},
        {symbol: 'BHP', close: 43.0, pe: 14.7}
      ]
    end

    it "carries formulae through from self" do
      ohlcv[:label] = proc{|r| "#{r[:symbol]}-self"}
      result = ohlcv * fundamentals
      _(result.map{|row| row[:label]}).must_equal ['BHP-self', 'RIO-self']
    end

    it "merges formulae from other" do
      fundamentals[:flag] = proc{|r| "pe=#{r[:pe]}"}
      result = ohlcv * fundamentals
      _(result.map{|row| row[:flag]}).must_equal ['pe=14.5', 'pe=9.2']
    end

    it "prefers self's formulae on conflict" do
      ohlcv[:label] = proc{|r| "self: #{r[:symbol]}"}
      fundamentals[:label] = proc{|r| "other: #{r[:symbol]}"}
      result = ohlcv * fundamentals
      _(result.map{|row| row[:label]}).must_equal ['self: BHP', 'self: RIO']
    end

    it "raises ArgumentError when there are no shared dimensions" do
      a = Namo.new([{symbol: 'BHP'}])
      b = Namo.new([{quarter: 'Q1'}])
      err = _ { a * b }.must_raise ArgumentError
      _(err.message).must_match(/no shared dimensions, need to have shared dimensions/)
    end

    it "raises TypeError on a non-Namo operand" do
      _ { ohlcv * [{symbol: 'BHP'}] }.must_raise TypeError
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      a = subclass.new([{symbol: 'BHP', close: 42.5}])
      b = Namo.new([{symbol: 'BHP', pe: 14.5}])
      _((a * b).class).must_equal subclass
    end
  end

  describe "#**" do
    let(:products) do
      Namo.new([{product: 'Widget'}, {product: 'Gadget'}])
    end

    let(:quarters) do
      Namo.new([{quarter: 'Q1'}, {quarter: 'Q2'}])
    end

    it "Cartesian-products two disjoint Namos" do
      result = products ** quarters
      _(result.to_a).must_equal [
        {product: 'Widget', quarter: 'Q1'},
        {product: 'Widget', quarter: 'Q2'},
        {product: 'Gadget', quarter: 'Q1'},
        {product: 'Gadget', quarter: 'Q2'}
      ]
    end

    it "has self.data.length * other.data.length rows" do
      a = Namo.new([{x: 1}, {x: 2}, {x: 3}])
      b = Namo.new([{y: 'a'}, {y: 'b'}])
      _((a ** b).to_a.length).must_equal 6
    end

    it "output dimensions are self.data_dimensions + other.data_dimensions" do
      result = products ** quarters
      _(result.dimensions).must_equal [:product, :quarter]
    end

    it "preserves duplicates on either side multiplicatively" do
      a = Namo.new([{x: 1}, {x: 1}])
      b = Namo.new([{y: 'a'}, {y: 'a'}])
      result = a ** b
      _(result.to_a.length).must_equal 4
    end

    it "carries formulae through from self" do
      products[:label] = proc{|r| "self: #{r[:product]}"}
      result = products ** quarters
      _(result.map{|row| row[:label]}).must_equal [
        'self: Widget', 'self: Widget', 'self: Gadget', 'self: Gadget'
      ]
    end

    it "merges formulae from other" do
      quarters[:flag] = proc{|r| "q=#{r[:quarter]}"}
      result = products ** quarters
      _(result.map{|row| row[:flag]}).must_equal ['q=Q1', 'q=Q2', 'q=Q1', 'q=Q2']
    end

    it "prefers self's formulae on conflict" do
      products[:label] = proc{|r| "self: #{r[:product]}"}
      quarters[:label] = proc{|r| "other: #{r[:quarter]}"}
      result = products ** quarters
      _(result.map{|row| row[:label]}).must_equal [
        'self: Widget', 'self: Widget', 'self: Gadget', 'self: Gadget'
      ]
    end

    it "raises ArgumentError when any dimension is shared" do
      a = Namo.new([{symbol: 'BHP', close: 42.5}])
      b = Namo.new([{symbol: 'RIO', pe: 14.5}])
      err = _ { a ** b }.must_raise ArgumentError
      _(err.message).must_match(/dimensions in common, need no common dimensions/)
    end

    it "raises TypeError on a non-Namo operand" do
      _ { products ** [{quarter: 'Q1'}] }.must_raise TypeError
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      a = subclass.new([{product: 'Widget'}])
      b = Namo.new([{quarter: 'Q1'}])
      _((a ** b).class).must_equal subclass
    end
  end

  describe "#/" do
    let(:combined) do
      Namo.new([
        {symbol: 'BHP', date: '2025-01-01', close: 42.5, pe: 14.5},
        {symbol: 'RIO', date: '2025-01-01', close: 118.3, pe: 9.2}
      ])
    end

    let(:fundamentals) do
      Namo.new([
        {symbol: 'BHP', pe: 14.5},
        {symbol: 'RIO', pe: 9.2}
      ])
    end

    it "removes dimensions present in both self and other (the intersection)" do
      result = combined / fundamentals
      _(result.dimensions).must_equal [:date, :close]
    end

    it "preserves dimensions exclusive to self" do
      result = combined / fundamentals
      _(result.to_a).must_equal [
        {date: '2025-01-01', close: 42.5},
        {date: '2025-01-01', close: 118.3}
      ]
    end

    it "dedupes rows that collide after projection" do
      a = Namo.new([
        {symbol: 'BHP', close: 42.5},
        {symbol: 'RIO', close: 42.5}
      ])
      b = Namo.new([{symbol: 'X'}])
      result = a / b
      _(result.to_a).must_equal [{close: 42.5}]
    end

    it "carries formulae through from self" do
      combined[:label] = proc{|r| "row: #{r[:close]}"}
      result = combined / fundamentals
      _(result.map{|row| row[:label]}).must_equal ['row: 42.5', 'row: 118.3']
    end

    it "is a no-op when self and other share no dimensions" do
      shipments = Namo.new([{order_id: 1, weight: 10}])
      weather = Namo.new([{date: '2025-01-01', temperature: 22}])
      _(shipments / weather).must_equal shipments
    end

    it "ignores dimensions present in other but not in self" do
      a = Namo.new([{symbol: 'BHP', close: 42.5}])
      b = Namo.new([{symbol: 'BHP', pe: 14.5, sector: 'Mining'}])
      result = a / b
      _(result.dimensions).must_equal [:close]
    end

    it "is idempotent" do
      first = combined / fundamentals
      second = first / fundamentals
      _(second).must_equal first
    end

    it "raises TypeError on a non-Namo operand" do
      _ { combined / [{symbol: 'BHP'}] }.must_raise TypeError
    end

    it "returns an instance of self's class" do
      subclass = Class.new(Namo)
      a = subclass.new([{symbol: 'BHP', close: 42.5}])
      b = Namo.new([{symbol: 'BHP', pe: 14.5}])
      _((a / b).class).must_equal subclass
    end
  end

  describe "composition round-trip" do
    it "satisfies (a ** b) / b == a for disjoint a and b" do
      a = Namo.new([{symbol: 'BHP'}, {symbol: 'RIO'}])
      b = Namo.new([{quarter: 'Q1'}, {quarter: 'Q2'}])
      _((a ** b) / b).must_equal a
    end

    it "satisfies (a * b) / b == a[-:shared] for a and b with shared dimensions (shared dimensions lost)" do
      a = Namo.new([{symbol: 'BHP', close: 42.5}, {symbol: 'RIO', close: 118.3}])
      b = Namo.new([{symbol: 'BHP', pe: 14.5}, {symbol: 'RIO', pe: 9.2}])
      _((a * b) / b).must_equal Namo.new([{close: 42.5}, {close: 118.3}])
    end
  end

  describe "#==" do
    it "is true for same data, same order" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 1}, {x: 2}])
      _(a == b).must_equal true
    end

    it "is true for same data, different order" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 2}, {x: 1}])
      _(a == b).must_equal true
    end

    it "is false for different data" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 1}, {x: 3}])
      _(a == b).must_equal false
    end

    it "is multiset-aware: duplicates count" do
      a = Namo.new([{x: 1}])
      b = Namo.new([{x: 1}, {x: 1}])
      _(a == b).must_equal false
    end

    it "is true across subclasses with same data" do
      subclass = Class.new(Namo)
      a = Namo.new([{x: 1}, {x: 2}])
      b = subclass.new([{x: 1}, {x: 2}])
      _(a == b).must_equal true
    end

    it "ignores formulae" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 1}, {x: 2}])
      b[:y] = proc{|row| row[:x] * 2}
      _(a == b).must_equal true
    end

    it "is false against a non-Namo" do
      a = Namo.new([{x: 1}, {x: 2}])
      _(a == [{x: 1}, {x: 2}]).must_equal false
      _(a == 'string').must_equal false
      _(a == nil).must_equal false
    end
  end

  describe "#===" do
    it "is true when dimensions and formulae match, ignoring rows" do
      a = Namo.new([{x: 1}])
      b = Namo.new([{x: 2}, {x: 3}])
      _(a === b).must_equal true
    end

    it "is false when formulae differ" do
      a = Namo.new([{x: 1}])
      b = Namo.new([{x: 1}])
      b[:doubled] = proc{|row| row[:x] * 2}
      _(a === b).must_equal false
    end

    it "is true when formulae have the same names, regardless of proc identity" do
      a = Namo.new([{x: 1}])
      a[:doubled] = proc{|row| row[:x] * 2}
      b = Namo.new([{x: 1}])
      b[:doubled] = proc{|row| row[:x] * 2}
      _(a === b).must_equal true
    end

    it "is false when dimensions differ" do
      a = Namo.new([{x: 1}])
      b = Namo.new([{y: 1}])
      _(a === b).must_equal false
    end

    it "is true when dimensions are in different order" do
      a = Namo.new([{x: 1, y: 2}])
      b = Namo.new([{y: 9, x: 8}])
      _(a === b).must_equal true
    end

    it "is false for a non-Namo and does not raise" do
      a = Namo.new([{x: 1}])
      _(a === [{x: 1}]).must_equal false
      _(a === 'string').must_equal false
      _(a === nil).must_equal false
    end

    it "drives case statement dispatch on analytical type" do
      template = Namo.new([{x: 0}])
      candidate = Namo.new([{x: 5}, {x: 6}])
      result = case candidate
               when template; :matched
               else; :not_matched
               end
      _(result).must_equal :matched
    end
  end

  describe "#eql?" do
    it "is true for same class, same data, no formulae" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 1}, {x: 2}])
      _(a.eql?(b)).must_equal true
    end

    it "is true for same class, same data, different order" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 2}, {x: 1}])
      _(a.eql?(b)).must_equal true
    end

    it "is true when formula names match, regardless of proc identity" do
      a = Namo.new([{x: 1}, {x: 2}])
      a[:y] = proc{|row| row[:x] * 2}
      b = Namo.new([{x: 1}, {x: 2}])
      b[:y] = proc{|row| row[:x] * 2}
      _(a.eql?(b)).must_equal true
    end

    it "is false when formula names differ" do
      a = Namo.new([{x: 1}, {x: 2}])
      a[:doubled] = proc{|row| row[:x] * 2}
      b = Namo.new([{x: 1}, {x: 2}])
      b[:tripled] = proc{|row| row[:x] * 3}
      _(a.eql?(b)).must_equal false
    end

    it "is false across different classes" do
      subclass = Class.new(Namo)
      a = Namo.new([{x: 1}, {x: 2}])
      b = subclass.new([{x: 1}, {x: 2}])
      _(a.eql?(b)).must_equal false
    end
  end

  describe "#hash" do
    it "is equal for set-equal Namos" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 2}, {x: 1}])
      _(a.hash).must_equal b.hash
    end

    it "differs when formula names differ" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 1}, {x: 2}])
      b[:y] = proc{|row| row[:x] * 2}
      _(a.hash).wont_equal b.hash
    end

    it "is equal when formula names match, regardless of proc identity" do
      a = Namo.new([{x: 1}, {x: 2}])
      a[:y] = proc{|row| row[:x] * 2}
      b = Namo.new([{x: 1}, {x: 2}])
      b[:y] = proc{|row| row[:x] * 2}
      _(a.hash).must_equal b.hash
    end

    it "differs across classes" do
      subclass = Class.new(Namo)
      a = Namo.new([{x: 1}, {x: 2}])
      b = subclass.new([{x: 1}, {x: 2}])
      _(a.hash).wont_equal b.hash
    end

    it "makes Namos usable as Hash keys" do
      a = Namo.new([{x: 1}, {x: 2}])
      b = Namo.new([{x: 2}, {x: 1}])
      h = {a => 'first'}
      _(h[b]).must_equal 'first'
    end
  end

  describe "#<, #<=, #>, #>=" do
    let(:small) { Namo.new([{x: 1}, {x: 2}]) }
    let(:large) { Namo.new([{x: 1}, {x: 2}, {x: 3}]) }
    let(:disjoint) { Namo.new([{x: 4}, {x: 5}]) }

    it "recognises proper subset" do
      _(small < large).must_equal true
      _(small <= large).must_equal true
      _(large > small).must_equal true
      _(large >= small).must_equal true
    end

    it "treats equal sets as <= and >= but not < or >" do
      copy = Namo.new([{x: 2}, {x: 1}])
      _(small <= copy).must_equal true
      _(small >= copy).must_equal true
      _(small < copy).must_equal false
      _(small > copy).must_equal false
    end

    it "treats disjoint sets as neither subset nor superset" do
      _(small <= disjoint).must_equal false
      _(small >= disjoint).must_equal false
      _(small < disjoint).must_equal false
      _(small > disjoint).must_equal false
    end

    it "is multiset-aware: a single row is a proper subset of two of the same row" do
      one = Namo.new([{x: 1}])
      two = Namo.new([{x: 1}, {x: 1}])
      _(one < two).must_equal true
      _(one <= two).must_equal true
      _(two <= one).must_equal false
      _(two < one).must_equal false
    end

    it "raises ArgumentError on mismatched dimensions" do
      other = Namo.new([{y: 1}])
      _ { small < other }.must_raise ArgumentError
      _ { small <= other }.must_raise ArgumentError
      _ { small > other }.must_raise ArgumentError
      _ { small >= other }.must_raise ArgumentError
    end

    it "raises TypeError on non-Namo" do
      _ { small < [{x: 1}] }.must_raise TypeError
      _ { small <= 'string' }.must_raise TypeError
      _ { small > nil }.must_raise TypeError
      _ { small >= 42 }.must_raise TypeError
    end
  end

  describe "#equal?" do
    it "is false for distinct objects" do
      a = Namo.new([{x: 1}])
      b = Namo.new([{x: 1}])
      _(a.equal?(b)).must_equal false
    end

    it "is true for the same object" do
      a = Namo.new([{x: 1}])
      _(a.equal?(a)).must_equal true
    end
  end

  describe "dimension-mismatch error message" do
    it "names both dimension lists" do
      a = Namo.new([{x: 1}])
      b = Namo.new([{y: 1}])
      err = _ { a + b }.must_raise ArgumentError
      _(err.message).must_match(/dimensions don't match/)
      _(err.message).must_match(/\[:x\]/)
      _(err.message).must_match(/\[:y\]/)
    end
  end

  describe "non-Namo comparison error message" do
    it "names the offending class" do
      a = Namo.new([{x: 1}])
      err = _ { a < 'string' }.must_raise TypeError
      _(err.message).must_match(/can't compare Namo with/)
      _(err.message).must_match(/String/)
    end
  end

  describe "non-Namo set operation error message" do
    it "raises TypeError on non-Namo for #+, #-, #&, #|, #^" do
      a = Namo.new([{x: 1}])
      _ { a + [{x: 1}] }.must_raise TypeError
      _ { a - 'string' }.must_raise TypeError
      _ { a & nil }.must_raise TypeError
      _ { a | 42 }.must_raise TypeError
      _ { a ^ :symbol }.must_raise TypeError
    end

    it "names the offending class" do
      a = Namo.new([{x: 1}])
      err = _ { a + 'string' }.must_raise TypeError
      _(err.message).must_match(/can't compare Namo with/)
      _(err.message).must_match(/String/)
    end
  end

  describe "#to_a" do
    it "returns the data as an array of hashes" do
      _(sales.to_a).must_equal sample_data
    end
  end
end
