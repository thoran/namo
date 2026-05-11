# namo.rb
# Namo

require_relative './Namo/NegatedDimension'
require_relative './Namo/Row'
require_relative './Symbol'

class Namo
  include Enumerable

  attr_accessor :data
  attr_accessor :formulae

  def dimensions
    @dimensions ||= @data.first.keys
  end

  def coordinates
    @coordinates ||= (
      dimensions.each_with_object({}) do |dimension, hash|
        hash[dimension] = @data.map{|row| row[dimension]}.uniq
      end
    )
  end

  def [](*names, **selections)
    rows = selections.any? ? select{|row| row.match?(selections)} : entries
    negated, positive = names.partition{|n| n.is_a?(NegatedDimension)}
    if negated.any? && positive.any?
      raise ArgumentError, "cannot mix projection and contraction in a single call"
    end
    projected = (
      if negated.any?
        excluded = negated.map(&:name)
        kept = dimensions - excluded
        rows.map do |row|
          kept.each_with_object({}){|name, hash| hash[name] = row[name]}
        end
      elsif positive.any?
        rows.map do |row|
          positive.each_with_object({}){|name, hash| hash[name] = row[name]}
        end
      else
        rows.map(&:to_h)
      end
    )
    self.class.new(projected, formulae: @formulae.dup)
  end

  def []=(name, proc)
    @formulae[name] = proc
  end

  def each(&block)
    return enum_for(:each) unless block_given?
    @data.each{|row_data| block.call(Row.new(row_data, @formulae))}
  end

  def +(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    self.class.new(@data + other.data, formulae: other.formulae.merge(@formulae))
  end

  def -(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    self.class.new(@data - other.data, formulae: @formulae.dup)
  end

  def &(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    self.class.new(@data & other.data, formulae: @formulae.dup)
  end

  def |(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    self.class.new((@data | other.data), formulae: other.formulae.merge(@formulae))
  end

  def ^(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    self.class.new((@data - other.data) + (other.data - @data), formulae: other.formulae.merge(@formulae))
  end

  def ==(other)
    return false unless other.is_a?(Namo)
    canonical_data == other.canonical_data
  end

  def ===(other)
    return false unless other.is_a?(Namo)
    dimensions.sort == other.dimensions.sort &&
      @formulae.keys.sort == other.formulae.keys.sort
  end

  def eql?(other)
    self.class == other.class &&
      canonical_data == other.canonical_data &&
      @formulae.keys.sort == other.formulae.keys.sort
  end

  def hash
    [self.class, canonical_data, @formulae.keys.sort].hash
  end

  def <(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    proper_subset_of_rows?(other)
  end

  def <=(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    subset_of_rows?(other)
  end

  def >(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    other.proper_subset_of_rows?(self)
  end

  def >=(other)
    raise_unless_namo(other)
    raise_unless_matching_dimensions(other)
    other.subset_of_rows?(self)
  end

  def to_a
    @data.map do |row|
      row.keys.each_with_object({}) do |key, hash|
        hash[key] = row[key]
      end
    end
  end

  protected

  def canonical_data
    @data.sort_by{|row| row.values_at(*dimensions.sort)}
  end

  def subset_of_rows?(other)
    self_counts = canonical_data.tally
    other_counts = other.canonical_data.tally
    self_counts.all?{|row, count| (other_counts[row] || 0) >= count}
  end

  def proper_subset_of_rows?(other)
    subset_of_rows?(other) && self != other
  end

  private

  def raise_unless_namo(other)
    unless other.is_a?(Namo)
      raise TypeError, "can't compare Namo with #{other.class}"
    end
  end

  def raise_unless_matching_dimensions(other)
    unless dimensions == other.dimensions
      raise ArgumentError, "dimensions don't match: #{dimensions} vs #{other.dimensions}"
    end
  end

  def initialize(data = nil, formulae: {})
    @data = data
    @formulae = formulae
  end
end
