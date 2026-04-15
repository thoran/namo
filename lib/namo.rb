# namo.rb
# Namo

require_relative 'Namo/NegatedDimension'
require_relative 'Namo/Row'
require_relative 'Symbol'

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

  def to_a
    @data.map do |row|
      row.keys.each_with_object({}) do |key, hash|
        hash[key] = row[key]
      end
    end
  end

  private

  def initialize(data = nil, formulae: {})
    @data = data
    @formulae = formulae
  end
end
