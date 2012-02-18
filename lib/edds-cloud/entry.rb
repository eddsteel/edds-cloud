#!/usr/bin/ruby -w
#
# Entry class. Various specialisations exist.
#

class Entry
  include Comparable

  attr_accessor :title, :url, :content, :date, 
    :author, :source, :tags, :meta, :source_url

  def self.create(source, post)
    case source
    when :twitter
      Tweet.new(source, post)
    when :delicious
      SharedLink.new(source, post)
    when :google
      SharedItem.new(source, post)
    when :github
      Action.new(source, post)
    end
  end

  def initialize(source, post)
    unless post.nil?
      @title = post.title.gsub("\n", "")
      @source = source
      @content = post.content
      @author = post.author 
      @date = post.date_published
      @url = post.urls[0]
      @tags = post.categories
      @source_url = post.id
      @meta = nil
    end
  end

  def html_content?
    false
  end

  def month
    @date.month
  end

  def year
    @date.year
  end

  def day
    @date.day
  end

  def id_url
    URI.escape((@source_url || '0'), /[^0-9a-zA-Z]/)
  end

  def tag_uri
    date = @date.strftime '%Y-%m-d'
    Entry.tag_uri date, id_url
  end

  def self.tag_uri date, id
    "tag:edd.heroku.com,#{date}:#{id}"
  end

  def some_url
    url = @source_url
    unless url =~ /https?:\/\//
      url = @url
    end

    url
  end

  def <=>(other)
    return 1 if (other.nil? || other.date.nil?)
    return -1 if @date.nil?
    return other.date <=> @date 
  end

  def self.from_json_hash(hash)
    event = create(hash['source'].to_sym, nil)
    event.title = hash['title']
    event.source = hash['source']
    event.content = hash['content']
    event.title = hash['title']
    event.source = hash['source']
    event.content = hash['content']
    event.author = hash['author']
    event.date = Time.local(*(hash['date']))
    event.url = hash['url']
    event.tags = hash['tags']
    event.source_url = hash['source_url']
    if hash['meta']
      event.meta = Meta.from_json_hash(hash['meta'])
    end
    event
  end

  def to_json_hash
    raise "Entry is not uniquely marked" if @source_url.nil?

    hash = {
     :_id => @source_url,
     :title => @title,
     :source => @source,
     :content => @content,
     :title => @title,
     :source => @source,
     :content => @content,
     :author => @author,
     :date => [:year, :month, :day, :hour, :min, :sec].map{|f| @date.send f},
     :url => @url,
     :tags => @tags,
     :source_url => @source_url}
    hash[:meta] = @meta.to_json_hash unless @meta.nil?

    hash
  end

  def to_json
    to_json_hash.to_json
  end

  def to_csv
    %Q|"#@source","#@url","#@title","#@author",| +
    %Q|"#{@date.strftime("%Y-%m-%d %H:%M:%S%z")}",| +
    %Q|"#{@content.gsub "\n", ''}"|
  end

  def self.csv_headers
    "source,url,title,author,date,content"
  end
end

class Tweet < Entry
  @@TAG_RE = /\B#\S+[^;]\b/

  def initialize(source, post)
    super
    unless post.nil?
      @author = post.title[/^[^:]*/]
      @title = nil
      text = post.title.sub(/^[^:]*: /, '')
      @meta = parse_meta(text)
      text.sub!(/(.*)(?:RT )@\w+:? ?(.*)/m) do |match|
        %Q[#$1<blockquote>#$2</blockquote>]
      end
      @content = text.sub(/^@\w+:?/, '').sub(/(\s*#@@TAG_RE\s*)+$/, '')
      @url = post.id
      @tags = @meta.tags
    end
  end

  def parse_meta(text)
    quoting,response,recipient = nil
    quoting = $1 if text =~ /RT @([-\w_]+)/
    tags = text.scan(@@TAG_RE).collect do |tag| 
      tag[1..-1].to_sym
    end
    recipient = $1 if text=~ /^@([-\w_]+)/

    Meta.new({:quoting=>quoting, :tags=>tags, 
      :response=>response, :recipient=>recipient})
  end

  def baseurl; "http://twitter.com/" ;end
end

class Meta
  attr_reader :tags, :quoting, :response_id, :recipient

  def initialize(meta={})
    @recipient = meta[:recipient]
    @response_id = meta[:response]
    @quoting = meta[:quoting]
    @tags = meta[:tags]
  end

  def to_json_hash
    {:recipient => @recipient,
    :response_id => @response_id,
    :quoting => @quoting,
    :tags => @tags}
  end

  def self.from_json_hash(hash)
     Meta.new(
      :recipient => hash['recipient'],
      :response_id => hash['response_id'],
      :quoting => hash['quoting'],
      :tags => hash['tags'])
  end
end

class SharedItem < Entry
  def initialize(source, post)
    super
    unless post.nil?
      @title = post.title.gsub("\n", "")
      @source = source
      @content = extract_content(post.content)
      @author = nil if @author == '(author unknown)'
    end
  end

  private 
  # Hacky way of jumping between quotes and new content: 3 line breaks.
  def extract_content(post_content)
    doc = Hpricot(post_content)
    html = ''
    if (doc % :blockquote)
      parts = (doc % :blockquote).children
      quoting = false
      bcount = 0

      if parts.size > 2
        parts[2..-1].each do |child|
          br = child.to_s == '<br />'
          bcount = br ? bcount + 1 : 0
          if bcount > 2
            quoting = !quoting
            html += quoting ? "<p><blockquote>" : "</blockquote></p>"
            bcount = 0
          else
            html += child.to_s
          end
        end

        html += '</blockquote></p>' if quoting
        html = html.gsub('<br /><br /><blockquote>', '<blockquote>')
        html = html.gsub('<br /><br /></p>', '</p>')
        html = html.gsub('<p><br />', '<p>')
      end
    end
  end
end

class SharedLink < Entry
  def initialize(source, post)
    super
    @author = nil
  end
end

class Action < Entry
  def initialize(source, post)
    super
    @author = author.split(/\n[ ]*/)[1] unless @author.nil?
    @title = nil
    @content = extract_content @content unless @content.nil?
  end

  def html_content?
    true
  end


  private
  def extract_content(content)
    doc = Hpricot(content)
    html = ((doc % 'div.title').inner_html).split("\n")[1] + ".\n"
    (doc / 'div.message' / 'blockquote').each do |bq|
      html += "#{bq.to_s}\n"
    end

    html
  end

  def extract_extra_url(content)
    doc = Hpricot(content)
    link =  doc % 'li.more a' 

    link.nil? ? nil : link['href']
  end

end
