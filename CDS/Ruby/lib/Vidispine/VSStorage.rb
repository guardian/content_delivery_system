# frozen_string_literal: true

require 'Vidispine/VSApi'
require 'awesome_print'
require 'uri'
require 'date'

class VSAlreadyImported < VSException
end # class VSAlreadyImported

class VSStorage < VSApi
  include Enumerable
  attr_accessor :id
  attr_accessor :state
  attr_accessor :type
  attr_accessor :capacity
  attr_accessor :freeCapacity
  attr_accessor :timestamp
  attr_accessor :lowWatermark
  attr_accessor :highWatermark
  attr_accessor :autoDetect
  attr_accessor :showImportables
  attr_accessor :scanInterval
  attr_accessor :metadata

  attr_accessor :host
  attr_accessor :port
  attr_accessor :user
  attr_accessor :passwd

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: nil, run_as: nil)
    # super.initialize(host,post,user,passwd,parent: p)
    super(host, port, user, passwd, parent: parent, run_as: run_as)
  end # def initialize

  def populate(storageid)
    unless storageid.nil?
      urlpath = "/storage/#{storageid}"
      vsdoc = request(urlpath, method: 'GET')

      @id = valueForXpath(vsdoc, '//vs:id')
      @state = valueForXpath(vsdoc, '//vs:state')
      @type = valueForXpath(vsdoc, '//vs:type')
      @capacity = valueForXpath(vsdoc, '//vs:capacity')
      @freeCapacity = valueForXpath(vsdoc, '//vs:freeCapacity')
      @timestamp = DateTime.parse(valueForXpath(vsdoc, '//vs:timestamp'))
      @lowWatermark = valueForXpath(vsdoc, '//vs:lowWatermark')
      @highWatermark = valueForXpath(vsdoc, '//vs:highWatermark')
      @autoDetect = valueForXpath(vsdoc, '//vs:autoDetect')
      @showImportables = valueForXpath(vsdoc, '//vs:showImportables')
      @scanInterval = valueForXpath(vsdoc, '//vs:scanInterval').to_i

      @metadata = get_metadata(urlpath)

      @storageMethods = []
      vsdoc.xpath('//vs:method', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |m|
        @storageMethods << VSStorageMethod.new(m, self)
      end # "vs:method".each
    end # if(storageid!-nil)
  end # def populate

  def createFileEntity(filepath)
    vsdoc = request("/storage/#{@id}/file", method: 'POST',
                                            query: { 'createOnly' => 'true',
                                                     'path' => filepath },
                                            content_type: 'text/plain')
    VSFile.new(vsdoc, self)
  end

  # yields methods of given type (file:, http:, etc.)
  def methodsOfType(type)
    typeRegex = /^#{type}/
    # ap @storageMethods

    @storageMethods.each do |m|
      if typeRegex.match(m.uri.to_s)
        yield m
      end # if typeRegex.match
    end # @storageMethods.each
  end # def methodsOfType

  def fileForPath(path)
    # this should through VSNotFound if the item is not found
    vsdoc = request("/storage/#{@id}/file/byURI", method: 'GET',
                                                  matrix: { 'includeItem' => 'true',
                                                            'path' => path })
    VSFile.new(vsdoc, self)
  end # def fileForPath

  # /API/storage/KP-2/file;start=1;number=2
  def each(&b); end # each
end # class VSStorage

class VSFile < VSApi
  attr_accessor :name
  attr_accessor :path
  attr_accessor :uri
  attr_accessor :state
  attr_accessor :size
  attr_accessor :hash
  attr_accessor :timestamp
  attr_accessor :refreshFlag
  attr_accessor :storageName
  attr_accessor :memberOfItem
  attr_accessor :host
  attr_accessor :port
  attr_accessor :id
  attr_accessor :user
  attr_accessor :passwd

  def initialize(xmlchunk, parent)
    @parent = parent
    @id = parent.valueForXpath(xmlchunk, '//vs:id')
    @path = parent.valueForXpath(xmlchunk, '//vs:path')
    @uri = parent.valueForXpath(xmlchunk, '//vs:uri')
    @state = parent.valueForXpath(xmlchunk, '//vs:state')
    @size = parent.valueForXpath(xmlchunk, '//vs:size')
    @hash = parent.valueForXpath(xmlchunk, '//vs:hash')
    @timestamp = DateTime.parse(parent.valueForXpath(xmlchunk, '//vs:timestamp'))
    @refreshFlag = parent.valueForXpath(xmlchunk, '//vs:refreshFlag')
    @storageName = parent.valueForXpath(xmlchunk, '//vs:storageName')

    @memberOfItem = nil
    xmlchunk.xpath('//vs:item', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |i|
      i.xpath('vs:id', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |idNode|
        next unless idNode

        host = parent.host
        port = parent.port
        user = parent.user
        passwd = parent.passwd

        # create as a parent of the storage. Needs these refs so it can make calls of its own.
        @memberOfItem = VSItem.new(host, port, user, passwd, parent: parent)
        @memberOfItem.id = idNode.inner_text
        # if(idNode)
      end # xpath.each
    end # "vs:item".each()
  end # def initialize

  def importToItem(metadata, tags: [], priority: 'LOW')
    unless @memberOfItem.nil?
      raise VSAlreadyImported, "The file #{@id} is already imported and associated with the item #{@memberOfItem}"
    end

    mdtext = ''
    if metadata.is_a?(String)
      mdtext = metadata
    elsif metadata.is_a?(Hash)
      mdtext = mdhash_to_xml(metadata, group: 'Asset')
    end

    q = { 'thumbnails' => 'true',
          'priority' => priority }

    q['tag'] = '' if tags.length.positive?

    tags.each do |t|
      q['tag'] += t + ','
    end # tags.each
    q['tag'].chop! if tags.length.positive?

    if @debug
      puts 'debug: importToItem: query section:'
      ap q
      puts 'debug importToItem: xml body'
      puts mdtext
    end # if(@debug)
    #    raise StandardError("Testing")

    vsdoc = @parent.request("/storage/#{@parent.id}/file/#{@id}/import",
                            method: 'POST',
                            query: q,
                            body: mdtext)
    import_job = VSJob.new(@parent.host, @parent.port, @parent.user, @parent.passwd)
    import_job.fromResponse(vsdoc)
    import_job
  end # def importToItem

  def close
    require 'net/http'
    uri = URI.parse("http://#{@parent.host}:#{@parent.port}/API/storage/file/#{@id}/state/CLOSED")
    request = Net::HTTP::Put.new uri.path
    request.basic_auth(@parent.user, @parent.passwd)
    response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }
    response.body
  end # def close
end # class VSFile

class VSStorageMethod
  attr_accessor :id
  attr_accessor :uri
  attr_accessor :read
  attr_accessor :write
  attr_accessor :browse
  attr_accessor :last_success
  attr_accessor :type

  def initialize(xmlchunk, parent)
    @parent = parent

    @id = parent.valueForXpath(xmlchunk, 'vs:id')
    @uri = URI(parent.valueForXpath(xmlchunk, 'vs:uri'))
    @read = parent.valueForXpath(xmlchunk, 'vs:read')
    @write = parent.valueForXpath(xmlchunk, 'vs:write')
    @browse = parent.valueForXpath(xmlchunk, 'vs:browse')
    last_success_string = parent.valueForXpath(xmlchunk, 'vs:id')
    begin
      @last_success = DateTime.rfc3339(last_success_string)
    rescue Exception => e
      puts "WARNING: #{e.message}"
    end
    @type = parent.valueForXpath(xmlchunk, 'vs:type')
  end
end # class VSStorageMEthod
