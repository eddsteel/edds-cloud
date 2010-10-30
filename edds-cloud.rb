#!/usr/bin/ruby -w
# GPL

libdir = File.dirname(__FILE__) + "/lib"
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include? libdir
require 'rubygems'
require 'sinatra'

require 'backends/couchdb'
require 'entry'

configure do
  @@back = CouchBackend.new
  @@front = :haml # this will be dynamically selected
end

get '/' do
  @entries, @next_key = @@back.entries(0, 10)
  display :page
end

get '/more' do
  @entries, @next_key = @@back.entries(10, 10)
  display :page
end

get %r{^/more/\[?(.*)\]?$} do
  @entries, @next_key = @@back.entries_from(
    "[#{params[:captures].first}]", 10)
  display :page
end

# By day
get %r{/(\d{4})/(\d{1,2})/(\d{1,2})} do
  @entries, @next_key = @@back.entries_for_day(*params[:captures])
  display :page 
end

# By month
get %r{/(\d{4})/(\d{1,2})} do
  year, month = params[:captures].map {|p| p.to_i}
  @entries, @next_key = @@back.entries_for_month(year,
                                                  month)
  @title = "#{Date::MONTHNAMES[month]}, #{year}"
  display :page 
end

helpers do
  # TODO: out to templates, or lib
  def linkify(text)
    return nil if text.nil?
    # TODO: what is included in \w?
    
    text.gsub!(%r[http://[-\w%./?&]+[\w\/]\b]) {
      %Q[<a href="#{$&}">#{$&}</a>]
    }
    text.gsub!(%r[@(\w+)\b]) {
      %Q[<a href="http://twitter.com/#{$1}">#{$&}</a>]
    }
    text
  end
  
  def format_date(time)
    time.strftime('%d %b, %Y')
  end

  def display(*args)
    send @@front, *args
  end
end
