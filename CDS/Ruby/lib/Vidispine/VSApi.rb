# frozen_string_literal: true

require 'net/http'
require 'base64'
require 'nokogiri'
require 'awesome_print'
require 'Vidispine/VSAcl'
require 'retryable'

class HTTPError < StandardError; end

class VSException < StandardError
  attr_accessor :message, :id, :context, :type, :code

  def initialize(xmlstring)
    @id = 'unknown'
    @context = 'unknown'
    @type = 'unknown'
    @code = 'unknown'
    @message = 'unknown'

    xmldata = nil
    if xmlstring.is_a?(Net::HTTPResponse)
      @code = xmlstring.code
      xmlstring = xmlstring.body
    end
    if xmlstring.is_a?(String)
      begin
        xmldata = Nokogiri::XML(xmlstring.chomp)
      rescue Exception => e
        @message = xmlstring
        return
      end
    end

    unless xmldata.nil?
      exceptnode = xmldata.xpath('vs:ExceptionDocument/*', 'vs' => 'http://xml.vidispine.com/schema/vidispine')[0]
      unless exceptnode
        @message = xmlstring
        return
      end
      @type = exceptnode.name
      @context = exceptnode.xpath('vs:context', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
      @id = exceptnode.xpath('vs:id', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
      @message = exceptnode.xpath('vs:explanation', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
    end
  end

  def to_s
    rtn = "Vidispine Exception Details:\n"
    rtn += "\tClass: " + self.class.name + "\n"
    rtn += "\tID of affected object: #{@id}\n"
    rtn += "\tContext: #{@context}\n"
    rtn += "\tMessage: #{@message}\n"
    rtn += "\tResponse code: #{@code}\n"
    rtn
  end
end

class VSInvalidInput < VSException; end
class VSNotFound < VSException; end
class VSPermissionDenied < VSException; end

class VSApi
  attr_accessor :debug

  def initialize(host = 'localhost', port = 8080, user = '', passwd = '', parent: nil, run_as: nil, https: true)
    @id = nil

    if parent
      @user = parent.user
      @passwd = parent.passwd
      @host = parent.host
      @port = parent.port
      @debug = parent.debug
      @run_as = parent.run_as
      @https = parent.https
    else
      @user = user
      @passwd = passwd
      @host = host
      @port = port
      @debug = false
      @run_as = run_as
      @retry_delay = 5
      @retry_times = 10
      @https = https
      @attempt = 0
    end
  end

  def initialize_headers(rq, h)
    h.each do |key, value|
      rq.add_field(key, value)
    end
  end

  def sendAuthorized(_conn, method, url, body, headers)
    if @https
      puts 'debug: sendAuthorized using https'
    else
      puts 'debug: sendAuthorized using http only'
    end

    headers ||= {}
    headers['RunAs'] = @run_as unless @run_as.nil?

    uri = URI(url)
    response = nil

    case method.downcase
    when 'get'
      rq = Net::HTTP::Get.new(uri)
    when 'post'
      rq = Net::HTTP::Post.new(uri)
    when 'put'
      rq = Net::HTTP::Put.new(uri)
    when 'delete'
      rq = Net::HTTP::Delete.new(uri)
    when 'head'
      rq = Net::HTTP::Head.new(uri)
    when 'options'
      rq = Net::HTTP::Options.new(uri)
    else
      raise HTTPError, "VSApi::SendAuthorized: #{method} is not a recognised HTTP method"
    end

    rq.body = body
    initialize_headers(rq, headers)
    rq.basic_auth(@user, @passwd)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 10 # seconds
    http.read_timeout = 60 # seconds

    if block_given?
      http.request(rq) do |response|
        response.read_body do |segment|
          yield segment
        end
        return response
      end
    else
      Retryable.retryable(tries: 3, on: [OpenSSL::SSL::SSLError, Net::ReadTimeout, Net::OpenTimeout], sleep: 5) do
        response = http.request(rq)
      end
    end
  end

  class NeedRedirectException < StandardError; end
  class ServerUnavailable < StandardError; end

  def request(path, method: 'GET', matrix: nil, query: nil, body: nil, headers: {}, accept: 'application/xml', content_type: 'application/xml')
    puts "debug: request - block given is #{block_given?}" if @debug

    begin
      if block_given?
        response = raw_request(path, method, matrix, query, body, headers: headers, content_type: content_type, accept: accept) do |b|
          yield b
        end
      else
        response = raw_request(path, method, matrix, query, body, headers: headers, content_type: content_type, accept: accept)
      end

      raise HTTPError, 'No response came back from request' if response.is_a?(NilClass)

      if response.is_a?(Net::HTTPSuccess)
        return if block_given?

        return Nokogiri::XML(response.body)
      end

      raise VSPermissionDenied, response if response.code == '401' || response.code == '403'
      raise VSNotFound, response if response.code == '404'
      raise VSInvalidInput, response if response.code == '400'
      raise ServerUnavailable, response if response.code == '503'
      raise NeedRedirectException, response['Location'] if response.code == '303'

      raise HTTPError, "#{response.body} (#{response.code})"
    rescue NeedRedirectException => e
      puts "debug: VSAPI::Request: redirecting to #{e.message}" if @debug
      path = e.message
      retry
    rescue VSPermissionDenied => e
      @attempt += 1
      raise e if @attempt > @retry_times
      puts "-WARNING: VSAPI::Request: permission denied error accessing #{e.context} #{e.id}: #{e.message} on attempt #{@attempt}"
      sleep(@retry_delay)
      retry
    rescue ServerUnavailable => e
      @attempt += 1
      raise ServerUnavailable, response if @attempt > @retry_times
      puts "debug: VSAPI::Request: Got 503 error on attempt #{@attempt} of #{@retry_times}" if @debug
      sleep(@retry_delay)
      retry
    rescue OpenSSL::SSL::SSLError => e
      @attempt += 1
      raise e if @attempt > @retry_times
      puts "debug: VSAPI::Request: SSL error on attempt #{@attempt} of #{@retry_times} - #{e.message}"
      sleep(@retry_delay)
      retry
    end
  end

  def raw_request(path, method = 'GET', matrix = nil, query = nil, body = nil, headers: {}, content_type: 'application/xml', accept: 'application/xml')
    base_headers = { 'Accept' => accept, 'Content-Type' => content_type }
    base_headers.merge!(headers) unless headers.nil?

    matrixpart = ''
    unless matrix.nil?
      matrix.each do |key, value|
        matrixpart += ";#{key}=#{URI.escape(value, %r{[^:/\w\d]})}"
      end
      puts "VSApi::raw_request: matrix part is #{matrixpart}" if @debug
    end

    querypart = ''
    unless query.nil?
      querypart = '?'
      query.each do |key, value|
        querypart += "#{key}=#{URI.escape(value, %r{[^:/\w\d]})}&"
      end
      querypart.chomp!('&')
      puts "VSApi::raw_request: query part is #{querypart}" if @debug
    end

    protopart = 'http://'
    protopart = 'https://' if @https
    url = if path !~ /^http/
            protopart + @host + ':' + @port.to_s + '/API' + path + matrixpart + querypart
          else
            path + matrixpart + querypart
          end

    if @debug
      puts "VSApi::raw_request: url is #{url}"
      ap base_headers
      puts "VSApi::raw_request: body is #{body}" if content_type != 'application/octet-stream'
    end

    if block_given?
      sendAuthorized(nil, method, url, body, base_headers) do |b|
        yield b
      end
    else
      sendAuthorized(nil, method, url, body, base_headers)
    end
  end

  def get_access(path)
    data = request("/#{path}/access", method: 'GET')
    VSACL.new(xmldoc: data)
  end

  def set_metadata(path, md, groupname)
    doc = '<SimpleMetadataDocument xmlns="http://xml.vidispine.com/schema/vidispine">'
    doc += '<group name="' + groupname + '">' if groupname

    md.each do |key, value|
      doc += "\n<field><key>#{key}</key><value>#{value}</value></field>"
    end

    doc += '</group>' if groupname
    doc += '</SimpleMetadataDocument>'
    path += '/metadata'

    if @debug
      puts "\ndebug: set_meta about to send this XML:\n"
      puts doc
      puts "\n"
    end
    request(path, method: 'PUT', matrix: nil, query: nil, body: doc)
  end

  def get_metadata(path)
    path += '/metadata'

    data = request(path, method: 'GET')
    groupname = nil
    data.xpath('//vs:group', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |groupnode|
      groupname = groupnode.inner_text
    end

    rtn = {}
    data.xpath('//vs:field', 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |node|
      key = node.xpath('vs:name', 'vs' => 'http://xml.vidispine.com/schema/vidispine').inner_text
      val = node.xpath('vs:value', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      if val.count > 1
        if rtn[key].nil?
          rtn[key] = []
        elsif !rtn[key].is_a?(Array)
          rtn[key] = [rtn[key]]
        end

        val.each do |entry|
          rtn[key] << entry.inner_text
        end
      else
        if rtn[key].is_a?(Array)
          rtn[key] << val.inner_text
        elsif rtn[key]
          rtn[key] = [rtn[key], val.inner_text]
        else
          rtn[key] = val.inner_text
        end
      end
    end
    [rtn, groupname]
  end

  def valueForXpath(data, path)
    data.xpath(path, 'vs' => 'http://xml.vidispine.com/schema/vidispine').each do |n|
      if block_given?
        yield n.text
      else
        return n.text
      end
    end
    nil
  end

  def addAccess(path, access)
    raise TypeError, 'You need to pass a VSAccess to addAccess' unless access.is_a?(VSAccess)

    request("#{path}/access", method: 'POST', body: access.to_xml)
  end

  protected

  def output_xml_fieldgroup(xml, metadata, top: false)
    metadata.each do |k, values|
      if values.is_a?(Hash)
        xml.group do
          xml.name k
          output_xml_fieldgroup(xml, values, top: false)
        end
      else
        values = [values] unless values.is_a?(Array)
        xml.field do
          xml.name k
          values.each do |v|
            xml.value v
          end
        end
      end
    end
  end

  def mdhash_to_xml(metadata, documentType: 'MetadataDocument', group: nil)
    return nil if metadata.nil?
    raise StandardError, 'You need to pass a hash to mdhash_to_xml' unless metadata.is_a?(Hash)

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.method_missing(documentType, 'xmlns' => 'http://xml.vidispine.com/schema/vidispine') do
        xml.group(group) if group
        xml.timespan('start' => '-INF', 'end' => '+INF') do
          output_xml_fieldgroup(xml, metadata, top: true)
        end
      end
    end

    doc = builder.to_xml
    puts 'debug: VSApi::mdhash_to_xml'
    puts 'source data:'
    ap metadata
    puts 'generated document'
    puts doc
    puts '---------------------------'
    doc
  end

  def makeMetadataDocument(metadata)
    mdhash_to_xml(metadata, documentType: 'MetadataDocument')
  end

  def makeItemSearchDocument(metadata)
    mdhash_to_xml(metadata, documentType: 'ItemSearchDocument')
  end
end
