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

    def derive(name, row, namo, *arguments)
      formula = self[name]
      if collection_scoped?(name)
        raise_unless_namo_context(name, namo)
        formula.call(row, namo, *arguments)
      else
        formula.call(row)
      end
    end

    def required_parameter_count(name)
      formula = self[name]
      formula.arity >= 0 ? formula.arity : -formula.arity - 1
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

    def collection_scoped?(name)
      required_parameter_count(name) >= 2
    end

    def raise_unless_namo_context(name, namo)
      unless namo
        raise ArgumentError, "collection-scoped formula #{name.inspect} requires a Namo context, but this Row has none"
      end
    end
  end
end
