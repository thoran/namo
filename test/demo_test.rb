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

  def cut
    @cut ||= demo('--help').scan(/^  \* ([a-z_]+)$/).flatten
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
    _(cut).wont_be_empty
    _(cut - sections).must_be_empty
  end

  it "runs the talk cut" do
    demo('talk')
    _($?.success?).must_equal true
  end

  # The padding is what holds a section title in one place on the screen, and it
  # can only pad down to the constants.  A section grown past them would silently
  # start pushing the next one about.  Rows rather than lines, since a line wider
  # than the window costs more than one of them.
  #
  # The cut rather than every section: those are the ones which have to fit on the
  # day, and the rest are reference, free to run long and be scrolled.
  it "has no section in the talk cut taller than the slide height" do
    source = File.read(File.join(File.expand_path('..', __dir__), 'script', 'demo'))
    height, width = %w[SLIDE_HEIGHT SLIDE_WIDTH].map{|name| source[/^#{name} = (\d+)$/, 1].to_i}
    _([height, width].min).must_be :>, 0
    overlong = cut.select do |section|
      demo(section).lines.sum{|line| [(line.chomp.size / width.to_f).ceil, 1].max} > height
    end
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
