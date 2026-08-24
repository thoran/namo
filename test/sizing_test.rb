# test/sizing_test.rb

require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../lib/namo'

# script/sizing produces the figures in ROADMAP.md's "What size it is for".  A
# measurement whose script has rotted is a measurement nobody can repeat, which is
# the condition the script exists to end — so assert it still runs, at sizes small
# enough not to make the suite a benchmark.

describe 'script/sizing' do
  def sizing(*arguments)
    root = File.expand_path('..', __dir__)
    IO.popen([File.join(root, 'script', 'sizing'), *arguments],
      chdir: root, err: [:child, :out]){|io| io.read}
  end

  it "reports a row per size asked for" do
    output = sizing('2000', '4000')
    _($?.success?).must_equal true
    _(output).must_match(/^\| 2,000 \| \d+ ms \|/)
    _(output).must_match(/^\| 4,000 \| \d+ ms \|/)
  end

  it "renders as the table the ROADMAP carries" do
    _(sizing('2000').lines.first).must_equal "| rows | group_by | per row | bytes/row |\n"
  end

  it "refuses a size it cannot measure" do
    sizing('0')
    _($?.success?).must_equal false
  end

  it "needs nothing but the gem's own dependencies" do
    root = File.expand_path('..', __dir__)
    output = IO.popen({'RUBYLIB' => nil}, [File.join(root, 'script', 'sizing'), '2000'],
      chdir: root, err: [:child, :out]){|io| io.read}
    _(output).wont_match(/LoadError/)
  end
end
