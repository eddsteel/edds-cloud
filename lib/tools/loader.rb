#!/usr/bin/ruby -w
#
# Loads from one back-end to another.
#
require 'lib/feed'

class Loader
  def initialize(inBE, outBE)
    @source = Object.const_get(inBE).restore_or_create
    @target = Object.const_get(outBE).restore_or_create
  end

  def load
    if (@source.empty?)
      %w[google delicious twitter].each do |source|
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
  require 'backends/file-backend'
  require 'backends/couch-backend'

  loader = Loader.new(:FileBackend, :CouchBackend)
  loader.load
end
