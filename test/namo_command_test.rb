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

  # A line per check carrying the status and the version.  "already installed" on
  # its own repeated what install.sh had just done; the version is the part
  # neither script has said, and the reason to read the line at all.
  it "reports the status and version of each gem it checks" do
    output = namo('setup')
    _($?.success?).must_equal true
    _(output.lines.length).must_equal 2
    _(output).must_match(/^\s+namo\s+\d+\.\d+\.\d+\s+already installed$/)
    _(output).must_match(/^\s+measurand\s+\d+\.\d+\.\d+\s+already installed$/)
  end

  # install.sh is the part a Ruby script cannot do — the Ruby the script would be
  # running on, and the gem which carries the command it hands over to.  Its
  # syntax is asserted and its body is not run: a test which executed it on a
  # machine without Ruby would install Ruby.
  #
  # It hands over to a clone's own bin/namo where it was run from one, and fetches
  # the gem only where it was not: the gem is the bootstrap for the handover rather
  # than a second opinion about what wants installing.  Piped from curl there is no
  # clone to find, the guard being that $0 is a readable file at all, which the
  # shell's own name is not.
  #
  # It installs Homebrew only through `agreed`, which answers no unless -y was
  # given or somebody is there to say yes.  What is asserted is that the curl of
  # Homebrew's installer sits behind that gate: an unguarded call is the failure
  # this is written against.
  it "has a shell bootstrap which parses, hands over by name, and gates the one install it forces" do
    root = File.expand_path('..', __dir__)
    system("sh -n #{File.join(root, 'install.sh')}")
    _($?.success?).must_equal true
    body = File.read(File.join(root, 'install.sh'))
    _(body).must_match(/install_ruby/)
    _(body).must_match(/install_namo/)
    %w{brew port apt-get dnf pacman zypper}.each do |manager|
      _(body).must_match(/command -v #{manager}/)
    end
    _(body).must_match(/ruby_routes/)
    _(body).must_match(/install_ruby_install/)
    # One prompt and one line however many directories want adding: the shell
    # configuration is written to once, not once per directory.
    _(body).must_match(/wants_on_path/)
    _(body.scan(/>> "\$file"/).length).must_equal 1
    # The tag is resolved from the latest release rather than pinned, so that the
    # branch does not rot against a version.
    _(body).wont_match(/ruby-install-0\.\d+\.\d+\.tar\.gz/)
    _(body).must_match(/namo setup/)
    _(body).must_match(/repository\(\) \{\n\s+\[ -f "\$0" \]/)
    _(body).must_match(%r{"\$clone/bin/namo" setup})
    _(body).must_match(/\[ -n "\$clone" \] \|\| install_namo/)
    _(body).must_match(/elif agreed .*Install Homebrew\?.*; then\n\s+\/bin\/bash -c/)
  end

  it "declines to install anything where nothing can answer" do
    root = File.expand_path('..', __dir__)
    output = IO.popen([File.join(root, 'install.sh'), '--help'], chdir: root, err: [:child, :out]){|io| io.read}
    _($?.success?).must_equal true
    _(output).must_match(/-y, --yes/)
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
