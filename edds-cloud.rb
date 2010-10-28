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


__END__

@@layout
!!! 5
%html{:lang => 'en'}
  %head
    %meta{:charset => 'utf-8'}
    %title<
      = @title || 'Edd\'s Cloud'
    %link{:rel => 'stylesheet', :href => '/style.css'}
  %body.cloud
    =yield

@@page
%section#header
  %header.main
    %hgroup
      %h1 Edd's
      %h2 Cloud
%section#main
  -if @title
    %h2 
      =@title
  -@entries.each do |entry|
    = haml :entry, :locals=>{:entry=>entry}, 
      :layout=>false
%footer#more
  - if @next_key
    %a{:href=>"/more/#@next_key"}
      More
  - else
    = "&\##{9748}"; 

@@entry
%article
  - if entry.title
    %h1
      - if entry.author
        = "#{entry.author}: "
      %a{:href=>entry.url}
        = entry.title
  %section.content
    = linkify(entry.content)
  %footer
    -if entry.date
      %span.date<
        = format_date(entry.date)
    %span.source<
      on
      -if "#{entry.source_url}".start_with? 'http://'
        %a{:href=>"#{entry.source_url}"}<
          = entry.source
      -else
        = entry.source
    -unless entry.tags.empty?
      %span.tags<
        = "tagged #{entry.tags.join(', ')}"
    -if entry.meta
      %span.meta<
        =haml :meta, 
          :locals=>{:meta=>entry.meta, 
            :url=>"http://twitter.com/"}

@@meta
%span
  - if meta.recipient
    - if meta.response_id
      in reply to 
      %a.reply{:href=>"#{url}status/#{meta.response_id}"}<
        ="@#{meta.recipient}"
    - else
      to 
      %a.to{:href=>"#{url}#{meta.recipient}"}<
        ="@#{meta.recipient}"
  - if meta.quoting
    quoting 
    %a.quoting{:href=>"#{url}#{meta.quoting}"}<
      ="@#{meta.quoting}"
