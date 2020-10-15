# frozen_string_literal: true

require 'Vidispine/VSApi'
require 'date'
require 'awesome_print'

class VSJobFailed < VSException
  def initialize(xmlstring, failedJob = nil)
    puts "debug: VSJobFailed: #{xmlstring}"
    puts "debug: VSJobFailed: #{failedJob}"
    super(xmlstring)
    @failedJob = failedJob
    self
  end

  def to_s
    "Job #{@failedJob.id} of type #{@failedJob.type} failed"
  end # def to_s

  def message
    to_s
  end

  attr_reader :failedJob
end # class VSJobFailed

class VSJob < VSApi
  attr_accessor :id
  attr_accessor :submitted_user
  attr_accessor :started
  attr_accessor :status
  attr_accessor :type
  attr_accessor :priority
  attr_accessor :progress

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: nil)
    super

    @id = ''
    @submitted_user = ''
    @started = ''
    @status = ''
    @type = ''
    @priority = ''
    @progress = 0
    @meta = {}
  end # def initialize

  def refresh
    populate(@id)
  end

  def populate(itemid)
    @id = itemid
    @metadata = _parse(request("/job/#{itemid}", method: 'GET'))
  end # def populate

  def fromResponse(vsdoc)
    _parse(vsdoc)
  end # def fromResponse

  def _read_data(node)
    # reads a generic metadata node
    key = ''
    val = ''

    node.children.each do |n|
      case n.name
      when 'key'
        key = n.inner_text
      when 'value'
        val = n.inner_text
      end
    end
    [key, val]
  end

  def _parse(jobdoc)
    # print jobdoc.to_xml
    rootNode = jobdoc.root
    # ap jobdoc
    # ap rootNode

    rootNode.children.each do |n|
      # puts "debug: got #{n.name}"
      case n.name
      when 'jobId'
        @id = n.inner_text
      when 'user'
        @submitted_user = n.inner_text
      when 'started'
        begin
            @started = Date.rfc3339(n.inner_text)
        rescue Exception => e
          puts "WARNING: #{e.message}"
          @started = n.inner_text
          end
      when 'status'
        @status = n.inner_text
      when 'type'
        @type = n.inner_text
      when 'priority'
        @priority = n.inner_text
      when 'data'
        k, v = _read_data(n)
        @meta[k] = v
      end
    end # rootNode.children.each

    # if there's a progress node, we'll 'ave that too...
    rootNode.xpath('//vs:progress', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |prognode|
      @progress = prognode.inner_text
    end
  end # _parse

  def itemId
    raise ArgumentError, 'No item reference found in job' unless @meta.include?('item')

    @meta['item']
  end

  def failed?
    if @status.match(/^FAILED/)
      return true
    elsif @status.match(/^ABORTED/)
      return true
    end # if @status.match

    false
  end # def failed?

  def aborted?
    return true if @status.match(/^ABORTED/)

    false
  end # def aborted?

  attr_reader :status

  def hasWarning?
    return true if @status.match(/_WARNING/)

    false
  end

  def finished?(noraise: true)
    return true if @status.match(/^FINISHED/)

    if failed?
      if noraise
        return true
      else
        raise VSJobFailed.new('', self)
      end # if(noraise)
    end # if(self.failed?)
    false
  end
end # class VSJob
