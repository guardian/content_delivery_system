# frozen_string_literal: true

require 'Vidispine/VSApi'
require 'Vidispine/VSShape'
require 'Vidispine/VSJob'
require 'nokogiri'
require 'cgi'

class VSTranscodeError < VSException
end # VSTranscodeError

class VSItem < VSApi
  attr_accessor :id

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: nil, run_as: nil, https: true)
    # super.initialize(host,port,user,passwd,parent: p)
    super

    @processed_xml = nil
    @shapes = nil
    @metadata = {}
    @vs_object_class = 'item'
  end # def initialize

  def populate(itemid, refreshShapes: false)
    if @shapes.nil? || refreshShapes
      @shapes = VSShapeCollection.new(@host, @port, @user, @passwd)
      @shapes.populate(itemid)
    end

    # urlpath="/item/#{itemid}/metadata"
    # @processed_xml=self.request(urlpath,"GET")
    @metadata, @groupname = get_metadata("/item/#{itemid}")
    @id = itemid
  end # def populate

  def import_raw(data, filename, shape_tags: [], initial_metadata: nil, metadata_group: 'Asset', original_shape: nil, thumbs: true, storage_id: nil, priority: 'MEDIUM')
    qparms = {
      'filename' => File.basename(filename)
    }

    qparms['thumbnails'] = 'true' if thumbs

    unless shape_tags.nil?
      shape_tags = [shape_tags] unless shape_tags.is_a?(Array)
      qparms['tag'] = shape_tags.join(',')
    end

    if !shape_tags.nil? && !original_shape.nil?
      unless shape_tags.include?(original_shape)
        raise ArgumentError, 'When importing a file, if original_shape is specified it must be one of the transcode shapes supplied'
      end

      qparms['original'] = original_shape
    end

    qparms['storageId'] = storage_id unless storage_id.nil?
    qparms['priority'] = priority unless priority.nil?

    jobDocument = request('/import/raw', method: 'POST', query: qparms, body: data, content_type: 'application/octet-stream')

    jobdesc = _waitjob(jobDocument)
    @id = jobdesc.itemId
    populate(@id)
  end

  def import_uri(uri, shape_tags: [], initial_metadata: nil, metadata_group: 'Asset', original_shape: nil, thumbs: true, storage_id: nil, priority: 'MEDIUM')
    qparms = {
      'uri' => URI.encode_www_form_component(uri),
      'filename' => File.basename(uri)
    }

    qparms['thumbnails'] = 'true' if thumbs

    unless shape_tags.nil?
      shape_tags = [shape_tags] unless shape_tags.is_a?(Array)
      qparms['tag'] = URI.encode_www_form_component(shape_tags.join(','))
    end

    if !shape_tags.nil? && !original_shape.nil?
      unless shape_tags.include?(original_shape)
        raise ArgumentError, 'When importing a file, if original_shape is specified it must be one of the transcode shapes supplied'
      end

      qparms['original'] = original_shape
    end

    qparms['storageId'] = URI.encode_www_form_component(storage_id) unless storage_id.nil?
    qparms['priority'] = priority unless priority.nil?

    filebase = File.basename(uri)
    if initial_metadata.nil?
      raise ArgumentError, "import_uri: you must set some initial metadata by providing a hash to initial_metadata:, i.e. initial_metadata: {'title': 'rhubarb'}"
    end
    if !initial_metadata.is_a?(Hash) || initial_metadata.empty?
      raise ArgumentError, "import_uri: initial_metadata must be a Hash of fieldname-value pairs containing at least one element (hint: {'title'=>'my title'})"
    end

    initial_metadata['originalFilename'] = filebase unless initial_metadata.include?('originalFilename')

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.MetadataDocument({ xmlns: 'http://xml.vidispine.com/schema/vidispine' }) do
        xml.group(metadata_group)
        xml.timespan({ start: '-INF', end: '+INF' }) do
          initial_metadata.each do |k, v|
            xml.field do
              xml.name(k)
              xml.value(v)
            end # xml.field
          end # initial_metadata.each
        end # xml.timespan
      end # xml.MetadataDocument
    end # Nokogiri::XML::Builder.new

    jobDocument = request('/import', method: 'POST', query: qparms, body: builder.to_xml)

    _waitjob(jobDocument)
  end

  def refresh(refreshShapes: true)
    populate(@id, refreshShapes: refreshShapes)
  end # def refresh

  def refresh!(refreshShapes: true)
    refresh(refreshShapes: refreshShapes)
  end

  attr_reader :metadata

  attr_reader :shapes # def shapes

  def get(key)
    @metadata[key]
  end

  def include?(key)
    @metadata.include?(key)
  end

  def getMetadata
    @metadata
  end # def getMetadata

  def _waitjob(jobDocument)
    puts jobDocument.to_xml(indent: 2) if @debug
    jobid = -1
    jobDocument.xpath('//vs:jobId', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |idnode|
      jobid = idnode.inner_text
      # puts "found id #{idnode.inner_text}"
    end # jobId

    raise NameError, 'Unable to get job ID!!' if jobid == -1

    # puts "found job at id #{jobid}"
    job = nil
    loop do
      job = VSJob.new(@host, @port, @user, @passwd)
      job.populate(jobid)
      # unless(silent)
      #     ap job
      puts "Job #{jobid} has status #{job.status}"
      # end

      if job.finished?(noraise: false) # this will raise VSJobFailed if there was an error
        # reload our shapes
        @shapes = VSShapeCollection.new(@host, @port, @user, @passwd)
        @shapes.populate(@id)
        break
      end

      sleep(20)
    end
    job
  end

  def transcode!(shapetag, priority: 'MEDIUM', silent: 'false')
    jobDocument = request("/item/#{@id}/transcode", method: 'POST',
                                                    query: { 'priority' => priority,
                                                             'tag' => URI.encode_www_form_component(shapetag) })
    # it's up to the caller to catch exceptions...

    _waitjob(jobDocument)

    # reload our shapes
    @shapes = VSShapeCollection.new(@host, @port, @user, @passwd)
    @shapes.populate(@id)
  end # def transcode!

  # sets metadata fields on this item. Should be called as item.setMetadata({'field': 'value', 'field2': 'value2' etc.})
  # will throw exceptions (VS* or HTTPError) and not update the internal representation if the Vidispine update fails
  def setMetadata(mdhash, groupname: @groupname, vsClass: 'item')
    raise ArgumentError if vsClass.match(/[^a-z]/)

    # we can't use self.set_metadata as this gives a SimpleMetadataDocument, wherase we need the full monty for items
    # self.set_metadata("/item/#{@id}",mdhash,groupname)
    xmlBuilder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.MetadataDocument('xmlns' => 'http://xml.vidispine.com/schema/vidispine') do
        xml.timespan('start' => '-INF', 'end' => '+INF') do
          if groupname
            xml.group do
              xml.name groupname
              mdhash.each do |key, value|
                xml.field do
                  xml.name key
                  if value.is_a?(Array)
                    value.each do |v|
                      xml.value v
                    end # value.each
                  else
                    xml.value value
                  end # if value.is_a?(Array)
                end
              end # mdhash.each
            end
          else
            mdhash.each do |key, value|
              xml.field do
                xml.name key
                if value.is_a?(Array)
                  value.each do |v|
                    xml.value v
                  end # value.each
                else
                  xml.value value
                end # if value.is_a?(Array)
              end
            end # mdhash.each
          end # if(groupname)
        end # <timespan>
      end # <MetadataDocument>
    end # Nokogiri::XML::Builder.new

    doc = xmlBuilder.to_xml

    if @debug
      puts "item::setMetadata: debug: xml to send:\n"
      puts doc
    end
    request("/#{vsClass}/#{@id}/metadata", method: 'PUT', body: doc) # ,matrix={'projection'=>'default'} )

    mdhash.each do |_key, value|
      @metadata['key'] = value
    end
  end # def setMetadata

  # downloads file content and yields to block
  def fileData(shapeTag: 'original', &block)
    requiredShapes = shapes.shapeForTag(shapeTag) # should raise an exception if shapetag is not found
    requiredShapes.fileData(block)
  end

  def addAccess(access)
    super("/#{@vs_object_class}/#{@id}", access)
  end

  def importMetadata(readyXML, projection: nil)
    begin
      # validate the XML with Nokogiri before passing it to Vidispine
      Nokogiri::XML(readyXML, &:strict)
    rescue Nokogiri::XML::SyntaxError => e
      if @logger
        @logger.error("Invalid XML passed to importMetadata: #{e}")
      else
        warn "Invalid XML passed to importMetadata: #{e}"
      end
    end

    if projection
      request("/#{@vs_object_class}/#{@id}/metadata", method: 'PUT', matrix: { 'projection' => projection }, body: readyXML)
    else
      request("/#{@vs_object_class}/#{@id}/metadata", method: 'PUT', body: readyXML)
    end
  end
end
