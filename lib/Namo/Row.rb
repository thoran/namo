# Namo/Row.rb
# Namo::Row

class Namo
  class Row
    def [](name, *arguments)
      raise_unless_expected_arguments(name, arguments)
      if @formulae.key?(name)
        @formulae.derive(name, self, @namo, *arguments)
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

    def expected_argument_counts(name)
      return [0, 0] unless @formulae.key?(name)
      count = @formulae.required_parameter_count(name)
      return [0, 0] unless count >= 2
      minimum = count - 2
      maximum = @formulae[name].arity >= 0 ? minimum : nil
      [minimum, maximum]
    end

    def raise_unless_expected_arguments(name, arguments)
      minimum, maximum = expected_argument_counts(name)
      return if arguments.length >= minimum && (maximum.nil? || arguments.length <= maximum)
      expected = maximum.nil? ? "#{minimum}+" : minimum.to_s
      raise ArgumentError, "wrong number of arguments for #{name.inspect} (given #{arguments.length}, expected #{expected})"
    end
  end
end
