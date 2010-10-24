#!/usr/bin/env ruby -w
#
# Common backend stuff

module Backend
  def add(item)
    if item.is_a? Feed
      item.entries.each do |post|
        add(post)
      end
    elsif item.is_a? Entry
      add_entry(item)
    else
      raise ArgumentError, "Can't deal with a #{item.class}"
    end
  end
end

