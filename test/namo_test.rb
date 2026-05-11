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

  describe "#dimensions" do
    it "infers dimensions from hash keys" do
      _(sales.dimensions).must_equal [:product, :quarter, :price, :quantity]
    end
  end

  describe "#coordinates" do
    it "extracts unique values for each dimension" do
      _(sales.coordinates).must_equal ({
        product: ['Widget', 'Gadget'],
        quarter: ['Q1', 'Q2'],
        price: [10.0, 25.0],
        quantity: [100, 150, 40, 60]
      })
      _(sales.coordinates[:product]).must_equal ['Widget', 'Gadget']
      _(sales.coordinates[:quarter]).must_equal ['Q1', 'Q2']
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
