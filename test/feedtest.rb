#!/usr/bin/ruby -w
#

require 'feed'
require 'entry-store'

def test
  store = EntryStore.restore_or_create
  if (store.empty?)
    %w[google delicious twitter].each do |source| 
      store.add(Feed.load(source))
    end
    store.persist
  end

  store.each_in_order do |entry|
    title = "#{entry.author}: #{entry.title}"
    puts title
    puts title.gsub(/./, '=')
    puts entry.content if entry.content 
    puts "#{entry.url} | #{entry.date}"
    puts
    puts
  end

  store
end
