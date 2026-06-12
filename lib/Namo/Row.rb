# Namo/Row.rb
# Namo::Row

class Namo
  class Row
    def [](name)
      if @formulae.key?(name)
        case @formulae[name].arity
        when 2
          raise_unless_namo_context(name)
          @formulae[name].call(self, @namo)
        else
          @formulae[name].call(self)
        end
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

    def initialize(row, formulae, namo = nil)
      @row = row
      @formulae = formulae
      @namo = namo
    end

    def raise_unless_namo_context(name)
      unless @namo
        raise ArgumentError, "two-arity formula #{name.inspect} requires a Namo context, but this Row has none"
      end
    end
  end
end
