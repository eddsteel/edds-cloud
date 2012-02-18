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

RE = { :ext=>%r{\.([a-z]{1,5})},
    :year=>%r{(\d{4})},
    :md=>%r{(\d{1,2})}}

##
# Base configuration.
#
# Set up back-end, read alternative titles.
#
configure do
  @@back = CouchBackend.new
  @@clouds = File.read('public/clouds.txt').split("\n")
  set :views, File.dirname(__FILE__) + '/../views'
  set :public_folder, File.dirname(__FILE__) + '/../public'
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
  uri_part = URI::encode(params[:splat][0])
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

get '/resume' do
  send_file 'public/cv.html'
end

##
# List entries
#
get '/' do
  @entries, @next_key = @@back.entries(0, 10)
  display :entries, params[:ext]
end
get '/entries.?:ext?' do
  @entries, @next_key = @@back.entries(0, 10)
  display :entries, params[:ext]
end

##
# List 2nd page of entries
#
get '/more.?:ext?/?' do
  @entries, @next_key = @@back.entries(10, 10)
  display :entries, params[:ext]
end

##
# List page of entries starting from specific entry.
#
get %r{^/more/\[?([^.]*)\]?#{RE[:ext]}?$} do
  @entries, @next_key = @@back.entries_from(
    "[#{sanitize(params[:captures].first)}]", 10)
  display :entries, params[:captures][1]
end

##
# List all entries for day
#
get %r{/#{RE[:year]}/#{RE[:md]}/#{RE[:md]}(?:#{RE[:ext]}|/)?} do
  y, m, d, e = params[:captures]
  y, m, d = [y, m, d].map {|p| sanitize(p).to_i}
  @entries, @next_key = @@back.entries_for_day(
    y, m, d)
  @title = "#{d} #{month_name(m)}, #{y}"
  display :entries, e
end

##
# List all entries for a month
#
get %r{/#{RE[:year]}/#{RE[:md]}(?:#{RE[:ext]}|/)?} do
  y, m, e = params[:captures]
  y, m = [y, m].map {|p| sanitize(p).to_i}
  @entries, @next_key = @@back.entries_for_month(y, m)
  @title = "#{month_name(m)}, #{y}"
  display :entries, e
end

##
# List month links for a year
#
get %r{/#{RE[:year]}/?} do
  year = sanitize(params[:captures][0])
  @title = "#{year}"
  display :year, nil, :locals=>{:year=>year}
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
  display :tags, nil, :locals=>locals
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

  def display(view, extension=nil, *args)
    # def to nil then set for routing matches
    extension ||= 'html'
    case extension
    when 'atom'
      @id = Entry.tag_uri Time.now, ENV['REQUEST_URI']
      content_type 'application/atom+xml'
      haml :entry_feed, :format => :xhtml, :layout => false
    when 'csv'
      # todo: view awareness
      ret = Entry.csv_headers
      ret = [ret] + @entries.map{|entry| entry.to_csv}
      content_type 'text/plain'
      ret.join("\n")
    when 'html'
      haml *([view] + args)
    else
      404
    end
  end
end
