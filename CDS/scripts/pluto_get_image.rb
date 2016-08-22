#!/usr/bin/env ruby

#This method decodes the JSON object passed by PLUTO to identify an image,
#looks it up in Vidispine and returns the filename into an array in the datastore
#
#Arguments:
# <image_specifier>{meta:image_field_name} - use this to get the image out. Should usually be a JSON object with the field id: "AA-nnnnn" to give the Vidispine ID of the image. Normally passed in using a substitution, e.g. {meta:pluto_id}
# <output_key>keyname - output the filename to this datastore key. If there is a value in this key already, the current image will be appended to the list, delimited by a | character
# <output_key_43>keyname - output the filename for 4x3 image (if provided) to this datastore key.
# <use_http/> - download from Vidispine via HTTP rather than use the filename
# <cache_path>/path/to/download - When downloading, save to this path. Defaults to /tmp
# <no_array/> [OPTIONAL] - blank any existing values in {meta:output_key}
# <vidispine_host>hostname [OPTIONAL] - Connect to Vidispine running on this server. Defaults to 'localhost'
# <vidispine_port>nnnn [OPTIONAL] - Connect to Vidispine API on this port. Defaults to 8080.
# <vidispine_user>username [OPTIONAL] - Connect to Vidispine using this username. Defaults to admin
# <vidispine_passwd>password [OPTIONAL] - Connect to Vidispine using this password

#END DOC

require 'rubygems'
require 'CDS/Datastore'
require 'Vidispine/VSItem'
require 'json'
require 'awesome_print'
require 'fileutils'
require 'uri'
require 'net/http'

class DownloadError < StandardError
end

def downloadViaURL(url,cache_path,filename: nil,agent: nil,retry_delay: 2,retries: 10)
    rq = Net::HTTP::Get.new(url)
    uri = URI(url)
    
    response = agent.request(rq)
    unless(response.is_a?(Net::HTTPSuccess))
        raise DownloadError, "#{response.code}: #{response.message}"
    end
    #fn = File.basename(url)
    
    filename = File.basename(uri.path) if(filename==nil)
    
    outname = File.join(cache_path,filename)
    puts "INFO: Server returned success. Downloading to #{outname}"
    File.open(outname,"wb") do |f|
        #response.read_body do |data|
            f.write(response.read_body())
            #end #read_body
    end #File.open
    return outname
    
end #def downloadViaURL

def getImageFilename(vsid,retry_delay: 2,retries: 10)
    return getImageData(vsid,retry_delay: retry_delay,retries: retries,content:'filepath')
end

def getImageContent(vsid,retry_delay: 2,retries: 10)
    r = getImageData(vsid,retry_delay: retry_delay,retries: retries,content:'data') do |b|
	yield b
    end
    return r
end

def getImageData(vsid,retry_delay: 2,retries: 10,content: 'filepath')
    filename=""
    attempts=0
    begin
        attempts+=1
        item=VSItem.new($vshost,$vsport,$vsuser,$vspass)
        item.populate(vsid)
        
        item.shapes.each do |s|
	    if content=='filepath'
		filename=URI.unescape(s.fileURI(scheme: "file").path)
		break if(filename!=nil and filename!="")
	    elsif content=='data'
		s.fileData do |b|
		    yield b
		end
		return true
	    end
        end #item.shapes.each

        if(filename==nil or filename=="")
                raise StandardError,"No file could be found"
        end
        return filename
        
    rescue VSException=>e
        puts "-ERROR: Unable to retrieve information from Vidispine: #{e.message}"
        exit 1
        
    rescue HTTPError=>e
        puts "-ERROR: HTTP error communicating with vidispine at #{$vshost}:#{$vsport} - #{e.message} attempt #{attempts} of #{retries}"
        if(attempts>=retries)   #retry as this is likely to be a transient network fault
            exit 1
        end
        sleep(retry_delay)
        retry

    rescue StandardError=>e
        puts "-WARNING: #{e.message}"
        if(attempts>=retries)
            exit 1
        end
        sleep(retry_delay)
        retry
        
        end
    return nil
end #def getImageFilename

#START MAIN
#connect to the datastore
$store=Datastore.new('pluto_get_image')

$vshost='localhost'
if(ENV['vidispine_host'])
    $vshost=$store.substitute_string(ENV['vidispine_host'])
end
$vsport=8080
if(ENV['vidispine_port'])
    $vsport=$store.substitute_string(ENV['vidispine_port']).to_i
end
$vsuser='admin'
if(ENV['vidispine_user'])
    $vsuser=$store.substitute_string(ENV['vidispine_user'])
end
$vspass=''
if(ENV['vidispine_passwd'])
    $vspass=$store.substitute_string(ENV['vidispine_passwd'])
elsif(ENV['vidispine_password'])
    $vspass=$store.substitute_string(ENV['vidispine_password'])
end

retries=10
retry_delay=2
if(ENV['retries'])
    retries=$store.substitute_string(ENV['retries']).to_i
