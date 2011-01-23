#!/usr/bin/env ruby -w
# Simple, memory-only store with disk persistence (YAML)
require 'yaml'
require 'backends/backend'

class FileBackend
  include Backend

  @@FILE_NAME = 'entries.yaml'

  def initialize
    @entries = []
  end

  def empty?
    @entries.empty?
  end

  def entries(start=0, count=10)
    if count < 0
      return @entries, nil
    else
      next_id = start + count + 1
      next_id = next_id < @entries.size ? next_id : nil
      return @entries[start, count], next_id
    end
  end

  alias :entries_from :entries

  def entries_for_month(year, month)
    @entries.select do |entry|
      puts "matching #{entry.date.month}/#{entry.date.year} with #{month}/ #{year}"
      entry.date && entry.date.year == year.to_i &&
        entry.date.month == month.to_i
    end
  end

  def entries_for_day(year, month, day)
    @entries.select do |entry|
      entry.date && entry.date.year == year.to_i &&
        entry.date.month == month.to_i &&
        entry.date.day == day.to_i
    end
  end

  def add_entry(item)
    @entries << item
    @entries.sort!
  end

  def persist
    File.open(@@FILE_NAME, 'w') do |f|
      f.write(to_yaml)
    end
  end

  def self.restore
    if File.exist? @@FILE_NAME
      YAML::load(File.read(@@FILE_NAME))
    end
  end

  def self.restore_or_create
    store = restore
    store ? store : FileBackend.new
  end
end
