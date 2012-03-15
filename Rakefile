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
  out = ENV['TMP'] || 'raw'
  rm_r "#{out}/rss/out" if File.exist? "#{out}/rss/out"
  rm_r "#{out}/entries.yaml" if File.exist? "#{out}/entries.yaml"
  rm_r Dir.glob("#{out}/rss/*.cached.xml")
  mkdir_p "#{out}/rss/out"
  `wget -i raw/rss/sources.list -P #{out}/rss/out`
  {'esteel' => 'delicious.xml',
   'user%2F18259483549891522271%2Fstate%2Fcom.google%2Fbroadcast' => 'google.xml',
   '5505502.rss' => 'twitter.xml',
    'eddsteel.atom' => 'github.xml'}.each do |source, target|
    mv "#{out}/rss/out/#{source}", "#{out}/rss/#{target}"
  end
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

desc "Cron job, run by heroku every hour"
task :cron => :load

desc "Load personal statement from stackexchange careers"
task :statement do
  require 'open-uri'
  require 'hpricot'

  URL = 'http://careers.stackoverflow.com/eddsteel'
  STMT= 'conf/statement.md'

  doc = Hpricot(open(URL))
  ps = doc % '#statement' / 'p'

  File.delete(STMT)
  File.open(STMT, 'w') do |f|
    ps.each do |p|
      f.puts p.inner_text
      f.puts "\n"
    end
  end
end