end
if(ENV['retry_delay'])
    retry_delay=$store.substitute_string(ENV['retry_delay']).to_i
end

cache_path = "/tmp"
if(ENV['cache_path'])
    cache_path = $store.substitute_string(ENV['cache_path'])
    if(not Dir.exists?(cache_path))
    	FileUtils.mkdir_p(cache_path)
    end
end

unless(ENV['image_specifier'])
    puts "-ERROR: You need to specify the meta: datastore key to get the image specifier string from by using <image_specifier>keyname in the routefile"
    exit 1
end

ENV['output_key'] = "image_file" unless(ENV['output_key'])
ENV['output_key_43'] = "image_file_43" unless(ENV['output_key_43'])

specifierstring=$store.substitute_string(ENV['image_specifier'])
unless(specifierstring)
    puts "-ERROR: The key #{ENV['image_specifier']} did not give a value"
    exit 1
end

#specdata=nil
vs_id_169=""
vs_id_43=""

if(specifierstring.match(/^{/))
    if(ENV['debug'])
        puts specifierstring
    end
    specdata=JSON.parse(specifierstring)
    ap specdata
    
    vs_id_169 = specdata['id'] if(specdata['id'])
    vs_url_169 = specdata['url'] if(specdata['url'])
    vs_id_169 = specdata['id_16x9'] if(specdata['id_16x9'])
    vs_url_169 = specdata['url_16x9'] if(specdata['url_16x9'])
    vs_id_43 = specdata['id_4x3'] if(specdata['id_4x3'])
    vs_url_43 = specdata['url_4x3'] if(specdata['url_4x3'])
    ap specdata if(ENV['debug'])

else
    puts "-WARNING: #{specifierstring} doesn't look like a JSON object, which is what i was expecting. Trying to treat it as a Vidispine ID..."
    vsid=specifierstring
end

unless(vs_id_169.match(/^[A-Z]{2}-\d+$/))
    puts "-ERROR: Unable to get a vidispine ID. The best I got was '#{vs_id_169}', which doesn't look right (not in the form XX-nnnnnnn)"
    exit 1
end

got_169 = false
got_43 = false

attempts = 0
if(ENV['use_http'])
    begin
    #Net::HTTP.start($vshost,$vsport) do |http|
    #    $filename_169 = downloadViaURL(vs_url_169,cache_path,agent: http,filename: "#{vs_id_169}_crop.jpg")
    #    if(vs_url_43)
    #        $filename_43 = downloadViaURL(vs_url_43,cache_path,agent: http,filename: "#{vs_id_43}_crop.jpg")
    #    end
    #end #Net::HTTP
    $filename_169 = File.join(cache_path,"#{vs_id_169}_crop.jpg")
    File.open($filename_169,"wb") do |f|
	getImageContent(vs_id_169) do |data|
	    f.write(data)
	end
    end
 
    $filename_43 = File.join(cache_path,"#{vs_id_43}_crop.jpg")
    File.open($filename_43,"wb") do |f|
	getImageContent(vs_id_43) do |data|
	    f.write(data)
	end
    end
     
    rescue DownloadError=>e
        retries+=1
        if(attempts>retries)
            puts "-ERROR: Unable to download after #{attempts} attempts"
            exit(1)
        end
        puts "-WARNING: Problem downloading #{e.message}. Re-trying... (attempt #{attempts} of #{retries})"
	sleep(retry_delay)
        retry
    end #exception block
else
    $filename_169 = getImageFilename(vs_id_169,retry_delay: retry_delay,retries: retries)
    if(vs_id_43!="")
        $filename_43 = getImageFilename(vs_id_43,retry_delay: retry_delay,retries: retries)
    end
end

begin
    if(ENV['no_array'])
        $store.set('meta',ENV['output_key'],$filename_169)
        puts "INFO: Overwriting #{ENV['output_key']} to #{$filename_169}"
        if($filename_43)
            $store.set('meta',ENV['output_key_43'],$filename_43)
            puts "INFO: Overwriting #{ENV['output_key_43']} to #{$filename_43}"
        end
    else
        current_value=$store.get('meta',ENV['output_key'])
        new_value=$filename_169
        if(current_value and current_value.length>1)
            new_value=current_value + "|" + $filename_169
        end
        puts "INFO: Setting new value of #{ENV['output_key']} to #{new_value}"
    	$store.set('meta',ENV['output_key'],new_value)
        
        if($filename_43 and ENV['output_key_43'])
            current_value=$store.get('meta',ENV['output_key_43'])
            new_value=$filename_43
            if(current_value and current_value.length>1)
                new_value=current_value + "|" + $filename_43
            end
            puts "INFO: Setting new value of #{ENV['output_key_43']} to #{new_value}"
            $store.set('meta',ENV['output_key_43'],new_value)
        end #
    end

    puts "+SUCCESS: #{$filename_169} output to #{ENV['output_key']}"
    
rescue Exception=>e
    puts "-ERROR: Unable to store value into datastore: #{e.message}"
    puts e.backtrace
    exit 1
end
