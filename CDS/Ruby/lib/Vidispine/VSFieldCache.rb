# frozen_string_literal: true

require 'Vidispine/VSApi'
require 'awesome_print'
require 'JSON'

class NoFieldsPresentException < VSException
end

class VSFieldCache < VSApi
  include Enumerable
  # @by_VSName,@by_PortalName,@by_Group

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '')
    super
    @by_VSName = {}
    @by_PortalName = {}
    @by_Group = {}
  end

  def refresh
    warn 'Loading field definitions...' if @debug

    data = request('/metadata-field', method: 'GET', matrix: nil, query: { 'data' => 'all' })
    # ap data

    warn 'Parsing provided data...' if @debug

    data.xpath('//vs:field', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |node|
      field = {}
      field['vs_name'] = node.xpath('vs:name', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
      field['vs_type'] = node.xpath('vs:type', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
      field['vs_origin'] = node.xpath('vs:origin', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
      field['default'] = node.xpath('vs:defaultValue', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text

      field['vs_extradata'] = node.xpath("vs:data/vs:key[text()='extradata']/../vs:value", 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text

      if field['vs_extradata'].start_with?('{')
        begin
          portaldata = JSON.parse(field['vs_extradata'])
          portaldata.each do |key, value|
            field['portal_' + key] = value
          end # portaldata.each

          @by_PortalName[field['portal_name']] = field
        rescue JSON::JSONError => e
          warn "WARNING - JSON parsing error: #{e.message}"
        end # json parsing block
      end # start_with

      @by_VSName[field['vs_name']] = field
    end # data.xpath().each

    # ap @by_VSName
    # ap @by_PortalName
  end # def refresh

  def lookupByPortalName(name)
    if @by_PortalName.count < 1
      refresh
      raise NoFieldsPresentException, 'No Portal-created fields were found!' if @by_PortalName.count < 1
    end

    return @by_PortalName[name] if @by_PortalName[name].is_a?(Hash)

    raise VSNotFound, "lookupByPortalName: No field could be found with Portal name #{name}"
  end # def lookupByPortalName

  def lookupByVSName(name)
    if @by_VSName.count < 1
      refresh
      raise NoFieldsPresentException, 'No fields were found!' if @by_VSName.count < 1
    end

    return @by_VSName[name] if @by_VSName[name].is_a?(Hash)

    raise VSNotFound, "lookupByVSName: No field could be found with name #{name}"
  end # def lookupByVSName

  def each
    @by_VSName.each do |_vsname, field|
      yield field
    end
  end
end # class VSFieldCache
