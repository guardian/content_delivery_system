require 'net/http'
require 'nokogiri'
require 'digest/md5'
require 'uri'

class ErrorDocumentParser < Nokogiri::XML::SAX::Document
S_ERROR = 2

attr_accessor :error_list

def start_document
@element_tree = []
@error_list = []
end #start _document

def end_document
end

def start_element(name, attrs = [])
@element_tree << name

puts "ErrorDocumentParser::start_element: #{name}"

if(name == "error")
    newerror = ElementalError.new(nil,nil,nil)
    @error_list << newerror
end

end #start_element

def characters(string)
    current_tag = @element_tree.last
    
    #puts "characters: #{string}"
    #ap @element_tree
    
    if(string == nil or /^[\s\n]*$/.match(string))
        return
    end
    
    current_error=@error_list.last
    if(current_error==nil)
        return
    end
    if(current_tag=="code")
      begin
        current_error.code=Integer(string)
      rescue StandardError=>e
        puts "-WARNING: #{e}"
        current_error.code=string
      end
    end
    if(current_tag=="created_at")
        current_error.created_at=string
    end
    if(current_tag=="message")
        current_error.message=string
    end
    if(current_tag=="error")
        current_error.message=string
    end
end #characters
end #ErrorDocumentParser

class ElementalError
attr_accessor :code
attr_accessor :created_at
attr_accessor :message

def initialize()
    @code=nil
    @created_at=nil
    @message=nil
end

def initialize(code,created_at,message)
    begin
    	@code = Integer(code)
    rescue StandardError=>e
        puts "-WARNING: code '#{code}' could not be converted to number"
        @code = code
    end
    @created_at = created_at
    @message = message
end

end #ElementalError

class ElementalException < StandardError
attr_accessor :errors

def initialize(error_list)
    @errors = error_list
end #def initialize

def message
    str = "#{@errors.count} elemental errors occurred:\n"
    @errors.each do |e|
        if(e.created_at and e.code)
            str+="\t#{e.created_at}: error #{e.code}\n\t\t#{e.message}\n"
        else
            str+="\t#{e.message}"
        end #if
    end #@errors.each
    return str
end #def message

def has_code?(codenum)
    @errors.each {|e|
      puts "has_code? - comparing #{e.code} (#{e.code.class.name}) to #{codenum} (#{codenum.class.name})"
      if e.code.is_a?(String)
        c = Integer(e.code)
      else
        c = e.code
      end
      if(c==codenum)
          return true
      end
    }
    return false
end

end #class ElementalException

class HTTPInvalidData < StandardError
end

class HTTPMethodUnknown < StandardError
end

class HTTPError <StandardError
    #TODO: initialize from Net::HTTP::Response
end

class ElementalAPI
attr_accessor :host
attr_accessor :port
attr_accessor :user
attr_accessor :pass
attr_accessor :debug
attr_accessor :version
attr_accessor :login
attr_accessor :key
attr_accessor :overlay_image
attr_accessor :overlay_x
attr_accessor :overlay_y
attr_accessor :overlay_opacity

def initialize(hostname,port: port, user:user, passwd: passwd, version: version, login: nil, key: nil, overlay_image: nil, overlay_x: '0', overlay_y: '0', overlay_opacity: '100')
    @host=hostname
    port=80
    if(port)
        @port=port
    end
    @user=""
    if(user)
        @user=user
    end
    @passwd=""
    if(passwd)
        @passwd=passwd
    end
    @version=""
    if(version)
        @version="/#{version}" #need the / to incorporate it into URLs
    end
    @login = login
    @key = key
    @overlay_image = overlay_image
    @overlay_x = overlay_x
    @overlay_y = overlay_y
    @overlay_opacity = overlay_opacity
    
end #def initialize

