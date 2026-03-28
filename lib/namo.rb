# namo.rb
# Namo

class Namo
  class Row
    def [](name)
      if @formulae.key?(name)
        @formulae[name].call(self)
      else
        @row[name]
      end
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
    data = selections.any? ? select_rows(selections) : @data
    if names.any?
      data = data.map do |row_data|
        row = Row.new(row_data, @formulae)
        names.each_with_object({}){|name, hash| hash[name] = row[name]}
      end
    end
    self.class.new(data, formulae: @formulae.dup)
  end

  def []=(name, proc)
    @formulae[name] = proc
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

  def select_rows(selections)
    @data.select do |row|
      selections.all? do |dimension, coordinate|
        case coordinate
        when Array, Range
          coordinate.include?(row[dimension])
        else
          row[dimension] == coordinate
        end
      end
    end
  end
end
