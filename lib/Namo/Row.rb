# Namo/Row.rb
# Namo::Row

class Namo
  class Row
    def [](name, *arguments)
      raise_unless_expected_arguments(name, arguments)
      if @formulae.key?(name)
        formula = @formulae[name]
        if collection_scoped?(formula)
          raise_unless_namo_context(name)
          formula.call(self, @namo, *arguments)
        else
          formula.call(self)
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

    def collection_scoped?(formula)
      required_parameter_count(formula) >= 2
    end

    def required_parameter_count(formula)
      formula.arity >= 0 ? formula.arity : -formula.arity - 1
    end

    def expected_argument_counts(name)
      formula = @formulae[name]
      return [0, 0] unless formula && collection_scoped?(formula)
      minimum = required_parameter_count(formula) - 2
      maximum = formula.arity >= 0 ? minimum : nil
      [minimum, maximum]
    end

    def raise_unless_expected_arguments(name, arguments)
      minimum, maximum = expected_argument_counts(name)
      return if arguments.length >= minimum && (maximum.nil? || arguments.length <= maximum)
      expected = maximum.nil? ? "#{minimum}+" : minimum.to_s
      raise ArgumentError, "wrong number of arguments for #{name.inspect} (given #{arguments.length}, expected #{expected})"
    end

    def raise_unless_namo_context(name)
      unless @namo
        raise ArgumentError, "collection-scoped formula #{name.inspect} requires a Namo context, but this Row has none"
      end
    end
  end
end
