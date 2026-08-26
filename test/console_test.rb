# test/console_test.rb

require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../lib/namo'

# bin/console is the conventional gem prompt: irb with the library loaded and
# nothing else.  It held the demo's fixtures until 20260826, so that a question
# asked here was asked of the data the demo had shown — a guarantee the demo's
# own `i` now keeps better, opening irb on the binding the run is using rather
# than on a second process holding equal values.
#
# What is left to assert is that it starts, that Namo is there, and that it needs
# nothing off the load path.

describe 'bin/console' do
  def console(*expressions)
    root = File.expand_path('..', __dir__)
    IO.popen([File.join(root, 'bin', 'console'), '--prompt', 'simple'],
      'r+', chdir: root, err: [:child, :out]) do |io|
      io.puts(expressions, 'exit')
      io.close_write
      io.read
    end
  end

  it "starts with Namo loaded" do
    _(console('Namo.new([{a: 1}]).dimensions.inspect')).must_match(/\[:a\]/)
  end

  it "starts without echoing its own source" do
    _(console('1')).wont_match(/IRB\.start/)
  end

  it "needs nothing but the gem's own dependencies" do
    root = File.expand_path('..', __dir__)
    output = IO.popen({'RUBYLIB' => nil}, [File.join(root, 'bin', 'console'), '--prompt', 'simple'],
      'r+', chdir: root, err: [:child, :out]) do |io|
      io.puts('exit')
      io.close_write
      io.read
    end
    _(output).wont_match(/LoadError/)
  end
end
