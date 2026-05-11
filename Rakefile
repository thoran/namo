# Rakefile

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/**/*_test.rb']
end

namespace :docs do
  SOURCE_DOCS = %w{COMPARISON EXAMPLES README ROADMAP}

  desc "Strip syntax highlighting from code blocks for printing"
  task :md4print do
    SOURCE_DOCS.each do |name|
      sh "script/md4print #{name}.md"
      sh "mv #{name}.print.md docs/"
    end
  end

  desc "Render print-ready markdown to PDF"
  task :md2pdf => :md4print do
    Dir.glob('docs/*.print.md').each do |f|
      pdf = f.sub(/\.md$/, '.pdf')
      sh "pandoc #{f} --pdf-engine=xelatex -V geometry:margin=1in -o #{pdf}"
    end
  end

  desc "Remove intermediate .print.md files"
  task :clean do
    rm_f Dir.glob('docs/*.print.md')
  end

  desc "Remove all generated docs (intermediates and PDFs)"
  task :clobber => :clean do
    rm_f Dir.glob('docs/*.print.pdf')
  end

  desc "Regenerate all derived docs"
  task :gen => [:md2pdf, :clean]
end

task default: :test
