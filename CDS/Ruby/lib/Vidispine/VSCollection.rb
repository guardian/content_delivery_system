# frozen_string_literal: true

require 'Vidispine/VSItem'
require 'Vidispine/VSSearch'
require 'nokogiri'

class VSCollection < VSItem
  attr_accessor :name

  attr_accessor :host
  attr_accessor :port
  attr_accessor :user
  attr_accessor :passwd

  include Enumerable
  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: nil)
    super
    @vs_object_class = 'collection'
  end # def initialize

  def create!(title, meta, groupname: nil)
    raise TypeError unless title.is_a?(String)

    if meta
      raise TypeError unless meta.is_a?(Hash)
    end
    raise ArgumentError, 'You need to provide a collection name' if title == ''

    url = '/collection'
    q = { 'name' => title }
    result = request(url, method: 'POST', query: q)

    @id = result.xpath('//vs:id', 'vs' => 'http://xml.vidispine.com/schema/vidispine').text
    @name = result.xpath('//vs:name', 'vs' => 'http://xml.vidispine.com/schema/vidispine').text

    raise StandardError, 'Internal error: no ID returned from create operation' if @id.nil? || (@id == '')

    @groupname = groupname if groupname

    setMetadata(meta, vsClass: 'collection') if meta
  end

  def populate(collectionid)
    @metadata, @groupname = get_metadata("/collection/#{collectionid}")
    @id = collectionid
  end # def populate

  def addChild(item, type: nil)
    if item.is_a?(VSCollection)
      addType = 'collection'
      addId = item.id
    elsif item.is_a?(VSItem)
      addType = 'item'
      addId = item.id
    elsif item.is_a?(string)
      raise TypeError, 'If passing a raw ID you must set the type: argument' if type.nil?

      addType = type
      addId = item
    else
      raise TypeError
    end

    url = "/collection/#{@id}/#{addId}"
    q = { 'type' => addType }
    request(url, method: 'PUT', query: q) # this will raise any exceptions if an error occurs
  end # def addChild

  def removeChild(item, type: nil)
    if item.is_a?(VSCollection)
      addType = 'collection'
      addId = item.id
    elsif item.is_a?(VSItem)
      addType = 'item'
      addId = item.id
    elsif item.is_a?(string)
      raise TypeError, 'If passing a raw ID you must set the type: argument' if type.nil?

      addType = type
      addId = item
    else
      raise TypeError
    end

    url = "/collection/#{@id}/#{addId}"
    request(url, 'DELETE', nil, nil, nil) # this will raise any exceptions if an error occurs
  end # def removeChild

  def each(start: 0, limit: 100)
    url = "/collection/#{@id}/"

    saxclass = SearchParser.new
    saxclass.debug = false
    saxclass.vsConnection = self
    parser = Nokogiri::XML::SAX::PushParser.new(saxclass, nil, nil)

    raw_request(url, 'GET', nil, nil, nil) do |response|
      puts "Returned response: #{response}" if @debug

      sanitisedText = ''
      begin
        # not _quite_ sure why this works, but it does!
        # ref. http://stackoverflow.com/questions/23309669/ruby-encode-xc3-from-ascii-8bit-to-utf-8-encodingundefinedconversionerr
        sanitisedText = response
        # sanitisedText = response.force_encoding('ISO-8859-1').encode('UTF-8')
      rescue Encoding::UndefinedConversionError => e
        # if(sanitisedText.gsub!(/#{e.error_char}/,'?')==nil)
        #        yield StandardError,"Unable to sanitise string"
        #   end
        # retry
        puts "error char: #{e.error_char}"
        sanitisedText = sanitisedText.dump
        ap e
        retry
      end

      begin
        parser << sanitisedText
      rescue Nokogiri::XML::SyntaxError => e
        puts "-WARNING: #{e} at column #{e.column} on line #{e.line}"
        raise StandardError, 'Fatal error' if e.fatal?
        # ensure #if we error, output everything that we got up till that point
      end # exception block
      while saxclass.items.length.positive?
        @hits = saxclass.hits
        foundItem = saxclass.items.shift
        if @debug
          ap foundItem
          puts "Yielding item #{foundItem.id}"
        end

        yield foundItem
      end # while(saxclass.items.length > 0)
    end # self.raw_request
  end # each

  # def addAccess(access)
  #    super("/collection/#{@id}",access)
  # end
end # class VSCollection
