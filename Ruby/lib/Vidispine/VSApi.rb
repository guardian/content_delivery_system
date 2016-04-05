require 'net/http'
require 'base64'
require 'nokogiri'
require 'awesome_print'
require 'Vidispine/VSAcl'

class HTTPError < StandardError
end

class VSException < StandardError
    attr_accessor :message
    
    def initialize(xmlstring)
        @id="unknown"
        @context="unknown"
        @type="unknown"
        @code="unknown"
        @message="unknown"
        
        xmldata=nil
        if(xmlstring.is_a?(Net::HTTPResponse))
            @code=xmlstring.code
            xmlstring=xmlstring.body
        end
        if(xmlstring.is_a?(String))
	    xmlstring.chomp!
	    begin
		xmldata=Nokogiri::XML(xmlstring)
	    rescue Exception=>e #if the xml parse fails, assume what we were given isn't XML
		@message=xmlstring
		return
	    end
	end
        
        if xmldata!=nil
	    exceptnode=xmldata.xpath("vs:ExceptionDocument/*",'vs'=>"http://xml.vidispine.com/schema/vidispine")[0]
	    unless(exceptnode)  #if we don't have an ExceptionDocument node, then assume it isn't parseable
		@message=xmlstring
		return
	    end
	    @type=exceptnode.name()
	    @context=exceptnode.xpath("vs:context",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	    @id=exceptnode.xpath("vs:id",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	    @message=exceptnode.xpath("vs:explanation",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	end #if xmldata!=nil
    end
    
    def to_s
        rtn=""
        rtn="Vidispine Exception Details:\n"
        rtn+="\tClass: "+self.class.name+"\n"
        rtn+="\tID of affected object: #{@id}\n"
        rtn+="\tContext: #{@context}\n"
        rtn+="\tMessage: #{@message}\n"
        rtn+="\tResponse code: #{@code}\n"
        
        return rtn
    end
end

class VSInvalidInput < VSException
end

class VSNotFound < VSException
end

class VSApi
attr_accessor :debug

def initialize(host="localhost",port=8080,user="",passwd="",parent: nil)
    #puts "debug: VSApi::initialize: #{host} #{port} #{user} #{passwd}"
   @id=nil
   
if(parent)
    #puts "debug: VSApi::initialize: init from parent object"
    @user=parent.user
    @passwd=parent.passwd
    @host=parent.host
    @port=parent.port
    @debug=parent.debug
 #   @retry_delay=parent.retry_delay
 #   @retry_times=parent.retry_times
else
    @user=user
    @passwd=passwd
    @host=host
    @port=port
    @debug=false
    @retry_delay=5
    @retry_times=10
    @attempt=0
end

end #def initialize

def initialize_headers(rq,h)

h.each do |key,value|
	rq.add_field(key,value)
end

end

def sendAuthorized(conn,method,url,body,headers,&block)
#auth=Base64.encode64("#{@user}:#{@passwd}".gsub("\n",""))

if(headers==nil)
	headers=Hash.new
end

if @debug
    #puts "debug: sendAuthorized - block given is #{block_given?}"
end

#headers['Authorization']="Basic #{auth}"

uri=URI(url)
response=nil

case method.downcase
when 'get'
	rq=Net::HTTP::Get.new(uri)
	rq.body=body
	initialize_headers(rq,headers)
	rq.basic_auth(@user,@passwd)
when 'post'
	rq=Net::HTTP::Post.new(uri)
	rq.body=body
	initialize_headers(rq,headers)
	rq.basic_auth(@user,@passwd)
when 'put'
	rq=Net::HTTP::Put.new(uri)
	rq.body=body
	initialize_headers(rq,headers)
	rq.basic_auth(@user,@passwd)
when 'delete'
	rq=Net::HTTP::Delete.new(uri)
	rq.body=body
	initialize_headers(rq,headers)
	rq.basic_auth(@user,@passwd)
when 'head'
	rq=Net::HTTP::Head.new(uri)
	rq.body=body
	initialize_headers(rq,headers)
	rq.basic_auth(@user,@passwd)	
when 'options'
	rq=Net::HTTP::Options.new(uri)
	rq.body=body
	initialize_headers(rq,headers)
	rq.basic_auth(@user,@passwd)
else
	raise HTTPError, "VSApi::SendAuthorized: #{method} is not a recognised HTTP method"
end


#ap rq

response=nil
http=Net::HTTP.new(uri.host,uri.port)
if(block_given?)
    #puts "DEBUG: VSApi::sendAuthorized: using block return"
    http.request(rq) do |response|
        response.read_body do |segment|
	    #puts "DEBUG: VSAPI::sendAuthorized: sending segment #{segment}"
            yield segment
        end #response.read_body
        return response
    end #http.request
else
    #puts "DEBUG: VSApi::sendAuthorized: using conventional return"
    response=http.request(rq)
    return response
end

end

class NeedRedirectException < StandardError
end

class ServerUnavailable < StandardError
end

def request(path,method: "GET",matrix: nil,query: nil,body: nil,headers: {}, accept: "application/xml", content_type: 'application/xml')

if @debug
    #puts "debug: request - block given is #{block_given?}"
end

begin
    if block_given?
	response=self.raw_request(path,method,matrix,query,body,headers: headers,content_type: content_type, accept: accept) do |b|
	    yield b
	end
    else
	response=self.raw_request(path,method,matrix,query,body,headers: headers,content_type: content_type, accept: accept)
    end
    
    if response.is_a?(NilClass)
	    raise HTTPError, "No response came back from request"
    end
    
    if response.is_a?(Net::HTTPSuccess)
		return if block_given?
	    return Nokogiri::XML(response.body)
    end
    
    raise VSNotFound.new(response) if response.code=="404"
    raise VSInvalidInput, response if response.code=="400"
    raise ServerUnavailable, response if response.code=="503"
    raise NeedRedirectException, response['Location'] if response.code=="303"

    raise HTTPError, "#{response.body} (#{response.code})"
    
rescue NeedRedirectException=>e
    if self.debug
	puts "debug: VSAPI::Request: redirecting to #{e.message}"
    end
    
    path = e.message
    retry

rescue ServerUnavailable=>e
    @attempt+=1
    if @attempt > @retry_times
	raise ServerUnavailable, response
    end
    
    if self.debug
	puts "debug: VSAPI::Request: Got 503 error on attempt #{@attempt} of #{@retry_times}"
    end
    sleep(@retry_delay)
    retry
    

end

end 

def raw_request(path,method="GET",matrix=nil,query=nil,body=nil,headers: {}, content_type: 'application/xml', accept: "application/xml")
base_headers={ 'Accept'=>accept, 'Content-Type'=> content_type }

if headers!=nil
    base_headers.merge!(headers)
end

if @debug
    #puts "debug: raw_request - block given is #{block_given?}"
end
matrixpart=""
if(matrix!=nil)
	matrix.each do |key,value|
		matrixpart+=";#{key}=#{URI.escape(value,/[:\/]/)}"
	end #matrix.each
	if(@debug)
		puts "VSApi::raw_request: matrix part is #{matrixpart}"
	end
end #if(matrix!=nil)

querypart=""
if(query!=nil)
	querypart="?"
	query.each do |key,value|
		querypart+="#{key}=#{URI.escape(value,/[:\/]/)}&"
	end #query.each
	querypart.chomp('&')
	if(@debug)
		puts "VSApi::raw_request: query part is #{querypart}"
	end
end #if(query!=nil)

if not path=~/^http/
    url="http://"+@host+":"+@port.to_s+"/API"+path+matrixpart+querypart
else
    url=path+matrixpart+querypart
end



if(@debug)
    puts "VSApi::raw_request: url is #{url}"
    ap base_headers
    puts "VSApi::raw_request: body is #{body}" if(content_type!='application/octet-stream')
end

if(block_given?)
    #puts "VSApi::raw_request: using block"
    self.sendAuthorized(nil,method,url,body,base_headers) do |b|
        yield b
    end
else
    #puts "VSApi::raw_request: using conventional return"
    return self.sendAuthorized(nil,method,url,body,base_headers)
end

end #def raw_request

def get_access(path)
    data = self.request("/#{path}/access",method="GET")
    return VSACL.new(xmldoc:data)
end #get_access

def set_metadata(path,md,groupname)
	doc='<SimpleMetadataDocument xmlns="http://xml.vidispine.com/schema/vidispine">'
    if(groupname)
        doc+="<group name=\""+groupname+"\">"
    end
    
	md.each do |key,value|
		doc=doc+"\n<field><key>#{key}</key><value>#{value}</value></field>"
	end #md.each

    if(groupname)
        doc+="</group>"
    end
    doc=doc+'</SimpleMetadataDocument>'
	path=path+'/metadata'
	
    if(@debug)
        puts "\ndebug: set_meta about to send this XML:\n";
        puts doc
        puts "\n"
    end
	return self.request(path,method="PUT",matrix=nil,query=nil,body=doc)

end #def set_metadata

def get_metadata(path)
path=path+'/metadata'

data=self.request(path,method: "GET")
groupname=nil
#should only get one of these, really
data.xpath("//vs:group",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |groupnode|
    groupname=groupnode.inner_text
end #groupnode

rtn=Hash.new
data.xpath("//vs:field",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
	key=node.xpath("vs:name",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	val=node.xpath("vs:value",'vs'=>"http://xml.vidispine.com/schema/vidispine")
	if(val.count>1)
	    if not rtn[key]
		rtn[key]=Array.new
	    elsif not rtn[key].is_a?(Array)
		rtn[key]=[rtn[key]]
	    end
	    
	    val.each do |entry|
		rtn[key] << entry.inner_text
	    end
	else
	    if rtn[key].is_a?(Array)
		rtn[key] << val.inner_text
	    elsif rtn[key]
		rtn[key] = [rtn[key],val.inner_text]
	    else
		rtn[key]=val.inner_text
	    end
	end #if(val.count>1)
end
return rtn, groupname

end #def get_metadata

#Return the inner_text content of the given xpath from the nokogiri doc data, or nil if it doesn't exist.
def valueForXpath(data,path)
    data.xpath(path,'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |n|
        if(block_given?)
            yield n.text
        else
            return n.text
        end
    end
    #if(node)
    #    return node.text
    #end
    return nil
end #def valueForXpath

#Adds an entry to the objects ACL. This method is a generic one which is subclassed in actual entities to provide the correct path.
def addAccess(path,access)
    unless(access.is_a?(VSAccess))
        raise TypeError, "You need to pass a VSAccess to addAccess"
    end
    
    self.request("#{path}/access",method: "POST",
                 body: access.to_xml)
end

#private method to recursively generate group sections and field name/value sections depending on data type in the hash
protected
def output_xml_fieldgroup(xml,metadata,top: false)
    metadata.each do |k,values|
        if(values.is_a?(Hash))
            xml.group {
                xml.name k
                self.output_xml_fieldgroup(xml,values, top: false)
            }
            else
            values = [ values ] unless(values.is_a?(Array))
            xml.field {
                xml.name k
                values.each do |v|
                    xml.value v
                end #values.each
            }#xml.field
        end
    end #metadata.each
end #def _output_xml_fieldgroup

#uses nokogiri builder to construct a Vidispine representation of the given metadata hash. Hash should be in fieldname=>fieldvalue or fieldname=>[value1,value2,...] format.
def mdhash_to_xml(metadata, documentType: "MetadataDocument", group: nil)
    return nil if(metadata==nil)
    raise StandardError, "You need to pass a hash to mdhash_to_xml" unless(metadata.is_a?(Hash))
    
    #build the xml document
    builder = Nokogiri::XML::Builder.new do |xml|
        xml.method_missing(documentType, 'xmlns'=>'http://xml.vidispine.com/schema/vidispine') {
            if(group)
                xml.group(group)
            end #if(group)
            xml.timespan('start'=>'-INF', 'end'=>'+INF'){
                #recursively descend the metadata hash, creating fields and groups as we go.
                self.output_xml_fieldgroup(xml,metadata,top: true)
            } #xml.timespan
        } #xml.MetadataDocument
    end # Nokogiri::XML::Builder do |xml|
    
    doc = builder.to_xml
    #if(@debug)
    puts "debug: VSApi::mdhash_to_xml"
    puts "source data:"
    ap metadata
    puts "generated document"
    puts doc
    puts "---------------------------"
    #end
    return doc
end #def mdhash_to_xml

#convenience method to call mdhash_to_xml for setting metadata
def makeMetadataDocument(metadata)
    self.mdhash_to_xml(metadata, documentType: "MetadataDocument")
end

#convenience method to call mdhash_to_xml for generating search document
def makeItemSearchDocument(metadata)
    self.mdhash_to_xml(metadata, documentType: "ItemSearchDocument")
end

end #class VSAPI

