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

    def ==(other)
      other.is_a?(Row) && @row == other.to_h
    end

    def eql?(other)
      other.is_a?(Row) && @row.eql?(other.to_h)
    end

    def hash
      @row.hash
    end

    def match?(selections)
      selections.all? do |dimension, coordinate|
        case coordinate
        when Array, Range
          coordinate.include?(self[dimension])
        when Proc
          coordinate.call(self[dimension])
        when Regexp
          coordinate.match?(self[dimension].to_s)
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
