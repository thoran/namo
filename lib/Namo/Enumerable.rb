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
      self.class.new(@data.select{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end
    alias_method :filter, :select
    alias_method :find_all, :select

    def reject(&block)
      self.class.new(@data.reject{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def sort_by(&block)
      self.class.new(@data.sort_by{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def first(n = nil)
      if n
        self.class.new(@data.first(n), formulae: @formulae.dup)
      else
        @data.first ? Row.new(@data.first, @formulae, self) : nil
      end
    end

    def last(n = nil)
      if n
        self.class.new(@data.last(n), formulae: @formulae.dup)
      else
        @data.last ? Row.new(@data.last, @formulae, self) : nil
      end
    end

    def take(n)
      self.class.new(@data.take(n), formulae: @formulae.dup)
    end

    def drop(n)
      self.class.new(@data.drop(n), formulae: @formulae.dup)
    end

    def take_while(&block)
      self.class.new(@data.take_while{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def drop_while(&block)
      self.class.new(@data.drop_while{|row| block.call(Row.new(row, @formulae, self))}, formulae: @formulae.dup)
    end

    def uniq(&block)
      rows = block ? @data.uniq{|row| block.call(Row.new(row, @formulae, self))} : @data.uniq
      self.class.new(rows, formulae: @formulae.dup)
    end

    def partition(&block)
      matches, non_matches = @data.partition{|row| block.call(Row.new(row, @formulae, self))}
      [
        self.class.new(matches, formulae: @formulae.dup),
        self.class.new(non_matches, formulae: @formulae.dup),
      ]
    end
  end
end
