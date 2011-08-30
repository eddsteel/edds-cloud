#!/usr/bin/ruby -w
#
require 'rubygems'
require 'feed-normalizer'
require 'entry'

class Feed
  attr_reader :title, :entries, :source

  def initialize(source, feed)
    @source = source.to_sym
    @entries = feed.entries[0..-2].collect do |post|
      Entry.create(@source, post)
    end
    @title = feed.title
  end

  def self.load(source)
    file = "#{ENV['TMP'] || 'raw'}/rss/#{source}.xml"
    cached_file = cached_feed(file)
    if (File.exists?(cached_file))
      raw_feed = YAML::load(File.read(cached_file))
    else
      content = File.read(file)
      raw_feed = FeedNormalizer::FeedNormalizer.parse(content)
      cache(raw_feed, cached_file)
    end

    feed = Feed.new(source, raw_feed)
  end

  private 

  def self.cache(feed, file)
    File.open(file, 'w') do |f|
      f.write(feed.to_yaml)
    end
  end

  def self.cached_feed(feed_name)
    feed_name.sub('.', '.cached.')
  end
end
