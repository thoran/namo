# namo.rb
# Namo

class Namo
  include Enumerable

  class Row
    def [](name)
      if @formulae.key?(name)
        @formulae[name].call(self)
      else
        @row[name]
      end
    end

    def match?(selections)
      selections.all? do |dimension, coordinate|
        case coordinate
        when Array, Range
          coordinate.include?(self[dimension])
        else
          self[dimension] == coordinate
        end
      end
    end

    def to_h
      @row
    end

    private

    def initialize(row, formulae)
      @row = row
      @formulae = formulae
    end
  end

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
    data = (
      if names.any?
        rows.map do |row|
          names.each_with_object({}){|name, hash| hash[name] = row[name]}
        end
      else
        rows.map(&:to_h)
      end
    )
    self.class.new(data, formulae: @formulae.dup)
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
