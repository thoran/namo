# Symbol.rb
# Symbol#-@

class Symbol
  def -@
    Namo::NegatedDimension.new(self)
  end
end
