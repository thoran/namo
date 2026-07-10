# Namo/Collection.rb
# Namo::Collection

class Namo
  class Collection < Namo
    attr_reader :members

    def <<(*constituents)
      constituents.flatten.each do |constituent|
        case constituent
        when Namo then add_member(constituent)
        when Module then attach(constituent)
        when Hash, Row
          raise ArgumentError, "a Collection's rows come from its members; add a member (a named Namo), not a loose row"
        else raise TypeError, "can't append #{constituent.class} to a Collection"
        end
      end
      @data = detail.data
      self
    end

    def find(name)
      @members.find{|member| member.name == name} unless name.nil?
    end

    def summary(dimension = nil, by: :member, reducer: :sum, &block)
      raise ArgumentError, "summary needs a dimension or a block" unless dimension || block
      rows =
        if block
          @members.map{|member| block.call(member).merge(by => member.name)}
        else
          @members.map{|member| {by => member.name, dimension => member.values(dimension).send(reducer)}}
        end
      Namo.new(rows)
    end

    def detail(by: :member)
      rows = @members.flat_map do |member|
        member.data.map{|row| row.key?(by) ? row : row.merge(by => member.name)}
      end
      Namo.new(rows)
    end

    def as_summary(dimension = nil, by: :member, reducer: :sum, &block)
      @data = summary(dimension, by: by, reducer: reducer, &block).data
      self
    end

    def as_detail(by = :member)
      @data = detail(by: by).data
      self
    end

    private

    def initialize(positional_data = nil, data: [], formulae: {}, name: nil)
      @members = []
      super
    end

    def add_member(member)
      @members.reject!{|existing| existing.name == member.name} unless member.name.nil?
      @members << member
    end
  end
end
