#!/usr/bin/env ruby
require 'net/http'
require 'awesome_print'
require 'nokogiri'
require 'CDS/Datastore'
require 'base64'

#This CDS method takes any number of R2 Tag IDs and uses the PLUTO endpoint to map their actual names.
#Arguments:
# <tag_ids>{meta:tag_id_string} - list of tag IDs to map, separated by |.  This would normally be a datastore substitution, like {meta:tag_ids}
# <output_field>fieldname - name of a datastore field (in the meta: section) to output the list of names to
# <pluto_host>hostname [OPTIONAL] - name of the machine to connect to PLUTO on. Defaults to localhost
# <pluto_port>port [OPTIONAL] - port to connect to PLUTO on. Defaults to 80.
# <pluto_user>username - User name to connect to PLUTO with
# <pluto_pass>password - Password to connect to PLUTO with
#END DOC

class HTTPError < StandardError
    attr_accessor :result
    def initialize(msg,result)
        super(msg)
        @message=msg
        @result = result
        puts "HTTPError::initialize"
    end
    
    def to_s
        return "#{@message}: #{@result.class}: #{@result.body} #{@result.inspect}"
    end
end

def lookup_tag(tagnum,conninfo)
    headers = {}
    headers['Authorization'] = 'Basic ' + Base64.encode64("#{conninfo['user']}:#{conninfo['passwd']}")
    uri = URI("http://#{conninfo['host']}:#{conninfo['port']}/gnm_tags/tags/#{tagnum}/")
    
    begin
        result = nil
        req = Net::HTTP::Get.new(uri)
        headers.each do |k,v|
            req[k] = v
        end
        Net::HTTP.start(uri.host,uri.port) do |http|
            result = http.request(req)
        end #Net::HTTP.start
        if(result.is_a?(Net::HTTPMovedPermanently) and result['Location'])
            #if(@debug)
            puts "INFO: Redirecting to #{result['Location']}"
                #end
            uri=URI.parse(result['Location'])
        end
    end while(result.is_a?(Net::HTTPMovedPermanently))
    
    unless(result.is_a?(Net::HTTPSuccess))
        raise HTTPError.new("Unable to communicate with PLUTO",result)
    end
    
    xmldoc = Nokogiri::XML(result.body)
    rtn = {}
    
    xmldoc.xpath("//tag").each do |node|
        rtn['id'] = node.attr('id')
        rtn['type'] = node.attr('type')
        rtn['internalname'] = node.attr('internalname')
        if(block_given?)
            yield rtn
        else
            return rtn
        end
    end #xpath("//tag").each
end

#START MAIN
$store = Datastore.new('pluto_map_keywords')
unless(ENV['tag_ids'])
    puts "-ERROR: You need to specify tag IDs to map into names with the <tag_ids> parameter"
end
unless(ENV['output_field'])
    puts "-ERROR: You need to specify a field to output to, using the <output_field> parameter"
end

conninfo = {}
conninfo['host']="localhost"
conninfo['host']=$store.substitute_string(ENV['pluto_host']) if(ENV['pluto_host'])
conninfo['port']=$store.substitute_string(ENV['pluto_host']).to_i if(ENV['pluto_port'])
conninfo['user']=$store.substitute_string(ENV['pluto_user'])
conninfo['passwd']=$store.substitute_string(ENV['pluto_pass'])

mapped_keywords = []

$store.substitute_string(ENV['tag_ids']).split('|').each do |tagid|
    begin #exception catch block
        tagnum=tagid.to_i #neat way of avoiding sql injection etc.; this will fail if there are any non-numeric characters
        taginfo = lookup_tag(tagnum,conninfo)
        ap taginfo
        mapped_keywords << taginfo['internalname']
    rescue HTTPError=>e
        if(e.result.is_a?(Net::HTTPNotFound))
            puts "-WARNING: Tag #{tagnum} not found. Continuing without it."
            next
        end
        puts "-ERROR: #{e}"
        exit(1)
    end
end

puts "INFO: Mapped #{mapped_keywords.length} tags"
puts "INFO: Will output #{mapped_keywords.join('|')} to #{ENV['output_field']}"

$store.set('meta',ENV['output_field'],mapped_keywords.join('|'))
exit 0

