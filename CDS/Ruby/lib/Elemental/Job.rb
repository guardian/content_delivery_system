require 'Elemental/Elemental'
require 'nokogiri'
require 'awesome_print'
require 'net/http'

class JobDocumentParser < Nokogiri::XML::SAX::Document
S_INPUT = 1
S_JOB = 0
S_ERROR = 2
S_OUTPUTGROUP = 3
S_STREAMASSEMBLY = 4

attr_accessor :job_section
attr_accessor :input_section
attr_accessor :error_list
attr_accessor :output_list
attr_accessor :stream_hash
attr_accessor :job_href
attr_accessor :api_version
attr_accessor :product

def start_document
@element_tree = []
@input_section = {}
@job_section = {}
@error_list = []
@output_list = []
@stream_list = []

@current_section = 0

end #start_document

def end_document
    @stream_hash = {}
    
    #fix up relations between streams and outputs
    @stream_list.each do |s|
        if(s['name'])
            @stream_hash[s['name']] = s
        end
    end
    
    @output_list.each do |output|
        if(output['stream_assembly_name'])
            output['stream'] = @stream_hash[output['stream_assembly_name']]
        end
    end
end #end_document

def start_element(name,attrs = [])
    @element_tree << name
    
    #get the id of the job
    if(name == "job")
        attrs.each do |a|
            case a[0]
                when 'href'
                    @job_href=a[1]
                when 'version'
                    @api_version=a[1]
                when 'product'
                    @product=a[1]
            end #case
        end #attrs.each
    end
    
    if(name == "input")
        @current_section=S_INPUT
    end
    
    if(name == "error_messages")
        #puts "in errors section"
        @current_section=S_ERROR
    end
    
    if(name == "output_group")
        @current_section=S_OUTPUTGROUP
    end
    
    if(name == "stream_assembly")
        @current_section=S_STREAMASSEMBLY
        newstream = Hash.new
        @stream_list << newstream
    end
    
    if(@current_section==S_ERROR)
        #puts "got #{name} in errors section"
        if(name == "error")
            newerror = ElementalError.new(nil,nil,nil)
            @error_list << newerror
        end
    elsif (@current_section==S_OUTPUTGROUP) #S_ERROR
        if(name == "output")
            newoutput = Hash.new
            @output_list << newoutput
        end
    end
end #start_element

def end_element(name)
@element_tree.pop

if(name == "input" or name == "error_messages" or name == "stream_assemly")
    @current_section=S_JOB
end

end #end_element

def characters(string)
current_tag = @element_tree.last

#puts "characters: #{string}"
#ap @element_tree

if(string == nil or /^[\s\n]*$/.match(string))
    return
end

case @current_section
    when S_JOB
        if(@element_tree.count == 2)
            if(@job_section[current_tag])
                @job_section[current_tag] += string
            else
                @job_section[current_tag] = string
            end
        end #if @element_tree.count == 1
    when S_INPUT
        if(@input_section[current_tag])
            @input_section[current_tag] += string
        else
            @input_section[current_tag] = string
        end
    when S_OUTPUTGROUP
        current_output = @output_list.last
        unless(current_output)
            return
        end
        if(current_output[current_tag])
            current_output[current_tag] += string
        else
            current_output[current_tag] = string
        end
    when S_ERROR
        current_error=@error_list.last
        if(current_error==nil)
            return
        end
        if(current_tag=="code")
            current_error.code=string
        end
        if(current_tag=="created_at")
            current_error.created_at=string
        end
        if(current_tag=="message")
            current_error.message=string
        end
    when S_STREAMASSEMBLY
    #for stream assemblies, assemble a path of tags from below the stream_assembly node so we can distinguish video_description, audio_description etc.
        relevant_tags = @element_tree.slice(2,@element_tree.count)
        current_tag = relevant_tags.join('_')
        
        current_stream = @stream_list.last
        if(current_stream == nil)
            return
        end
        #puts "on stream assembly: #{current_tag}"
        if(current_stream[current_tag])
            current_stream[current_tag] += string
        else
            current_stream[current_tag] = string
        end
end #case

end #characters

end #class JobDocumentParser

class JobList
include Enumerable

