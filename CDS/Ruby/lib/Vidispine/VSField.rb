# frozen_string_literal: true

require 'Vidispine/VSApi'
require 'nokogiri'

class VSField < VSApi
  attr_accessor :name
  attr_accessor :type
  attr_accessor :origin
  attr_accessor :default_value
  attr_accessor :extradata

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '')
    super
    # if(hashData)
    #    @data = hashData
    # end
    @dataContent = nil
    @name = ''
    @type = ''
    @origin = ''
    @default_value = ''
    @extradata = ''
  end

  def name=(newname)
    @dataContent.xpath('vs:name', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text = newname
  end

  def populate(fieldname)
    @dataContent = request("/metadata-field/#{fieldname}", method: 'GET', query: { 'data' => 'all' })

    @name = @dataContent.xpath('//vs:name', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
    @type = @dataContent.xpath('//vs:type', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
    @origin = @dataContent.xpath('//vs:origin', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
    @default_value = @dataContent.xpath('//vs:defaultValue', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text

    @extradata = @dataContent.xpath("//vs:data/vs:key[text()='extradata']/../vs:value", 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
  end # def populate

  # Copies the field definition to a new one
  def copyTo(newfield)
    requestBody = @dataContent
    requestBody.xpath('//vs:name', 'vs' => 'http://xml.vidispine.com/schema/vidispine').remove

    # puts "debug: xml to send to vidispine:"
    #    puts requestBody.to_xml

    request("/metadata-field/#{newfield}", method: 'PUT', body: requestBody.to_xml)
  end # def copyTo
end # class VSField
