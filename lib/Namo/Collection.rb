# Namo/Collection.rb
# Namo::Collection

class Namo
  class Collection < Namo
    attr_reader :members

    def <<(*members)
      members.flatten.each do |member|
        @members.reject!{|existing| existing.name == member.name} unless member.name.nil?
        @members << member
      end
      @data = detail.data
      self
    end

    def find(name)
      @members.find{|member| member.name == name} unless name.nil?
    end

    def summary(dimension, by: :member, reducer: :sum)
      rows = @members.map do |member|
        {by => member.name, dimension => member.values(dimension).send(reducer)}
      end
      Namo.new(rows)
    end

    def detail(by: :member)
      rows = @members.flat_map do |member|
        member.data.map{|row| row.key?(by) ? row : row.merge(by => member.name)}
      end
      Namo.new(rows)
    end

    def as_summary(dimension, by: :member, reducer: :sum)
      @data = summary(dimension, by: by, reducer: reducer).data
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
  end
end