end #class JobList

class Job
attr_accessor :status
attr_accessor :input
attr_accessor :id
attr_accessor :errors
attr_accessor :output_list

def initialize(jobid,httpresponse,apiptr)
    #    unless(httpresponse.response_body_permitted?)
    #    raise HTTPInvalidData, "You need a response when initializing Job"
    #end
    
    @id = jobid
    #puts "Job::initialize: #{httpresponse.body}"
    docp = JobDocumentParser.new
    parser = Nokogiri::XML::SAX::PushParser.new(docp)
    
    parser << httpresponse.body
    
    parser.finish() #ensure that end_document is called
    
    if(@id==nil)
        parts = /(\d+)$/.match(docp.job_href)
        #ap parts
        if(parts)
            @id=parts[1]
        end
        #puts "debug: got job id #{@id} from xml"
    end
    
    @status = docp.job_section
    @input = docp.input_section
    @errors = docp.error_list
    @output_list = docp.output_list
    @stream_list = docp.stream_hash
    @api = apiptr
    #ap docp
    
end #def initialize

def refresh_status!(no_raise_on_error: false)
    if(@id==nil)
        error_list = [ ElementalError.new(nil,nil,"You need to have an ID before refreshing a job") ]
        raise ElementalException, error_list
    end
    
    Net::HTTP.start(@api.host,@api.port) do |http|
        #puts "Connecting to /jobs/#{@id}/status"
        #@api.debug = 1
        request=@api._genRequest("GET","jobs/#{@id}/status")
        begin
            response = http.request request
            if(response.is_a?(Net::HTTPTemporaryRedirect))
                puts "Redirecting to #{response['location']}"
                request = Net::HTTP::Get.new(response['Location'])
                request['Accept'] = 'application/xml'
            end
        end while(response.is_a?(Net::HTTPTemporaryRedirect))
        
        if(response.is_a?(Net::HTTPSuccess))
            docp = JobDocumentParser.new
            parser = Nokogiri::XML::SAX::PushParser.new(docp)
            
            parser << response.body
            
            parser.finish() #ensure that end_document is called
            
            @status = docp.job_section
            @errors = docp.error_list
            unless(no_raise_on_error)
                self.raise_on_error
            end
        else
        begin
            errp = ErrorDocumentParser.new
            parser = Nokogiri::XML::SAX::PushParser.new(errp)
            
            parser << response.body
            
            parser.finish()
            @errors = errp.error_list
        rescue Exception=>e
            puts response.body
            puts "WARNING: Unable to parse error message: #{e.message}"
            raise HTTPError, "HTTP error #{response.code}: #{response.body}"
        end
            raise ElementalException, errp.error_list
        end
    end #Net::HTTP
end

def complete?
    if(@status['status'].downcase == "complete")
        return true
    else
        return false
    end
end #def complete?

def cancelled?
    if(@status['status'].downcase == "cancelled")
        return true
    else
        return false
    end
end #def cancelled?

def raise_on_error
    if(@status['status'].downcase == "error")
        raise ElementalException, @errors
    end
    if(@status['status'].downcase == "cancelled")
        @errors = [ ElementalError.new(nil,nil,"Job was cancelled by user") ]
        raise ElementalException, @errors
    end
end

def input_file
    if(@input['complete_name'])
        return @input['complete_name']
    elsif(@input['uri'])
        return @input['uri']
    end
end #def input_file

def output_count
    if(@output_list)
        return @output_list.count
    end
    return nil
end

def dump
    puts "Dump for job #{@id}:"
    puts "Status:"
    ap @status
    puts "Input section:"
    ap @input
    puts "Stream assemblies:"
    ap @stream_list
    ap @stream_hash
    puts "Output section:"
    ap @output_list
    puts "Errors:"
    ap @errors
end #def dump

def cancel!
   request = @api._genRequest("POST","/job/#{@id}/cancel")
   request.body = "<cancel></cancel>"
   request['Content-type'] = "application/xml"
   
   Net::HTTP.start(@api.host,@api.port) do |http|
       response = http.request request
   end
   
   unless(response.is_a?(Net::HTTPSuccess))
       raise HTTPError, response.body
    end
end

end #class job
