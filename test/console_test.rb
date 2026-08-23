# test/console_test.rb

require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../lib/namo'
require_relative '../script/fixtures'

# script/console exists so that a question asked at a prompt is asked of the same
# data the demo put on the screen.  That is only true while both read
# script/fixtures.rb, so what is worth asserting is the agreement rather than the
# session: the names it defines, and that they hold what the fixtures say.

describe 'script/console' do
  def console(*expressions)
    root = File.expand_path('..', __dir__)
    IO.popen([File.join(root, 'script', 'console'), '--prompt', 'simple'],
      'r+', chdir: root, err: [:child, :out]) do |io|
      io.puts(expressions, 'exit')
      io.close_write
      io.read
    end
  end

  it "defines the names it says it does" do
    output = console('[sales, symbols, quarters].map{|n| n.class}.inspect')
    _(output).must_match(/\[Namo, Namo, Namo\]/)
  end

  it "gives sales the revenue formula" do
    _(console('sales.derived_dimensions.inspect')).must_match(/\[:revenue\]/)
  end

  it "holds what the fixtures hold, so it cannot drift from the demo" do
    expected = eval(Fixtures.sales)
    _(console('sales.to_a == ' + expected.inspect)).must_match(/true/)
  end

  it "starts without echoing its own source" do
    _(console('1')).wont_match(/binding\.irb/)
  end
end
