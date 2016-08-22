require 'net/http'
require 'uri'
require 'awesome_print'

#This module is an interface to the R2 newspaper integration API
#It is not intended as a complete implementation, but as a container that can be
#added to as needed

class HTTPError < StandardError
end

class R2Error < StandardError
end

class R2NewspaperIntegration
    attr_accessor :host,:port,:rootpath
    attr_accessor :debug
    
    def initialize(host: "localhost",port: 80,rootpath: "/tools/newspaperintegration")
        @host=host
        @port=port
        @rootpath=rootpath
	@debug=false
    end
    
    def uploadImage(filepath,site: "guardian.co.uk",groupID: 3232,altText: nil,
                    caption: nil,source: "guardian.co.uk",photographer: nil,
                    comments: nil,picdarId: nil,copyright: nil,ref: nil, secure: false)
        if(secure)
	    proto='https'
        else
            proto='http'
        end
        uri=URI("#{proto}://#{@host}:#{@port}/#{@rootpath}/image/import")
        
        if(altText==nil)
            altText=File.basename(filepath)
        end
        
        if(caption==nil)
            caption=altText
        end
        
        formdata={
            'file'=>File.new(filepath),
            'site'=>site,           #preset, not from exif
            'image.group'=>groupID, #preset, not from exif
            'image.altText'=>altText,   #xmp:dc.description OR exifr.image_description [check truncate limit]
            'image.caption'=>caption, #xmp:dc.description OR exifr.image_description [check truncate limit]
            'source'=>source,   #?
            'image.photographer'=>photographer, #xmp:dc.creator OR exifr.artist
            'image.comments'=>comments, #exifr.comment - this is an array - needs to be joined together.
            'image.copyright.picdarId'=>picdarId,  #xmp:dc.title - if matches /^[A-Z]{2}.\d+$/
            'image.copyright.copyrightInformation'=>copyright, #exifr.copyright
            'image.copyright.suppliersReference'=>ref #??
        }
        
	if(@debug)
        	puts "debug: R2NewspaperIntegration: uploading info:"
        	ap formdata
        end

        begin
            data,headers=Multipart::Post.prepare_query(formdata)
            http = Net::HTTP.new(uri.host, uri.port)
            res = http.start {|con| con.post(uri.path, data, headers) }
        
        rescue SocketError=>e
            raise HTTPError,"Internal socket error: #{e.message}"
        end
        
        unless(res.kind_of?(Net::HTTPSuccess))
	    body=res.body()
            raise HTTPError,"#{res.code} (#{res.msg}): #{body}"
        end
        
        returnstring=res.body()
        
        #loose newlines in the response are annoying
        returnstring.gsub!(/[\r\n]/,"")
        #also get rid of any trailing whitespace, while we're at it
        returnstring.gsub!(/\s+$/,"")
        
        unless(parts=returnstring.match(/^([^:]+):\s*(.*)\s*$/))
            raise R2Error,"Response not understood: #{returnstring}"
        end
        
        #puts "DEBUG: got R2 response #{parts[1]} with info #{parts[2]}"
        if(parts[1].upcase()=="ERROR")
            raise R2Error, parts[2]
        end
        
        responseparts=parts[2].match(/\s*(\d+)\s*;\s*(.*)$/)
        return responseparts[1], responseparts[2]
        
    end #def uploadImage
    
end #class R2NewspaperIntegration


#Code for multipart form upload from http://stackoverflow.com/questions/184178/ruby-how-to-post-a-file-via-http-as-multipart-form-data
# Takes a hash of string and file parameters and returns a string of text
# formatted to be sent as a multipart form post.
#
# Author:: Cody Brimhall <mailto:brimhall@somuchwit.com>
# Created:: 22 Feb 2008
# License:: Distributed under the terms of the WTFPL (http://www.wtfpl.net/txt/copying/)

#require 'rubygems'
require 'mime/types'
require 'cgi'
require 'base64'

module Multipart
    VERSION = "1.0.0"
    
    # Formats a given hash as a multipart form post
    # If a hash value responds to :string or :read messages, then it is
    # interpreted as a file and processed accordingly; otherwise, it is assumed
    # to be a string
    class Post
        # We have to pretend we're a web browser...
        USERAGENT = "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/523.10.6 (KHTML, like Gecko) Version/3.0.4 Safari/523.10.6"
        BOUNDARY = "0123456789ABLEWASIEREISAWELBA9876543210"
        CONTENT_TYPE = "multipart/form-data; boundary=#{ BOUNDARY }"
        HEADER = { "Content-Type" => CONTENT_TYPE, "User-Agent" => USERAGENT }
        
        def self.prepare_query(params)
        fp = []
        
        params.each do |k, v|
        if(v==nil)
            next
        end
        # Are we trying to make a file parameter?
        if v.respond_to?(:path) and v.respond_to?(:read) then
        fp.push(FileParam.new(k, v.path, v.read))
        # We must be trying to make a regular parameter
        else
        fp.push(StringParam.new(k, v))
    end
end

# Assemble the request body using the special multipart format
header= "--" + BOUNDARY + "\r\n"
trail = "--" + BOUNDARY + "--"
query = fp.collect {|p| header + p.to_multipart }.join("") + trail
 
return query.encode('UTF-8'), HEADER
end
end

private

# Formats a basic string key/value pair for inclusion with a multipart post
class StringParam
    attr_accessor :k, :v
    
    def initialize(k, v)
        @k = k
        @v = v
    end
    
    def to_multipart
        return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"\r\n\r\n#{v}\r\n".force_encoding('UTF-8')
    end
end

# Formats the contents of a file or string for inclusion with a multipart
# form post
class FileParam
    attr_accessor :k, :filename, :content
    
    def initialize(k, filename, content)
        @k = k
        @filename = filename
        @content = content
    end
    
    def to_multipart
        # If we can tell the possible mime-type from the filename, use the
        # first in the list; otherwise, use "application/octet-stream"
        mime_type = MIME::Types.type_for(filename)[0] || MIME::Types["application/octet-stream"][0]
        return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"; filename=\"#{ File.basename(filename) }\"\r\n" +
        "Content-Type: #{ mime_type.simplified }\r\n\r\n#{ content }\r\n".force_encoding('UTF-8')
    end
end
end
