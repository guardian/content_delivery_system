#!/usr/bin/env ruby
require 'CDS/Datastore'
require 'Vidispine/VSApi'
require 'Vidispine/VSItem'
require 'uri'

$stdout.sync = true
$stderr.sync = true

#This CDS method attempts to get a media file from Vidispine by requesting a
#specific shape.  If the shape does not exist, then we request a transcode of
#it from Vidispine.  If the shape tag specified is not valid, then an error is returned.
#
#Arguments:
# <item_id>{vidispine item id} - ask for a version of this item
# <shape_tag>{shapetag} - ask for a rendition of the item using the specified shape tag
# <no_set_media/> [OPTIONAL] - do NOT set the route's cf_media_file to the retrieved file
# <set_key>{meta|media|track}:keyname [OPTIONAL] - set the given key to the path of the returned file
# <vidispine_host>hostname - connect to Vidispine on this host
# <vidispine_port>port [OPTIONAL] - connect to Vidispine using this port. Default is 8080.
# <vidispine_user>user - connect to Vidispine with this username
# <vidispine_password>pass - connect to Vidispine with this password
# <no_transcode/> [OPTIONAL] - don't attempt to transcode a new rendition if it doesn't currently exist
# <wait_time>nnn [OPTIONAL] - wait this long for file to appear
# <retry_delay>nnn [OPTIONAL] - wait this long between attempts
# <download/> [OPTIONAL] - instead of returning filename, attempt to download it
# <download_path> [optional] - when downloading, save to this path.
#END DOC

class ArgumentError < StandardError
end

def assert_args(arglist)

arglist.each do |a|
    unless(ENV[a])
        raise ArgumentError,"Missing argument. You need to specify <#{a}> in the route file"
    end
end #arglist.each

end #def assert_args

#START MAIN
$store=Datastore.new('vidispine_get_media')

begin
    assert_args(['vidispine_host','vidispine_user','vidispine_password','item_id','shape_tag'])
rescue ArgumentError=>e
    puts "-ERROR: #{e.message}"
    exit(1)
end


begin
    wait_time = $store.substitute_string(ENV['wait_time']).to_i
    retry_delay = $store.substitute_string(ENV['retry_delay']).to_i
rescue Exception=>e
  wait_time = 300
  retry_delay = 10
end

begin
    vshost = $store.substitute_string(ENV['vidispine_host'])
    vsuser = $store.substitute_string(ENV['vidispine_user'])
    vspass = $store.substitute_string(ENV['vidispine_password'])
    vshttps = false
    vshttps = true if ENV["vidispine_https"]
    vsid = $store.substitute_string(ENV['item_id'])
    shapetag = $store.substitute_string(ENV['shape_tag'])
    vsport = 8080
    if(ENV['vidispine_port'])
        vsport = $store.substitute_string(ENV['vidispine_port']).to_i
    end
    debug=ENV['debug']
rescue Exception=>e
    puts e.backtrace
    puts "-ERROR: Unable to set up arguments: #{e.message}"
end

begin
    item = VSItem.new(vshost,vsport,vsuser,vspass)
    item.populate(vsid)
rescue VSNotFound=>e
    puts "-ERROR: Vidispine item #{vsid} could not be found on the server #{vshost}"
    exit(1)
rescue VSException=>e
    puts e.backtrace
    puts "-ERROR: #{e.message}"
    exit(1)
end

puts "Found item #{vsid}, with currently available shapes:"
item.shapes.each do |s|
    #specify a url scheme (e.g., file, http, omms, s3, etc.) to only return URIs that match that scheme
    s.eachFileURI(scheme: nil) do |u|
        puts "\t#{s.id} (#{s.tag}): #{u.to_s}\n";
    end
end

have_transcoded=false
start_time=Time.now.to_i

if(ENV['download'])
	if(ENV['download_path'])
		download_path = $store.substitute_string(ENV['download_path'])
	else
		download_path = "/tmp"
  end

  shouldHaveScheme=nil
else
  shouldHaveScheme='file'
end


begin
  s = item.shapes.shapeForTag(shapetag, scheme: shouldHaveScheme, refresh: true)
  while(s.fileURI().path.length == 0)
    sleep(5)
    puts "Shape exists, but path is zero-length. Probably still transcoding, waiting for a valid path..."
    s = item.shapes.shapeForTag(shapetag, refresh: true)
  end #while
  puts "Found #{s.id} at "+URI.unescape(s.fileURI().path)

  if ENV['download']
    output_file_path = File.join(download_path,File.basename(s.fileURI().path))

    File.open(output_file_path,"w") do |f|
      s.fileData do |data|
        f.write(data)
      end #s.fileData
    end #File.open
  else #if ENV['download']
    output_file_path=URI.unescape(s.fileURI(scheme: "file").path)
    puts "Found #{s.id} at "+output_file_path
  end #if ENV['download']

rescue VSNotFound=>e
  puts "No shape was found with the tag #{shapetag}"

  if(ENV['no_transcode'])
    elapsed = Time.now.to_i - start_time
    if(elapsed > wait_time)
      puts "No joy after #{elapsed} seconds."
      exit(1)
    end
    sleep(retry_delay)
    item.refresh
    retry
  end

  if(have_transcoded)
    puts "-ERROR: Previous transcode attempt failed, so we cannot continue.  Remove the shape from the item in Vidispine and re-run the route."
    exit(1)
  end
  have_transcoded=true
  begin
    item.transcode!(shapetag)
    puts "INFO: Transcode completed. Waiting 5s for Vidispine to kick in before re-trying..."
    sleep(5)
    retry
  rescue VSNotFound=>e
    puts "-ERROR: Shape tag #{shapetag} does not exist."
    exit(1)
  rescue VSException=>e
    puts e.backtrace
    puts "-ERROR: Vidispine reported #{e.message}"
  end
end #exception block

unless(ENV['no_set_media'])
    puts "INFO: Outputting found encoding "+output_file_path+ " as media file"
    File.open(ENV['cf_temp_file'],'w') do |tempfile|
        tempfile.write("cf_media_file="+output_file_path)
    end #File.open
end #unless(no_set_media)

if(ENV['set_key'])
    section='meta'
    parts=/^([^:]+):(.*)$/.match(ENV['set_key'])
    if(parts)
        section=parts[1]
        key=parts[2]
    else
        key=ENV['set_key']
    end
    puts "INFO: Outputting encoding path to key #{key} in section #{section}"
    $store.set(section,key,output_file_path)
end

print "+SUCCESS: Found an encoding matching shape tag #{shapetag}"