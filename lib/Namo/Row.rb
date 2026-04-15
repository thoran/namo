# Namo/Row.rb
# Namo::Row

class Namo
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
end
