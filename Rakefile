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

desc "Clear cached feeds and reload them from the web"
task :load do
  rm_r 'raw/rss/out' if File.exist? 'raw/rss/out'
  rm_r 'entries.yaml' if File.exist? 'entries.yaml'
  rm_r Dir.glob('raw/rss/*.cached.xml')
  mkdir_p 'raw/rss/out'
  `wget -i raw/rss/sources.list -P raw/rss/out`
  ruby 'lib/edds-cloud/tools/loader.rb'
end

desc "Push contents of DB to cloudant DB"
task :replicate do
  config = `heroku config --long`.split("\n")
  cloudant = config.map {|c| $1 if c =~ /CLOUDANT_URL *=> (.*)/}.join
  source = "http://localhost:5984"
  `curl -v -X POST -d '{"source":"#{source}/entries", "target":"#{cloudant}/entries"}' \
  -H "Content-Type: application/json" \
  #{source}/_replicate`
end
