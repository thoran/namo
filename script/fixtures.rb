# script/fixtures.rb
# Fixtures

# 20260823
# 0.0.0

# The data script/demo shows and script/console hands you, in one place so the
# two cannot drift.  They are held as source text rather than as objects: the
# demo prints these lines before evaluating them, so what the audience reads and
# what runs are necessarily the same string, and the console evaluates the same
# string to arrive at the same names.

module Fixtures
  module_function

  def sales
    "[
    {product: 'Widget', quarter: 'Q1', price: 10.0, quantity: 100},
    {product: 'Widget', quarter: 'Q2', price: 10.0, quantity: 150},
    {product: 'Gadget', quarter: 'Q1', price: 25.0, quantity: 90},
    {product: 'Gadget', quarter: 'Q2', price: 25.0, quantity: 80}]"
  end

  def revenue
    'proc{|row| row[:price] * row[:quantity]}'
  end

  def symbols
    "[{symbol: 'BHP'}, {symbol: 'RIO'}]"
  end

  def quarters
    "[{quarter: 'Q1'}, {quarter: 'Q2'}]"
  end
end
