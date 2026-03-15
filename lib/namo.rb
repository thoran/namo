# namo.rb
# Namo

class Namo
  def dimensions
    @dimensions ||= @data.first.keys
  end

  def coordinates
    @coordinates ||= (
      dimensions.each_with_object({}) do |dimension, hash|
        hash[dimension] = @data.map{|row| row[dimension]}.uniq
      end
    )
  end

  def [](**selections)
    selected = (
      @data.select do |row|
        selections.all? do |dimension, coordinate|
          case coordinate
          when Array, Range
            coordinate.include?(row[dimension])
          else
            coordinate == row[dimension]
          end
        end
      end
    )
    self.class.new(selected)
  end

  private

  def initialize(data)
    @data = data
  end
end
