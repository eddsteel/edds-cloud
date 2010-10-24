#!/usr/bin/ruby -w
#
# Stores/ retrieves entries using a pluggable backend
#
libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include? libdir
require 'feed'
require 'backends/couch-backend'

class EntryStore
  def initialize(backend=CouchBackend)
    @backend = backend.restore_or_create
  end

  def each(start=0, count=-1, &block)
    entries, next_id = @backend.entries
    entries.each do |entry|
      block.call(entry)
    end
    return next_id
  end

  def each_from(start, count, &block)
    entries, next_id = @backend.entries_from(start, count)
    entries.each do |entry|
      block.call(entry)
    end
    return next_id
  end

  def each_of_month(year, month, &block)
    entries = @backend.entries_for_month(year, month)
    entries.each do |entry|
      block.call(entry)
    end
  end

  def each_of_day(year, month, day, &block)
    entries = @backend.entries_for_day(year, month, day)
    entries.each do |entry|
      block.call(entry)
    end
  end
end

