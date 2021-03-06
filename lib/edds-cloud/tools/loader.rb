#!/usr/bin/ruby -w
#
# Loads from one back-end to another.
#
d = "#{File.dirname(__FILE__)}/.."
puts d
$LOAD_PATH.unshift d unless $LOAD_PATH.include? d
require 'feed'

class Loader
  def initialize(inBE, outBE)
    @source = Object.const_get(inBE).restore_or_create
    @target = Object.const_get(outBE).restore_or_create
  end

  def load
    if (@source.empty?)
      %w[delicious google twitter github].each do |source|
        @source.add(Feed.load(source))
      end
      @source.persist
    end
    @source.entries(0, -1)[0].each do |entry|
      @target.add(entry)
    end 
    @target.persist
  end
end

if $0 == __FILE__
  require 'backends/file'
  require 'backends/couchdb'

  loader = Loader.new(:FileBackend, :CouchBackend)
  loader.load
end
