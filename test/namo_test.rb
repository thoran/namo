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

  describe "#to_a" do
    it "returns the data as an array of hashes" do
      _(sales.to_a).must_equal sample_data
    end
  end
end