def _signRequest(request,url)
    #based on elemental sample code. see manual p. 40
    expires = Time.now.utc.to_i + 30
    path_without_api_version = url.path.sub(/\/api(?:\/[^\/]*\d+(?:\.\d+)*[^\/]*)?/i, '')

    hashed_key = Digest::MD5.hexdigest("#{@key}#{Digest::MD5.hexdigest("#{path_without_api_version}#{@login}#{@key}#{expires}")}")
    request['X-Auth-User'] = @login
    request['X-Auth-Expires'] = expires
    request['X-Auth-Key'] = hashed_key
    return request
end

#internal method called by subclasses
def _genRequest(method,path,querypart: {})
    querystring = ""
    
    if(querypart)
        querypart.each do |key,value|
            querystring += "#{key}=#{value}&"
        end
        querystring.chop!
    end
    
    if(querystring.length > 0)
        querystring = "?" + querystring
    end
    
    if(@debug)
        puts "_genRequest: connecting to http://#{@host}:#{@port}/#{path}#{querystring}"
    end
    
    uri = URI("http://#{@host}:#{@port}/api#{@version}/#{path}#{querystring}")
    
    #Net::HTTP.start(@host,@port) do |http|
    case method.downcase
        when "get"
            request = Net::HTTP::Get.new uri
        when "post"
            request = Net::HTTP::Post.new uri
        when "head"
            request = Net::HTTP::Head.new uri
        when "put"
            request = Net::HTTP::Put.new uri
        when "delete"
            request = Net::HTTP::Delete.new uri
        else
            raise HTTPMethodUnknown, "HTTP method #{method} is unknown"
    end
    
    request['Accept'] = "application/xml"
    if @key or @login
        self._signRequest(request,uri)
    end

return request

end #def _genRequest

#returns a FULL job object for the given job id
def job(jobid)

#TODO: validate jobid

Net::HTTP.start(@host,@port) do |http|
    request=self._genRequest("GET","/jobs/#{jobid}")
    response = http.request request
    
    if(response.is_a?(Net::HTTPSuccess))
        return Job.new(jobid,response,self)
    else
        raise HTTPError, response
    end
end #Net::HTTP

end #def job

def jobstatus(jobid)
    
    #TODO: validate jobid
    
    Net::HTTP.start(@host,@port) do |http|
        request=self._genRequest("GET","/jobs/#{jobid}/status")
        response = http.request request
        
        if(response.is_a?(Net::HTTPSuccess))
            return Job.new(jobid,response,self)
            else
            raise HTTPError, response
        end
    end #Net::HTTP
    
end #def job

#submits a job (class job) and returns a job status object or raises an exception
#def submit(job)
#    unless(job.is_a?(Job))
#        raise ArgumentError, "You need to create a Job object to submit"
#    end
    
    #response = self._sendCommand("POST","/jobs",job.to_xml)
    #return JobStatus.new(response)
    
    #end #def submit

#submit a file for encoding. Profileid can be the id, name or permalink for a Profile.
def submit(filepath, preroll: nil, postroll: nil, profileid: nil, audioTracks: [1,2])

#note - should be able to use preroll_input and postroll_input (at same level as xml.input, with same format as file_input) to do on-demand preroll and postroll
b = Nokogiri::XML::Builder.new do |xml|
    xml.job {
        if(preroll)
            xml.preroll_input {
                xml.file_input {
                    xml.uri(preroll)
                }
            }
        end #if(prerollpath)
        xml.input {
            xml.file_input {
                xml.uri(filepath)
            }
            if audioTracks.is_a?(Array)
                xml.audio_selector {
                    xml.default_selection('true')
                    xml.order('1')
                    xml.name('input_1_audio_selector_0')
                    xml.track(audioTracks.join(','))
                }
            end
            
        }
        if(postroll)
            xml.postroll_input {
                xml.file_input {
                    xml.uri(postroll)
                }
            }
        end #if(postrollpath)
        if(profileid)
            xml.profile(profileid)
        end

		if(@overlay_image!=nil)

        	xml.image_inserter {
        		xml.image_inserter_input {
        			xml.uri(@overlay_image)
        		}
        		xml.image_x(@overlay_x)
        		xml.image_y(@overlay_y)
        		xml.opacity(@overlay_opacity)
        	}
        end
    }
end
puts b.to_xml #if(@debug)

Net::HTTP.start(@host,@port) do |http|
    request = self._genRequest("POST","/jobs")
    request.body = b.to_xml
    request['Content-type'] = "application/xml"
    
    response = http.request request
    puts response.body
    
    unless(response.is_a?(Net::HTTPSuccess))
        #Parse the error message that we're given
        begin
            errp = ErrorDocumentParser.new
            parser = Nokogiri::XML::SAX::PushParser.new(errp)
            
            parser << response.body
            
            parser.finish()
        rescue Exception=>e
            puts "WARNING: Unable to parse error message: #{e.message}"
            raise HTTPError, "HTTP error #{response.code}: #{response.body}"
        end
        raise ElementalException, errp.error_list
    end
    return Job.new(nil,response,self)
end #Net::HTTP.start
end #def submit

#returns a jobProfileCollection, an Enumerable of all job profiles
def jobProfiles
    # GET /job_profiles
    
end #def jobProfiles


#returns a watchFolderCollection, an Enumerable of all watchfolders
def watchFolders
    
end #def watchFolders

#returns a presetCollection, an Enumerable of all presets
def presetCollection
    
end #def presetCollection

end #class ElementalAPI
