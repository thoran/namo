# test/namo_command_test.rb

require 'minitest/autorun'
require 'minitest-spec-context'

# bin/namo is the setup subcommand in the shape startor, shellac and mercurial use
# it: a predicate per prerequisite, an install which says so when there is nothing
# to do, and setup calling them in order.  What is worth asserting is the surface —
# that it reports rather than acts when everything is present, and that it refuses
# what it does not know — not that it can install Homebrew.

describe 'bin/namo' do
  def namo(*arguments)
    root = File.expand_path('..', __dir__)
    IO.popen([File.join(root, 'bin', 'namo'), *arguments],
      chdir: root, err: [:child, :out]){|io| io.read}
  end

  it "names its subcommands" do
    output = namo('--help')
    _(output).must_match(/setup/)
    _(output).must_match(/console/)
  end

  it "reports rather than acts where a gem is already there" do
    output = namo('setup')
    _($?.success?).must_equal true
    _(output).must_match(/namo is already installed!/)
    _(output).must_match(/measurand is already installed!/)
  end

  # install.sh is the half a Ruby script cannot do — Homebrew, and the Ruby the
  # script would be running on.  Its syntax is asserted and its body is not run:
  # a test which executed it on a machine lacking Homebrew would install Homebrew.
  it "has a shell bootstrap which parses, and which hands over to this" do
    root = File.expand_path('..', __dir__)
    system("sh -n #{File.join(root, 'install.sh')}")
    _($?.success?).must_equal true
    body = File.read(File.join(root, 'install.sh'))
    _(body).must_match(/install_homebrew/)
    _(body).must_match(/install_ruby/)
    _(body).must_match(%r{bin/namo" setup})
  end

  it "refuses a subcommand it does not have" do
    namo('nonsense')
    _($?.success?).must_equal false
  end

  it "needs nothing but the gem's own dependencies" do
    root = File.expand_path('..', __dir__)
    output = IO.popen({'RUBYLIB' => nil}, [File.join(root, 'bin', 'namo'), '--help'],
      chdir: root, err: [:child, :out]){|io| io.read}
    _(output).wont_match(/LoadError/)
  end
end
