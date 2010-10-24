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
     :date => [:year, :month, :day].map{|f| @date.send f},
     :url => @url,
     :tags => @tags,
     :source_url => @source_url}
    hash[:meta] = @meta.to_json_hash unless @meta.nil?

    hash
  end

  def to_json
    to_json_hash.to_json
  end
end

class Tweet < Entry
  @@TAG_RE = /\B#\S+\b/

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
  def extract_content(post_content)
    doc = Hpricot.parse(post_content)
    html = ''
    if (doc % :blockquote)
      parts = (doc % :blockquote).children
      quoting = false
      bcount = 0

      if parts.size > 2
        parts[2..-1].each do |child|
          unless quoting
            br = child.to_s == '<br />'
            bcount = br ? bcount + 1 : 0
            if bcount > 2
              quoting = true
              html += "<blockquote>\n"
            else
              html += child.to_s
            end
          else
            html += child.to_s
          end
        end

        html += '</blockquote>' if quoting
        html.gsub('<br /><br /><block', '<block')
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
