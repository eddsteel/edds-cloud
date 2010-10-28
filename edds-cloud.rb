#!/usr/bin/ruby -w
# GPL

libdir = File.dirname(__FILE__) + "/lib"
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include? libdir
require 'rubygems'
require 'sinatra'

require 'backends/couchdb'
require 'entry'

configure do
  @@store = CouchBackend.new
end

get '/' do
  prepare
  @retriever = :each
  @retriever_args = [0, 10]
  haml :page
end

get '/more' do
  prepare
  @retriever = :each
  @retriever_args = [10, 10]
  haml :page
end


get %r{^/more/\[?(.*)\]?$} do
  prepare
  @retriever = :each_from
  @retriever_args = ["[#{params[:captures].first}]", 10]
  haml :page
end

# By day
get %r{/(\d{4})/(\d{1,2})/(\d{1,2})} do
  prepare
  @retriever = :each_of_day
  @retriever_args = params[:captures]
  haml :page 
end

# By month
get %r{/(\d{4})/(\d{1,2})} do
  prepare
  @retriever = :each_of_month
  year, date = params[:captures].map {|p| p.to_i}
  @retriever_args = params[:captures]
  @title = "#{Date::MONTHNAMES[date]}, #{year}"
  haml :page 
end

helpers do
  def prepare
    @store = @@store
  end

  # TODO: out to templates
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
  -next_id = @store.send(@retriever, *(@retriever_args)) do |entry|
    =haml :entry, :locals=>{:entry=>entry}, :layout=>false
%footer#more
  - if next_id
    %a{:href=>"/more/#{next_id}"}
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
        =haml :meta, :locals=>{:meta=>entry.meta, 
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
