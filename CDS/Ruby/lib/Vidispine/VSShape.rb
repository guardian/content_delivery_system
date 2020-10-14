# frozen_string_literal: true

require 'Vidispine/VSApi'
require 'awesome_print'
require 'uri'
require 'date'

class VSShapeCollection < VSApi
  include Enumerable

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: nil)
    # super.initialize(host,post,user,passwd,parent: p)
    super(host, port, user, passwd, parent: parent)

    puts 'debug: VSShapeCollection::initialize'
    @shapes = []
  end # def initialize

  def populate(itemid)
    unless itemid.nil?
      urlpath = "/item/#{itemid}/shape"
      vsdoc = request(urlpath, method: 'GET')

      # ap vsdoc

      vsdoc.xpath('//vs:uri', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |node|
        # ap node
        begin
          shapename = node.inner_text
          newshape = VSShape.new(@host, @port, @user, @passwd)
          newshape.populate(itemid, shapename)
          @shapes << newshape
        rescue Exception => e
          puts "-WARNING: an error occurred setting up new shape: #{e.message}"
        end # exception block
      end # xpath search
    end # if(itemid!=nil)
  end # def populate

  def each
    @shapes.each { |s| yield s }
  end

  def shapeForTag(tagname, scheme: nil, mustExist: false, noraise: false, refresh: false)
    @shapes.each do |s|
      next unless s.tag == tagname

      s.refresh! if refresh
      # check if the file actually exists. If not, keep lookin'...
      #            if(scheme and not File.exists?(URI.unescape(s.fileURI(scheme: scheme).path)))
      #    next
      # end
      if scheme
        s.eachFileURI(scheme: scheme) do |u|
          return s unless mustExist
          return s if File.exist?(URI.unescape(u.path))
        end # s.eachFileURI
        next
      end # if(scheme)
      return s
    end
    return nil if noraise

    raise VSNotFound, "No shape with tag #{tagname} could be found"
  end # shapeForTag

  def eachShapeForTag(tagname, noraise: false, refresh: false, &block)
    @shapes.each do |s|
      next unless s.tag == tagname

      s.refresh! if refresh
      block.call(s)
    end
    return nil if noraise

    raise VSNotFound, "No shape with tag #{tagname} could be found"
  end # def eachShapeForTag
end # class VSShapeCollection

class VSShape < VSApi
  attr_accessor :id, :tag

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: p)
    super
    @id = nil
    @tag = nil
    @item = nil
  end # def initialize

  def populate(itemid, shapeid)
    urlpath = "/item/#{itemid}/shape/#{shapeid}"
    @item = itemid
    @processed_xml = request(urlpath, method: 'GET')
    @processed_xml.xpath('//vs:ShapeDocument/vs:tag', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |node|
      @tag = node.inner_text
    end
    @processed_xml.xpath('//vs:ShapeDocument/vs:id', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |node|
      @id = node.inner_text
    end
  end

  def refresh!
    populate(@item, @id)
  end

  def eachFileURI(scheme: nil)
    @processed_xml.xpath('//vs:containerComponent/vs:file', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |node|
      uriNode = node.xpath('vs:uri', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      uri = (URI(uriNode.inner_text) if uriNode)
      storageNode = node.xpath('vs:storage', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      storageName = storageNode&.inner_text
      # yield URI(node.inner_text)
      # if the caller has requested a specific scheme, check that we match
      if scheme
        next if uri.scheme != scheme
      end # if(scheme)
      yield uri, storageName
    end
    URI('')
  end # def eachFileURI

  # kept for backwards compatibility
  def fileURI(scheme: nil)
    eachFileURI(scheme: scheme) do |u|
      return u
    end
  end # def fileURI

  def fileData
    @processed_xml.xpath('//vs:containerComponent/vs:file', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |node|
      idNode = node.xpath('vs:id', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      next unless idNode

      url = "/storage/file/#{idNode.inner_text}/data"
      request(url, method: 'GET', accept: '*') do |data|
        # puts "fileData: request"
        yield data
      end
      return
    end
    raise VSNotFound, 'No shapes with valid container components found'
  end
end # class VSShape

class StreamingImport < VSApi
  attr_accessor :stream, :chunkSize

  class ImportInProgress < StandardError
  end

  class NoImportStarted < StandardError
  end

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: nil, stream: nil)
    super(host, port, user, passwd, parent: parent)
    @stream = stream
    @importLength = -1
    @chunkSize = 1e6 # 1mb chunk size by default
    @transferId = nil
    @total_imported = 0
    @targetItem = nil
    @shapeTag = 'original'
  end # def initialize

  def start(targetItem: nil, shapeTag: 'original', importLength: 0)
    raise ImportInProgress unless @transferId.nil?

    raise TypeError, 'shapeTag must be a string' unless shapeTag.is_a?(string)
    raise ValueError, 'importLength must be > 0' if importLength <= 0

    @targetItem = targetItem
    @transferId = if @targetItem
                    @targetItem + ':' + shapeTag + '_' + date.strftime('%y%m%d%H%M%S')
                  else
                    'NEW' + ':' + shapeTag + '_' + date.strftime('%y%m%d%H%M%S')
                  end

    @importLength = importLength
    @shapeTag = shapeTag
  end

  def write_chunk(data, length: nil)
    raise NoImportStarted if @transferId.nil?

    if @targetItem
      url = "/item/#{@targetItem}/shape/essence/raw"
    else
      raise StandardError('Streaming import to a new item not supported yet')
    end

    length = @chunkSize if length.nil?

    to_write = if data.is_a?(IO)
                 data.read(length)
               else
                 data
               end

    request(url, method: 'POST', query: {
              'transferId' => @transferId,
              'tag' => @shapeTag
            }, headers: {
              'Content-Type' => 'application/octet-stream',
              'size' => length,
              'index' => @total_imported
            },
                 body: to_write)

    @total_imported += length
  end

  def write(&block) # expects a block that should return a length, data tuple. Return 0, nil to complete.
    loop do
      length, data = block.call
      break if data.nil?

      write_chunk(data, length: length)
    end
  end

  def end(args)
    # code
  end
end
