require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../../lib/namo'

class Array
  def mean
    sum.to_f / size
  end
end unless [].respond_to?(:mean)

class SubAssembly < Namo; end

class Car < Namo::Collection
  def summary(dimension, by: :assembly, reducer: :sum)
    super
  end

  def detail(by: :assembly)
    super
  end
end

describe Namo::Collection do
  let(:powertrain) do
    SubAssembly.new(name: :powertrain, data: [
      {component: 'engine', weight: 200, cost: 50000},
      {component: 'gearbox', weight: 80, cost: 20000},
    ])
  end

  let(:chassis) do
    SubAssembly.new(name: :chassis, data: [{component: 'frame', weight: 150, cost: 30000}])
  end

  let(:body) do
    SubAssembly.new(name: :body, data: [{component: 'panels', weight: 60, cost: 15000}])
  end

  let(:wheels) do
    SubAssembly.new(name: :wheels, data: [{component: 'tyres', weight: 40, cost: 8000}])
  end

  let(:collection) do
    Namo::Collection.new.tap{|c| c << [powertrain, chassis, body]}
  end

  describe "construction" do
    it "starts with empty members" do
      _(Namo::Collection.new.members).must_equal []
    end
  end

  describe "lazy detail materialisation" do
    it "materialises detail on a bare row-operation without a prior as_detail" do
      _(collection.values(:weight)).must_equal [200, 80, 150, 60]
    end

    it "supports selection against the materialised detail" do
      _(collection[component: 'engine'].values(:component)).must_equal ['engine']
    end

    it "reflects a newly added member on the next operation" do
      before = collection.values(:weight)
      collection << wheels
      _(collection.values(:weight)).must_equal before + [40]
    end
  end

  describe "#<<" do
    it "adds a member" do
      collection = Namo::Collection.new
      collection << powertrain
      _(collection.members.size).must_equal 1
      _(collection.find(:powertrain)).must_be_same_as powertrain
    end

    it "replaces a member with a colliding name (last-write-wins)" do
      collection = Namo::Collection.new
      collection << powertrain
      replacement = SubAssembly.new(name: :powertrain, data: [{component: 'hybrid', weight: 250, cost: 70000}])
      collection << replacement
      _(collection.members.size).must_equal 1
      _(collection.find(:powertrain)).must_be_same_as replacement
    end

    it "adds each member from an array" do
      collection = Namo::Collection.new
      collection << [powertrain, chassis]
      _(collection.members.size).must_equal 2
    end

    it "appends an unnamed member, which is unfindable by name" do
      collection = Namo::Collection.new
      collection << SubAssembly.new(data: [{component: 'misc', weight: 5, cost: 100}])
      collection << SubAssembly.new(data: [{component: 'other', weight: 6, cost: 200}])
      _(collection.members.size).must_equal 2
    end

    it "returns self" do
      collection = Namo::Collection.new
      _(collection << powertrain).must_be_same_as collection
    end
  end

  describe "#find" do
    it "returns the member with the given name" do
      _(collection.find(:chassis)).must_be_same_as chassis
    end

    it "returns nil for an absent name" do
      _(collection.find(:engine)).must_be_nil
    end

    it "returns nil for find(nil)" do
      _(collection.find(nil)).must_be_nil
    end

    it "never matches an unnamed member" do
      collection = Namo::Collection.new
      collection << SubAssembly.new(data: [{component: 'misc', weight: 5, cost: 100}])
      _(collection.find(nil)).must_be_nil
    end
  end

  describe "#summary" do
    it "reduces each member to a labelled row" do
      summary = collection.summary(:weight)
      _(summary.values(:member)).must_equal [:powertrain, :chassis, :body]
      _(summary.values(:weight)).must_equal [280, 150, 60]
    end

    it "labels with a custom by dimension" do
      summary = collection.summary(:weight, by: :assembly)
      _(summary.values(:assembly)).must_equal [:powertrain, :chassis, :body]
    end

    it "reduces with a custom reducer" do
      summary = collection.summary(:weight, reducer: :mean)
      _(summary.values(:weight)).must_equal [140.0, 150.0, 60.0]
    end

    it "is non-mutating — leaves the collection's data untouched" do
      collection.summary(:weight)
      _(collection.values(:weight)).must_equal [200, 80, 150, 60]
    end
  end

  describe "#detail" do
    it "returns a plain Namo" do
      _(collection.detail).must_be_instance_of Namo
    end

    it "unions the members' rows, injecting the by dimension when absent" do
      detail = collection.detail
      _(detail.values(:member)).must_equal [:powertrain, :powertrain, :chassis, :body]
      _(detail.values(:weight)).must_equal [200, 80, 150, 60]
    end

    it "does not inject when the by dimension is already present" do
      collection = Namo::Collection.new
      collection << SubAssembly.new(name: :ignored, data: [{member: :preexisting, weight: 5}])
      _(collection.detail.values(:member)).must_equal [:preexisting]
    end

    it "is non-mutating — leaves the collection's data untouched" do
      collection.detail(by: :assembly)
      _(collection.dimensions).wont_include :assembly
    end
  end

  describe "live recomputation (no memoisation in 1.x)" do
    it "reflects a mutation on the next detail call" do
      before = collection.detail.values(:weight).size
      collection << wheels
      _(collection.detail.values(:weight).size).must_equal before + 1
    end

    it "reflects a mutation on the next summary call" do
      collection << wheels
      _(collection.summary(:weight).values(:member)).must_equal [:powertrain, :chassis, :body, :wheels]
    end
  end

  describe "#as_summary / #as_detail" do
    it "as_summary sets the data to the summary view and returns self" do
      result = collection.as_summary(:weight)
      _(result).must_be_same_as collection
      _(collection.values(:weight)).must_equal [280, 150, 60]
    end

    it "as_detail sets the data to the detail view and returns self" do
      collection.as_summary(:weight)
      result = collection.as_detail
      _(result).must_be_same_as collection
      _(collection.values(:weight)).must_equal [200, 80, 150, 60]
    end

    it "exposes the summary's columns in dimensions immediately after as_summary" do
      collection.as_summary(:weight)
      _(collection.dimensions.sort).must_equal [:member, :weight].sort
    end
  end

  describe "as_* view lifetime (rebuild-on-<<: persists until the next <<)" do
    it "keeps the summary view across a bare row-operation" do
      collection.as_summary(:weight)
      _(collection.values(:weight)).must_equal [280, 150, 60]
      _(collection[member: :powertrain].values(:weight)).must_equal [280]
    end

    it "re-materialises detail on the next <<" do
      collection.as_summary(:weight)
      collection << wheels
      _(collection.values(:weight)).must_equal [200, 80, 150, 60, 40]
    end
  end

  describe "assembly round-trip" do
    it "injects :assembly via as_detail and retains it through a later << and as_detail" do
      collection.as_detail(:assembly)
      _(collection.dimensions).must_include :assembly
      _(collection.coordinates(:assembly)).must_equal [:powertrain, :chassis, :body]
      collection << wheels
      collection.as_detail(:assembly)
      _(collection.dimensions).must_include :assembly
      _(collection.coordinates(:assembly)).must_equal [:powertrain, :chassis, :body, :wheels]
    end

    it "removes :assembly only by explicit contraction" do
      collection.as_detail(:assembly)
      contracted = collection[-:assembly]
      _(contracted.dimensions).wont_include :assembly
    end
  end

  describe "subclass with a default by:" do
    let(:car) do
      Car.new.tap{|c| c << [powertrain, chassis, body]}
    end

    it "uses the subclass default :assembly for summary" do
      _(car.summary(:weight).values(:assembly)).must_equal [:powertrain, :chassis, :body]
    end

    it "uses the subclass default :assembly for detail" do
      _(car.detail.values(:assembly)).must_equal [:powertrain, :powertrain, :chassis, :body]
    end
  end
end
