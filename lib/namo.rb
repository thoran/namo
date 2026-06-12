# namo.rb
# Namo

require_relative './Namo/NegatedDimension'
require_relative './Namo/Row'
require_relative './Namo/Enumerable'
require_relative './Namo/VERSION'
require_relative './Symbol'

class Namo
  include Namo::Enumerable

  attr_accessor :data
  attr_accessor :formulae
  attr_accessor :name

  def dimensions
    data_dimensions + derived_dimensions
  end

  def data_dimensions
    @data.first&.keys || []
  end

  def derived_dimensions
    @formulae.keys
  end

  def values(*dims)
    if dims.empty?
      dimensions.each_with_object({}){|dim, hash| hash[dim] = values_for(dim)}
    elsif dims.length == 1
      values_for(dims.first)
    else
      dims.each_with_object({}){|dim, hash| hash[dim] = values_for(dim)}
    end
  end

  def coordinates(*dims)
    if dims.empty?
      values.transform_values(&:uniq)
    elsif dims.length == 1
      values(dims.first).uniq
    else
      dims.each_with_object({}){|dim, hash| hash[dim] = values(dim).uniq}
    end
  end

  def to_h
    values
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
        kept = data_dimensions - excluded
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

  def []=(name, value)
    case value
    when Proc
      @data.each{|row| row.delete(name)} if @data.first&.key?(name)
      @formulae[name] = value
    else
      @formulae.delete(name)
      @data.each{|row| row[name] = value}
    end
  end

  def +(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
    self.class.new(@data + other.data, formulae: other.formulae.merge(@formulae))
  end

  def -(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
    self.class.new(@data - other.data, formulae: @formulae.dup)
  end

  def &(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
    self.class.new(@data & other.data, formulae: @formulae.dup)
  end

  def |(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
    self.class.new((@data | other.data), formulae: other.formulae.merge(@formulae))
  end

  def ^(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
    self.class.new((@data - other.data) + (other.data - @data), formulae: other.formulae.merge(@formulae))
  end

  def *(other, &block)
    raise_unless_namo(other)
    raise_unless_shared_data_dimensions(other)
    shared = data_dimensions & other.data_dimensions
    combined_data = []
    @data.each do |left_row|
      matched = other.data.select{|right_row| shared.all?{|dim| left_row[dim] == right_row[dim]}}
      if block
        candidates = other.class.new(matched, formulae: other.formulae.dup)
        chosen = block.call(Row.new(left_row, @formulae, self), candidates)
        chosen.data.each{|right_row| combined_data << left_row.merge(right_row)}
      else
        matched.each{|right_row| combined_data << left_row.merge(right_row)}
      end
    end
    self.class.new(combined_data, formulae: other.formulae.merge(@formulae))
  end

  def **(other, &block)
    raise_unless_namo(other)
    raise_unless_disjoint_data_dimensions(other)
    combined_data = []
    @data.each do |left_row|
      if block
        candidates = other.class.new(other.data, formulae: other.formulae.dup)
        chosen = block.call(Row.new(left_row, @formulae, self), candidates)
        chosen.data.each{|right_row| combined_data << left_row.merge(right_row)}
      else
        other.data.each{|right_row| combined_data << left_row.merge(right_row)}
      end
    end
    self.class.new(combined_data, formulae: other.formulae.merge(@formulae))
  end

  def /(other)
    raise_unless_namo(other)
    kept = data_dimensions - other.data_dimensions
    projected = @data.map do |row|
      kept.each_with_object({}){|dim, hash| hash[dim] = row[dim]}
    end
    self.class.new(projected.uniq, formulae: @formulae.dup)
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
    raise_unless_matching_data_dimensions(other)
    proper_subset_of_rows?(other)
  end

  def <=(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
    subset_of_rows?(other)
  end

  def >(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
    other.proper_subset_of_rows?(self)
  end

  def >=(other)
    raise_unless_namo(other)
    raise_unless_matching_data_dimensions(other)
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
    @data.sort_by{|row| row.values_at(*data_dimensions.sort)}
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

  def initialize(positional_data = nil, data: [], formulae: {}, name: nil)
    @data = positional_data || data
    @formulae = formulae
    @name = name
  end

  def values_for(dim)
    if data_dimensions.include?(dim)
      @data.map{|row_data| row_data[dim]}
    else
      @data.map{|row_data| Row.new(row_data, @formulae, self)[dim]}
    end
  end

  def raise_unless_namo(other)
    unless other.is_a?(Namo)
      raise TypeError, "can't compare Namo with #{other.class}"
    end
  end

  def raise_unless_matching_data_dimensions(other)
    unless data_dimensions == other.data_dimensions
      raise ArgumentError, "dimensions don't match: #{data_dimensions} vs #{other.data_dimensions}"
    end
  end

  def raise_unless_shared_data_dimensions(other)
    if (data_dimensions & other.data_dimensions).empty?
      raise ArgumentError, "no shared dimensions, need to have shared dimensions: #{data_dimensions} vs #{other.data_dimensions}"
    end
  end

  def raise_unless_disjoint_data_dimensions(other)
    if (data_dimensions & other.data_dimensions).any?
      raise ArgumentError, "dimensions in common, need no common dimensions: #{data_dimensions} vs #{other.data_dimensions}"
    end
  end
end
