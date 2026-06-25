# Namo/Formulae.rb
# Namo::Formulae

class Namo
  class Formulae
    include Enumerable

    def [](name)
      @store[name]
    end

    def []=(name, callable)
      @store[name] = callable
    end

    def keys
      @store.keys
    end

    def key?(name)
      @store.key?(name)
    end

    def empty?
      @store.empty?
    end

    def each(&block)
      return enum_for(:each) unless block_given?
      @store.each(&block)
    end

    def delete(name)
      @store.delete(name)
    end

    def merge(other)
      self.class.new(@store.merge(other.to_h))
    end

    def reject(&block)
      self.class.new(@store.reject(&block))
    end

    def dup
      self.class.new(@store.dup)
    end

    def to_h
      @store.dup
    end

    def ==(other)
      other.is_a?(Formulae) && keys.sort == other.keys.sort
    end

    def eql?(other)
      self == other
    end

    def hash
      keys.sort.hash
    end

    private

    def initialize(store = {})
      @store = store
    end
  end
end
