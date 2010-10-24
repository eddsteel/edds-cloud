task :default => [:spec]

directory "target"

desc "Run all RSpec specifications"
task :spec => [:target] do
  ruby 'spec/* -fn -c -fh:target/spec-output.html'
end

task :clobber => [:clean] do
  rm_r 'target'
end

task :gem => [:spec] do
  gem '*.gemspec'
end

task :clean 

task :load do
  rm_r 'raw/rss/out' if File.exist? 'raw/rss/out'
  mkdir_p 'raw/rss/out'
  `cd raw/rss && wget -i sources.list -P out`
  ruby 'loader.rb'
end

