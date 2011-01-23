#!/usr/bin/ruby -w
# GPL

libdir = File.dirname(__FILE__) + "/edds-cloud"
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include? libdir

require 'rubygems'
require 'sinatra'
require 'date'
require 'haml'

require 'backends/couchdb'
require 'entry'

##
# Base configuration.
#
# Set up back-end, read alternative titles.
#
configure do
  @@back = CouchBackend.new
  @@clouds = File.read('public/clouds.txt').split("\n")
  set :views, File.dirname(__FILE__) + '/../views'
  set :public, File.dirname(__FILE__) + '/../public'
end

##
# DEV configuration.
#
# Set context-root.
configure :dev do
  @@PATH_ADDN = "/sg"
end

##
# List entries
#
get '/' do
  @entries, @next_key = @@back.entries(0, 10)
  display :page
end

##
# List 2nd page of entries
#
get '/more' do
  @entries, @next_key = @@back.entries(10, 10)
  display :page
end

##
# List page of entries starting from specific entry.
#
get %r{^/more/\[?(.*)\]?$} do
  @entries, @next_key = @@back.entries_from(
    "[#{params[:captures].first}]", 10)
  display :page
end

##
# List all entries for day
#
get %r{/(\d{4})/(\d{1,2})/(\d{1,2})} do
  y, m, d = params[:captures].map {|p| p.to_i}
  @entries, @next_key = @@back.entries_for_day(y, m, d)
  @title = "#{d} #{month_name(m)}, #{y}"
  display :page
end

##
# List all entries for a month
#
get %r{/(\d{4})/(\d{1,2})} do
  y, m = params[:captures].map {|p| p.to_i}
  @entries, @next_key = @@back.entries_for_month(y, m)
  @title = "#{month_name(m)}, #{y}"
  display :page
end

##
# List all entries for a year
#
get %r{/(\d{4})} do
  year = params[:captures][0]
  @title = "#{year}"
  display :year, :locals=>{:year=>year}
end

helpers do
  # TODO: out to templates, or lib
  def linkify(text)
    return nil if text.nil?

    # note: latin domains only.
    text.gsub!(%r[http://[a-zA-Z][-a-zA-Z0-9.]*(/[-\w%./?&]*)*[\w\/-_]\b]) do
      %Q[<nobr><a href="#{$&}">#{$&}</a></nobr>]
    end
    text.gsub!(%r[@(\w+)\b]) do
      %Q[<nobr><a href="http://twitter.com/#{$1}">#{$&}</a></nobr>]
    end
    text
  end

  def random_title
    "Edd's #{@@clouds[rand(@@clouds.size)]}"
  end

  def title
    @title || random_title
  end

  def rurl(url)
    ((defined? @@PATH_ADDN) ? @@PATH_ADDN : "") + url
  end

  def print_params
    puts "Params"
    params.sort_by {|k,v| k.to_s}.each do |key, value|
      puts "#{key}: #{value}"
    end
    puts "ENV"
    env.sort_by {|k,v| k.to_s}.each do |key, value|
      puts "#{key}: #{value}"
    end
  end

  def format_date(time)
    time.strftime('%d %b, %Y')
  end

  def month_name(m)
    Date::MONTHNAMES[m]
  end

  def display(*args)
    haml *args
  end
end
