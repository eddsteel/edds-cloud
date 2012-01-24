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
# Get something from the public S3 bucket
get '/bucket/*' do
  uri_part = URI::encode(params[:splat])
  redirect "http://s3.amazonaws.com/eddscloud-public/#{uri_part}"
end

##
# Some useful shortcircuits
#
get '/cv' do redirect '/bucket/cv.pdf' end
get '/resume.pdf' do redirect '/bucket/cv.pdf' end
get '/qr' do redirect '/about' end

get '/about' do
  display :about
end

get 'resume' do
  send_file '../public/cv.html'
end

##
# List entries
#
get '/' do
  @entries, @next_key = @@back.entries(0, 10)
  display :entries
end

##
# List 2nd page of entries
#
get '/more/?' do
  @entries, @next_key = @@back.entries(10, 10)
  display :entries
end

##
# List page of entries starting from specific entry.
#
get %r{^/more/\[?(.*)\]?$} do
  @entries, @next_key = @@back.entries_from(
    "[#{sanitize(params[:captures].first)}]", 10)
  display :entries
end

##
# List all entries for day
#
get %r{/(\d{4})/(\d{1,2})/(\d{1,2})/?} do
  y, m, d = params[:captures].map {|p| sanitize(p).to_i}
  @entries, @next_key = @@back.entries_for_day(y, m, d)
  @title = "#{d} #{month_name(m)}, #{y}"
  display :entries
end

##
# List all entries for a month
#
get %r{/(\d{4})/(\d{1,2})/?} do
  y, m = params[:captures].map {|p| sanitize(p).to_i}
  @entries, @next_key = @@back.entries_for_month(y, m)
  @title = "#{month_name(m)}, #{y}"
  display :entries
end

##
# List all entries for a year
#
get %r{/(\d{4})/?} do
  year = sanitize(params[:captures][0])
  @title = "#{year}"
  display :year, :locals=>{:year=>year}
end

##
# List tags
#
get '/tag' do redirect '/tag/' end
get '/tag/' do
  locals = {}
  locals[:tags] = @@back.tags
  locals[:taglist] = locals[:tags].keys.sort {|a,b| locals[:tags][b] <=> locals[:tags][a]}
  locals[:height] = (locals[:taglist].size / 3).to_i

  @title = 'Tags'
  display :tags, :locals=>locals
end

##
# List entries for a tag
get '/tag/*' do
  clean_splat = sanitize(params[:splat].first)
  @entries, @next_key = @@back.entries_for_tag(clean_splat)

  display :entries
end

helpers do
  ##
  # Strips non-alphanumeric characters but
  # allows '.', '-', '_', ',', ':'.
  # Harsh, because we don't need it not to be.
  #
  def sanitize(text)
    text.gsub(/[^-a-zA-Z0-9.,:_]/, '')
  end

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
