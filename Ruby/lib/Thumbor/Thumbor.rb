#Client library for Thumbor image cropping service

require 'net/http'
require 'openssl'
require 'base64'
require 'mimemagic'
require 'awesome_print'

#Courtesy of https://gist.github.com/sasimpson/1112739
class ChunkedUploader
  def initialize(data, chunk_size)
    @size = chunk_size
    if data.respond_to? :read
      @file = data
    end
  end
  
  def read(foo,bar)
    if @file
      @file.read(@size)
    end
  end
  def eof!
    @file.eof!
  end
  def eof?
    @file.eof?
  end
end

class Thumbor
	attr_accessor :hostname
	attr_accessor :port
	attr_accessor :key
	attr_accessor :chunk_size
	
	def initialize(hostname: "localhost",port: 8888, key: "MY_SECURE_KEY")
		@hostname=hostname
		@port=port
		@key=key
		@chunk_size=2097152	#2Mb
		
		ap self
	end #def initialize
	
	#see https://github.com/thumbor/thumbor/wiki/Security
	def _signatureForURL(url)
		if(url.is_a?(URI))
			data = url.path.sub(/^\//,'')
		elsif(url.is_a?(String))
			parts = url.match(/:\/\/[^\/]\/(.*)/)
			if(parts)
				data = parts[1]
			else
				data = url
			end #if(parts)
		end #if(url.is_a?(String))
			
		d = OpenSSL::Digest.new('sha1')
		puts "key is #{@key}, data #{data}"
		
		result = Base64.strict_encode64(OpenSSL::HMAC.digest(d, @key, data))
		
		result.gsub!('+','-')
		result.gsub('/','_')
		
		#return "unsafe"
	end
	
	#you can call this with an outputPath, or you can call as a block in which case
	#body segments will be yielded to the block as they are read in
	def makeCrop(imageRef,outputPath,width: 0, height: 0, smart: false)
		pathref = "#{width}x#{height}/"
		pathref += "smart/" if(smart)
		if(imageRef.is_a?(URI))
			pathref += imageRef.to_s
		else
			pathref += imageRef
		end
		
		s = self._signatureForURL(pathref)
		
		u = URI::HTTP.build({
			:host => @hostname,
			:port => @port,
			:path => '/' + s + '/' + URI::encode(pathref)
		})
		
		puts "DEBUG: url is #{u.to_s}"
		
		Net::HTTP.start(u.host, u.port) do |http|
 			request = Net::HTTP::Get.new u
			http.request(request) do |response| # Net::HTTPResponse object
				response.value() #raises an HTTPError if the response is not 2xx
			
				if(outputPath)
					File.open(outputPath, mode: "w") do |f|
						response.read_body do |segment|
							f.write(segment)
						end
					end #File.open
				else
					response.read_body do |segment|
						yield segment
					end #response.read_body
				end #if(outputpath)
			end #http.request
		end #Net::HTTP.start
		
		return outputPath
	end #def makeRequest

	def normalizeFilename(fn)
		fn.gsub(/[^\w\d_\.]/,'_')
	end
	
	def uploadImage(imagePath, uploadedName: nil)
		if(uploadedName == nil)
			uploadedName=File.basename(imagePath)
		end
		
		mimeType=MimeMagic.by_magic(File.open(imagePath)).type
		ap mimeType
		
		#s = self._signatureForURL("image")
		u = URI::HTTP.build({
			:host => @hostname,
			:port => @port,
			:path => '/image'
		})
		
		location = ""
		
		puts "#{u.host} #{u.port}"

		Net::HTTP.start(u.host, u.port) do |http|
			request = Net::HTTP::Post.new u.request_uri, { 'Slug' => normalizeFilename(uploadedName), 'Content-Type' => mimeType }
			request.body = IO.read(imagePath)
			
			response = http.request(request)
			
			ap response
			
			response.value()
			location = response['Location']
		end #Net::HTTP.start		
		#fp.close
		return location.gsub(/^\/image\//,'')
		
		
	end #def uploadImage
	
	def deleteImage(imageRef)
		u = URI::HTTP.build({
			:host => @hostname,
			:port => @port,
			:path => '/image/' + URI::encode(imageRef)
		})
		
		Net::HTTP.start(u.host, u.port) do |http|
			request = Net::HTTP::Delete.new u.request_uri
			
			response = http.request(request)
			
			ap response
			response.value() #raise an exception if the response isn't 2xx. (expecting 204, No Content)
		end #Net::HTTP.start
	end #def deleteImage
	
end #class Thumbor
