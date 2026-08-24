# test/demo_test.rb

require 'minitest/autorun'
require 'minitest-spec-context'

require_relative '../lib/namo'

# script/demo is 300-odd lines exercising selection, projection, formulae,
# group_by, summary, the operators and inspect, and nothing else runs it.  These
# assert only that each section completes, which is the difference between a
# demonstration which rots quietly and one which fails the suite when the library
# moves under it.
#
# A process apiece, since the script is a program rather than a library and its
# sections share a binding within a run.

describe 'script/demo' do
  def demo(*sections)
    root = File.expand_path('..', __dir__)
    IO.popen([File.join(root, 'script', 'demo'), *sections],
      chdir: root, err: [:child, :out]){|io| io.read}
  end

  def sections
    @sections ||= demo('--help').scan(/^  [* ] ([a-z_]+)$/).flatten
  end

  it "lists its sections" do
    _(sections).wont_be_empty
    _(sections).must_include 'ingestion'
  end

  it "runs every section without raising" do
    failed = sections.reject do |section|
      demo(section)
      $?.success?
    end
    _(failed).must_be_empty
  end

  it "has a talk cut, and it is a subset of the sections" do
    cut = demo('--help').scan(/^  \* ([a-z_]+)$/).flatten
    _(cut).wont_be_empty
    _(cut - sections).must_be_empty
  end

  it "runs the talk cut" do
    demo('talk')
    _($?.success?).must_equal true
  end

  # The padding is what holds a section title in one place on the screen, and it
  # can only pad down to the constant.  A section grown past it would silently
  # start pushing the next one about.
  it "has no section taller than the slide height" do
    height = File.read(File.join(File.expand_path('..', __dir__), 'script', 'demo'))[/^SLIDE_HEIGHT = (\d+)$/, 1].to_i
    _(height).must_be :>, 0
    overlong = sections.select{|section| demo(section).lines.size > height}
    _(overlong).must_be_empty
  end

  it "runs the whole script" do
    demo
    _($?.success?).must_equal true
  end

  it "refuses a section it does not have" do
    demo('nonexistent')
    _($?.success?).must_equal false
  end

  it "needs nothing but the gem's own dependencies" do
    root = File.expand_path('..', __dir__)
    output = IO.popen({'RUBYLIB' => nil}, [File.join(root, 'script', 'demo'), 'ingestion'],
      chdir: root, err: [:child, :out]){|io| io.read}
    _(output).wont_match(/LoadError/)
  end
end
