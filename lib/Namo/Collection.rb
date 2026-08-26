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
      rows = (
        if block
          @members.map{|member| block.call(member).merge(by => member.name)}
        else
          @members.map{|member| {by => member.name, dimension => member.values(dimension).send(reducer)}}
        end
      )
      Namo.new(rows)
    end

    def detail(positional_by = nil, by: :member)
      by = positional_by || by
      rows = (
        @members.flat_map do |member|
          member.data.map{|row| row.key?(by) ? row : row.merge(by => member.name)}
        end
      )
      Namo.new(rows, formulae: member_formulae)
    end

    def as_summary(dimension = nil, by: :member, reducer: :sum, &block)
      @data = summary(dimension, by: by, reducer: reducer, &block).data
      self
    end

    def as_detail(positional_by = nil, by: :member)
      by = positional_by || by
      view = detail(by)
      @data = view.data
      @formulae = @formulae.merge(view.formulae)
      self
    end

    # The members are the substance, so they are what is rendered.  A list of names
    # and a row count described the derived view and called it the object, and the
    # list was unbounded besides: 2,641 members emitted 22,704 characters on one
    # line, which is the failure INSPECTED_ROWS was introduced to end.
    #
    # That budget is now spread across the members shown rather than spent on one
    # member's rows: one member renders ten of its rows, ten members render one
    # apiece, five render two.
    def inspect
      "#<#{self.class}#{inspected_name} #{inspected_members} #{@data.length} rows#{inspected_derived}>"
    end

    private

    # The members' formulae, folded in member order so that a later member wins a
    # name collision, as a later member wins a collision of names in <<.  The
    # detail view is the members' rows, so it must be able to answer what the
    # members can answer of them; group_by hands every member the same formulae,
    # so only an assembled Collection can have members which disagree.
    def member_formulae
      @members.map(&:formulae).reduce(Formulae.new){|merged, formulae| merged.merge(formulae)}
    end

    def inspected_members
      return '[]' if @members.empty?
      shown = [@members.length, INSPECTED_ROWS].min
      each = [INSPECTED_ROWS / shown, 1].max
      rendered = @members.first(shown).map{|member| "  #{member.name.inspect} => #{inspected_member(member, each)}"}.join(",\n")
      rendered += "\n  ... #{@members.length - shown} more members" if @members.length > shown
      "[\n#{rendered}\n]"
    end

    # A member showing a single row is rendered on one line: three lines of brackets
    # to carry one row is the shape a Collection of many members lands in, and it
    # cost more than the rows did.  On what is rendered rather than on the limit,
    # so a member holding one row of a larger allowance reads the same way.
    def inspected_member(member, limit)
      rows, remainder, unshown = member.inspected_data(limit)
      elided = remainder > 0
      suffix = inspected_derived_names(unshown)
      if rows.length == 1
        "[#{rows.join}#{elided ? ", ... #{remainder} more rows" : ''}]#{suffix}"
      else
        body = rows.map{|row| "    #{row}"}.join(",\n")
        body += "\n    ... #{remainder} more rows" if elided
        "[\n#{body}\n  ]#{suffix}"
      end
    end

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
