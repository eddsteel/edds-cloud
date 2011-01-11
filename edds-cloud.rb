#!/usr/bin/ruby -w
# GPL

libdir = File.dirname(__FILE__) + "/lib"
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include? libdir

require 'rubygems'
require 'sinatra'
require 'date'
require 'haml'

require 'backends/couchdb'
require 'entry'

configure do
  @@back = CouchBackend.new
  @@clouds = File.read('public/clouds.txt').split("\n")
end

configure :dev do
  @@PATH_ADDN = "/sg"
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

    # note: latin domains only.
    text.gsub!(%r[http://[a-zA-Z][-a-zA-Z0-9.](/[-\w%./?&])?[\w\/]\b]) do
      %Q[<a href="#{$&}">#{$&}</a>]
    end
    text.gsub!(%r[@(\w+)\b]) do
      %Q[<a href="http://twitter.com/#{$1}">#{$&}</a>]
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

  def format_date(time)
    time.strftime('%d %b, %Y')
  end

  def display(*args)
    haml *args
  end
end
