# namo.rb
# Namo

require_relative './Namo/NegatedDimension'
require_relative './Namo/Formulary'
require_relative './Namo/Formulae'
require_relative './Namo/Row'
require_relative './Namo/Collection'
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
      materialisable_dimensions.each_with_object({}){|dim, hash| hash[dim] = values_for(dim)}
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
    carried = positive.any? ? @formulae.reject{|name, _| positive.include?(name)} : @formulae.dup
    self.class.new(projected, formulae: carried)
  end

  def []=(name, value)
    if value.respond_to?(:call)
      @data.each{|row| row.delete(name)} if @data.first&.key?(name)
      @formulae[name] = value
    else
      @formulae.delete(name)
      @data.each{|row| row[name] = value}
    end
  end

  def attach(modul)
    collisions = modul.public_instance_methods(false) & data_dimensions
    unless collisions.empty?
      raise ArgumentError, "formulary methods collide with data dimensions: #{collisions.inspect}"
    end
    @formulae.attach(modul)
    self
  end

  def <<(constituent)
    case constituent
    when Module then attach(constituent)
    when Row then add_row(constituent.to_h)
    when Hash then add_row(constituent)
    else raise TypeError, "can't append #{constituent.class} to a Namo; expected a Module (formulary), a Hash, or a Row"
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
    raise_unless_data_formula_exclusivity(other)
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
    raise_unless_data_formula_exclusivity(other)
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
    row_multiset == other.row_multiset
  end

  def ===(other)
    return false unless other.is_a?(Namo)
    dimensions.sort == other.dimensions.sort &&
      @formulae.keys.sort == other.formulae.keys.sort
  end

  def eql?(other)
    self.class == other.class &&
      row_multiset == other.row_multiset &&
      @formulae.keys.sort == other.formulae.keys.sort
  end

  def hash
    [self.class, row_multiset, @formulae.keys.sort].hash
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

  def row_multiset
    @data.tally
  end

  def subset_of_rows?(other)
    self_counts = row_multiset
    other_counts = other.row_multiset
    self_counts.all?{|row, count| (other_counts[row] || 0) >= count}
  end

  def proper_subset_of_rows?(other)
    subset_of_rows?(other) && self != other
  end

  private

  def initialize(positional_data = nil, data: [], formulae: {}, name: nil)
    @data = positional_data || data
    @formulae = formulae.is_a?(Formulae) ? formulae : Formulae.new(formulae)
    @name = name
    attach_included_formularies
  end

  def add_row(row)
    @data << row
    self
  end

  def attach_included_formularies
    self.class.ancestors.reverse.each do |modul|
      next if modul.is_a?(Class) || !modul.include?(Namo::Formulary)
      attach(modul)
    end
  end

  def values_for(dim)
    if data_dimensions.include?(dim)
      @data.map{|row_data| row_data[dim]}
    else
      @data.map{|row_data| Row.new(row_data, @formulae, self)[dim]}
    end
  end

  def materialisable_dimensions
    dimensions.reject{|dim| requires_arguments?(dim)}
  end

  def requires_arguments?(name)
    formula = @formulae[name]
    !!formula && required_parameter_count(formula) > 2
  end

  def required_parameter_count(formula)
    formula.arity >= 0 ? formula.arity : -formula.arity - 1
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

  def raise_unless_data_formula_exclusivity(other)
    collisions = (data_dimensions & other.derived_dimensions) | (derived_dimensions & other.data_dimensions)
    if collisions.any?
      raise ArgumentError, "name collision between data and formulae: #{collisions.inspect}"
    end
  end
end
