#!/usr/bin/env ruby -w
#

require File.dirname(__FILE__) + '/backend'
require 'rubygems'
require 'json'
require 'restclient'
require 'date'


# TODO: extract design docs.
class CouchBackend
  include Backend

  @@DEF_DB_URL = ENV['CLOUDANT_URL'] || 'http://localhost:5984'
  @@DEF_DB_NAME = 'entries'

  attr_reader :info

  def initialize(db_url=@@DEF_DB_URL,
                 db_name=@@DEF_DB_NAME)
    options = get_options
    @db = options['db'] || db_url
    @db_name = options['name'] || db_name
    @info = curl
  end

  def self.month_lengths(year)
    [-1, 31, Date.leap?(year) ? 29 : 28, 31, 30, 31, 30, 31,
         31, 30, 31, 30, 31]
  end

  def get_options
    options = {}
    if File.exist? 'couch.yaml'
      options = YAML::load(File.read('couch.yaml'))
    end
    options
  end

  def create
    curl("/#@db_name", :put)
  end

  def self.restore_or_create(db_url=@@DEF_DB_URL, 
                             db_name=@@DEF_DB_NAME)
    store = CouchBackend.new(db_url, db_name)
    begin
      store.curl("/#{db_name}")
    rescue => e
      if e.respond_to? :http_code and e.http_code == 404 # Not Found
        store.create
      else
        raise e
      end
    end

    store
  end

  def empty?
    curl("/#@db_name")['doc_count'] == '0'
  end

  def add_entry(entry)
    begin
      curl("/#@db_name", :post, entry.to_json)
    rescue => e
      if e.respond_to? :http_code and e.http_code == 409 # Conflict
        puts "Ignoring conflict; I don't know how to update."
      else
        puts "Error on #{p entry.to_json}"
        raise e
      end
    end
  end

  # doing this has poor performance on couch.
  # Returns the first +count+ entries, starting
  # from +start+. Also returns the next ID, so
  # the better performing +entries_from+ method can
  # be called.
  def entries(start=0, count=10)
    url = "/#@db_name/_design/docs/_view/by_time?descending=true"
    url = url + "&skip=#{start}&limit=#{count+1}" if count >= 0

    get_entries(url)
  end

  def entry(id)
    url = "/#@db_name/#{URI.encode(id, /[^a-zA-Z0-9]/)}"
    Entry.from_json_hash(curl(url))
  end

  def get_entries(url, with_next = true)
    list = curl(URI::encode(url))['rows']
    list = list[0..-2] if with_next
    entries = list.map do |item|
      Entry.from_json_hash(item['value'])
    end

    next_key = list.last['key'].to_json[1..-2] if with_next
    [entries, next_key]
  end


  def entries_from(start, count=10)
    startkey = start
    url = "/#@db_name/_design/docs/_view/by_time" + 
    "?descending=true&startkey=#{startkey}"
    url = url + "&limit=#{count + 1}" if count > 0
    get_entries(url)
  end

  def entries_for_month(year, month)
    startkey = [year, month, 0]
    endkey = month >= 12 ? [year + 1, 1, 0] :
      [year, (month + 1), 0]
    url = "/#@db_name/_design/docs/_view/by_time" +
    "?startkey=#{startkey.to_json}" +
    "&endkey=#{endkey.to_json}"
    get_entries(url, false)
  end

  def entries_for_day(year, month, day)
    startkey = [year, month, day]
    days = CouchBackend.month_lengths(year)[month]
    nday = day >= days ? 1 : day + 1
    nmonth = nday == 1 ? month + 1 : month
    endkey = [year, nmonth, nday]
    url = "/#@db_name/_design/docs/_view/by_time" +
    "?startkey=#{startkey.to_json}" +
    "&endkey=#{endkey.to_json}"
    get_entries(url, false)
  end

  def entries_for_tag(tag)
    url = "/#@db_name/_design/docs/_view/by_tag" +
    "?startkey=#{tag.to_json}" +
    "&endkey=#{tag.to_json}"

    get_entries(url, false)
  end

  def tags
    url = "/#@db_name/_design/stats/_view/tags?group=true&descending=true"
    list = curl(URI::encode(url))['rows']
    tags = {}
    list.each do |item|
      tags[item['key']] = item['value']
    end
    tags
  end


  def persist
    # Do nothing, we're writing through every time.
  end


  def curl url='', method=:get, data=nil
    args = {:content_type=>'application/json',
      :accept=>'application/json'}
    resp = ''

    begin
      if data.nil?
        resp = RestClient.send method, (@db + url), args
      else
        resp = RestClient.send method, (@db + url), data,
          args
      end
    rescue => e
      raise e, "Failed to reach #{@db + url}"
    end

    JSON::parse(resp.body)
  end
end

