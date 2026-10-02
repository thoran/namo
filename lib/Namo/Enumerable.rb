# Namo/Enumerable.rb
# Namo::Enumerable

class Namo
  module Enumerable
    include ::Enumerable

    def each(&block)
      return enum_for(:each) unless block_given?
      @data.each{|row_data| block.call(Row.new(row_data, @formulae, self))}
    end

    def select(&block)
      return_class.new(@data.select{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end
    alias_method :filter, :select
    alias_method :find_all, :select

    def reject(&block)
      return_class.new(@data.reject{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def sort_by(&block)
      return_class.new(@data.sort_by{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def first(n = nil)
      if n
        return_class.new(@data.first(n), formulae: @formulae.dup)
      else
        @data.first ? Row.new(@data.first, @formulae, self) : nil
      end
    end

    def last(n = nil)
      if n
        return_class.new(@data.last(n), formulae: @formulae.dup)
      else
        @data.last ? Row.new(@data.last, @formulae, self) : nil
      end
    end

    def take(n)
      return_class.new(@data.take(n), formulae: @formulae.dup)
    end

    def drop(n)
      return_class.new(@data.drop(n), formulae: @formulae.dup)
    end

    def take_while(&block)
      return_class.new(@data.take_while{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def drop_while(&block)
      return_class.new(@data.drop_while{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def uniq(&block)
      rows = block ? @data.uniq{|row| block.call(Row.new(row, @formulae, self))} : @data.uniq
      return_class.new(rows, formulae: @formulae.dup)
    end

    def partition(&block)
      matches, non_matches = @data.partition{|row| block.call(Row.new(row, @formulae, self))}
      [
        return_class.new(matches, formulae: @formulae.dup),
        return_class.new(non_matches, formulae: @formulae.dup),
      ]
    end

    # The block form is the call Enumerable#group_by makes, and it is not
    # implemented: the groups a computed key makes have no dimension to
    # round-trip through on as_detail.  The raise says so and names the way to
    # partition by one, where Ruby's arity error said only that the count was
    # wrong; a call with no dimension at all gets its own sentence.
    def group_by(dimension = nil)
      if block_given?
        raise ArgumentError, 'the block form of group_by is not implemented; entries.group_by{|row| ...} partitions by a computed key'
      end
      raise ArgumentError, 'group_by needs a dimension' if dimension.nil?
      collection = Collection.new
      source = derived_dimensions.include?(dimension) ? self[*data_dimensions, dimension] : self
      members = (
        source.data.group_by{|row_data| row_data[dimension]}.map do |value, rows|
          return_class.new(rows, formulae: source.formulae.dup, name: value)
        end
      )
      collection << members
    end
  end
end
