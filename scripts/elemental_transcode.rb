#!/usr/bin/env ruby
require 'CDS/Datastore-Episode5'
require 'Elemental/Elemental'
require 'Elemental/Job'
require 'awesome_print'

#This module allows media to be transcoded with Elemental appliances.  You need to specify a profile name, ID or permalink and the hostname of the server, plus user ID and password if required.
#When multiple files are output, the module can work in two ways.  You can specify it as an input-method, and it will set Batch mode which will run all process-methods and output-methods once, sequentially, for each output.
#Alternatively, you can specify a <chain_route> option.  This will cause the method to run CDS with the given routes, and provide --input-media and --input-inmeta from the current state of this route.  These are run in parallel.
#If using <chain_route>, you can also set <asynchronous_chain/> to exit with success once the routes are spawned.  If this option is not set, the method will wait until all chained routes have completed before exiting.
#
#Arguments:
# <server>hostname_or_ip - Elemental server or cluster controller
# <port>n [OPTIONAL] - port number, defaults to 80
# <username>username [OPTIONAL] - log in with this username. Defaults to none.
# <password>password [OPTIONAL] - log in with this password. Defaults to none.
# <preroll_file>/path/to/preroll [OPTIONAL] - tell Elemental to use a preroll file. Defaults to none, substitutions are accepted.
# <postroll_file>/path/to/postroll [OPTIONAL] - tell Elemental to use a postroll file. Defaults to none, substitutions are accepted.
# <map_elemental_path>/path/on/elemental [OPTIONAL] - often the path to an output file is different on Elemental than on the local CDS node.  In this case, you can put the different part of the path into this argument and it will get replaced by the contents of the <map_cds_path> argument below
# <map_cds_path>/path/on/cds [OPTIONAL] - see map_elemental_path
# <profileid>profile - Name, numeric ID or permalink of an Elemental Output Profile.  This is how the system determines the properties of the transcoded file(s)
# <specific_chain_route>modifier:routename|modifier:routename [OPTIONAL] - use a specific route, given by 'routename', to chain to if the 'name modifier' of the Elemental profile matches 'modifier'. Useful to perform different post-encoding processing for different encoded formats.
#<chain_route>routename [OPTIONAL] - use the given route name to continue processing transcoded media files, executing in parallel (see notes above). This route is invoked with --input-media set to the transcoded media file and --input-inmeta set to a freshly created .inmeta file with the current state of the datastore.  If you don't use this option, then call elemental_transcode as an input-method to take advantage of batch mode processing.
#<asynchronous_chain/> [OPTIONAL] - when using <chain_route>, don't wait for the chained routes to terminate but exit as soon as they're up and going
# <no_batch/> [OPTIONAL] - by default, if there is more than one Preset in the Profile we will go to Batch mode if chain_route is not set.  This can cause problems with HLS, which is treated as a single output despite having multiple Presets.  You can set <no_batch/> to force the method to act as if there is only a single output.
#END DOC

#Globals
$refresh_delay = 15 #in seconds. Not much point setting to 10s or less as the status from Elemental only updates every 15-20s or so
#End globals

class ElementalMetadataMapper
    #    video_track_keymap = { 'video_description_h264_settings_bitrate' => 'bitrate',
    #                        'video_description_width' => 'width',
    #                    'video_description_height' => 'height',
    #                    'duration' => 'duration', #get from input_info
    #                    => 'size',
    #                    => 'framerate',
    #                    => 'index',
    #                    'video_description_codec' => 'format',
    #                    => 'start',
    #                    'video_description_h264_settings_profile' => 'profile' }
                        
                        #media_keymap = { '' => 'bitrate',
                        # => 'format'
def generic_properties(data,prefix)
rtn = []

data.each do |key,value|
    puts "debug: got key #{key}"
    realkey = key
    if(prefix)
        unless(/^#{prefix}/.match(key))
            next
        end
        realkey = key.gsub(/^#{prefix}_*/,'')
    end
    if(value.is_a?(Hash))
        next
    end
    if(value.is_a?(Array))
       string = ""
       value.each do |v|
        string += "#{v}|"
       end
       string.chop
       rtn << realkey << string
    else
       rtn << realkey << value
    end
end
return rtn
end

#returns an Array suitable for putting into Datastore::set
def video_properties(outputinfo)

#unless(outputinfo.is_a?(Hash))
#    return
#end
#rtn = [ 'track', 'vide' ]
#rtn << self.generic_properties(outputinfo)
#rself.generic_properties(outputinfo['stream'],'video_description').each do |v|
#	rtn << v
#end
rtn = self.generic_properties(outputinfo['stream'],'video_description')

puts "Video properties to set:"
ap rtn

return rtn
end #

def audio_properties(outputinfo)

#rtn = [ 'track', 'audi' ]
#self.generic_properties(outputinfo['stream'],'audio_description').each do |v|
#	rtn << v
#end
rtn = self.generic_properties(outputinfo['stream'],'audio_description')

puts "Audio properties to set:"
ap rtn

end #audio_track_properties

def media_properties(outputinfo)

#rtn = [ 'media' ]
#self.generic_properties(outputinfo,nil).each do |v|
#	rtn << v
#end
rtn = self.generic_properties(outputinfo,nil)

puts "Media properties to set:"
ap rtn
       
end #media_properties

end #class ElementalMetadataMapper

#START MAIN
#print output synchronously, so progress appears in the log
$stdout.sync = true
$stderr.sync = true

$store = Datastore::Episode5.new('elemental_transcode')

inputfile = ENV['cf_media_file']
unless(inputfile)
    puts "-ERROR: No media to work on.  Make sure that you have specified <take-files>media in the route file"
    exit(1)
end

hostname = $store.substitute_string(ENV['server'])
unless(hostname)
    puts "-ERROR: You need to specify an elemental server or cluster controller to talk to, using the <server> option"
    exit(1)
end

profileid = $store.substitute_string(ENV['profileid'])
unless(profileid)
    puts "-ERROR: You need to specify an elemental output profile to use, using the <profileid> option"
    exit(1)
end

port = 80
if(ENV['port'])
    begin
        port = $store.substitute_string(ENV['port']).to_i
    rescue Exception=>e
        puts "-WARNING: Unable to get a port number from " + $store.substitute_string(ENV['port']) + ".  Using default of 80."
    end
end #if(ENV['port'])

username = nil
passwd = nil
if(ENV['username'])
    username = $store.substitute_string(ENV['username'])
end
if(ENV['passwd'])
    username = $store.substitute_string(ENV['passwd'])
end

mapfrom = nil
mapto = nil

preroll = nil
if(ENV['preroll_file'])
    preroll = $store.substitute_string(ENV['preroll_file'])
end

postroll = nil
if(ENV['postroll_file'])
    postroll = $store.substitute_string(ENV['postroll_file'])
end

if(ENV['map_elemental_path'])
    unless(ENV['map_cds_path'])
        puts "-ERROR: If you specify <map_elemental_path>, you must specify a path to map to using <map_cds_path>"
        exit(1)
    end
    mapfrom = $store.substitute_string(ENV['map_elemental_path'])
    mapto = $store.substitute_string(ENV['map_cds_path'])
end

chainroute = nil
if(ENV['chain_route'])
    chainroute = "/etc/cds_backend/routes/" + $store.substitute_string(ENV['chain_route'])
    unless(File.exists?(chainroute))
        puts "-WARNING: route file #{chainroute} does not exist"
        chainroute = chainroute + ".xml"
    end
    unless(File.exists?(chainroute))
        puts "-ERROR: route file #{chainroute} does not exist"
        exit(1)
    end
    chainroute=File.basename(chainroute)
end

specific_chain_table = {}
if(ENV['specific_chain_route'])
    ENV['specific_chain_route'].split(/\|/).each do |routespec|
        parts = routespec.match(/^([^:]+):(.*)$/)
        if(parts)
            specific_chain_table[parts[1]] = "/etc/cds_backend/routes/" + $store.substitute_string(parts[2])
            unless(File.exists?(specific_chain_table[parts[1]]))
                puts "-WARNING: route file #{specific_chain_table[parts[1]]} does not exist"
                specific_chain_table.delete(parts[1])
            end #unless(File.exists?)
        else
            puts "-WARNING: The string #{routespec} does not identify a name modifier and a route (format does not appear to be {modifier}:{routename}"
        end #if(parts)
    end #specific_chain_route.split.each
end #if(ENV['specific_chain_route'])

puts "INFO: Specific chain route instructions:"
ap(specific_chain_table)

asynchronous_chain = false
if(ENV['asynchronous_chain'])
    asynchronous_chain = true
end

$debug = false
if(ENV['debug'])
    $debug = true
end

#OK, now the argument processing is sorted let's do something more interesting
api = ElementalAPI.new(hostname,port: port,user: username,passwd: passwd)
if($debug)
    ap api
end
api.debug = $debug

requiredAudioTracks = [1,2] #most of our master files have four, single-channel tracks in them.
                            #We want to take the first two and map them to left & right channels of a single track in the output file.
                            #BUT.... some files might already only have a single audio track.
                            #This causes the transcoder to throw an error (1040)
                            #This is caught below, resulting in this array being modified and the submit re-tried
                            
begin
    jobinfo = api.submit(inputfile,preroll: preroll, postroll:postroll, profileid: profileid, audioTracks: requiredAudioTracks)

    begin
    sleep($refresh_delay)
        jobinfo.refresh_status!()
        if($debug)
            ap jobinfo.status
        else
            puts "Job #{jobinfo.id} is #{jobinfo.status['status']} on #{jobinfo.status['node']}, #{jobinfo.status['pct_complete']}% complete, elapsed time = #{jobinfo.status['elapsed_time_in_words']}"
        end
    end while(not jobinfo.complete?)
rescue ElementalException=>e
    puts "-ERROR: #{e.message}"
    if e.has_code?(1040) #this means that the audio mapping is not correct.
        puts "INFO: Re-trying assuming a single audio track"
        requiredAudioTracks = [1]
        retry
    end
    
    if($debug)
        puts e.backtrace
    end
    exit(1)
end #exception handling

puts "+SUCCESS: Job completed successfully after #{jobinfo.status['elapsed_time_in_words']}"

#Get the full job info now it's completed
jobinfo = api.job(jobinfo.id)
if($debug)
    puts jobinfo.dump
end

did_fail = false

tempFile = open(ENV['cf_temp_file'],'w')
batch = false

if(jobinfo.output_list.count>1 and not chainroute and not ENV['no_batch'])
    batch = true
    tempFile.write("batch=true\n")
end

output_file_list = []
m3u8_master = ""

pids_to_wait = Array.new

jobinfo.output_list.each do |out|
begin
    unless(out['full_uri'])
        puts "-ERROR: output id is missing filename!"
        next
    end
    
    #Annoyingly, Elemental does not tell us the _master_ m3u8 that it has created, only the invididual encoding ones.
    #However,the filename of the master should be the same as the individual encoding, minus the name modifier.
    #So, if we are dealing with m3u8, we remove the name modifier with a simple regex and take that as the potential master name. If we've already processed it, then skip; if not, then we take that as the "media file" going forwards.
    if(out['extension'] == "m3u8")
        puts "INFO: dealing with m3u8 encoding"
        regex_source=out['name_modifier']
        puts "INFO: name modifier is #{regex_source}"
        potential_master = out['full_uri'].sub( %r{#{regex_source}\.m},".m")
        puts "INFO: potential master name is #{potential_master}, current master name is #{m3u8_master}"
        if(potential_master == m3u8_master)
            puts "INFO: Already got master m3u8 #{potential_master}, skipping this output."
            next
        end
        if(m3u8_master=="")
            #Hmmmm. It would appear that Ruby is referencing strings here. So, if the below line is a straight = , then when the mapfrom line outputpath.gsub! runs below, then it over-writes outputpath, which also overwrites out['full_uri'] due to an =, which also over-writes potential_master due to an =, which would then over-write m3u8_master due to an =. So the comparison potential_master == m3u8_master always fails.  Therefore, we create a new string here with the same _content_ as potential_master, and the comparison works.
            m3u8_master = "#{potential_master}"
            out['full_uri'] = potential_master
        end
    end
    
    #FIXME: need to extract output metadata and populate track/media sections!
    #output_file_list << out['full_uri']
    #puts "-WARNING: Incomplete code, no file stats being output"
    mapper = ElementalMetadataMapper.new
    $store.set('media',mapper.media_properties(out))
    $store.set('track','vide',mapper.video_properties(out))
    $store.set('track','audi',mapper.audio_properties(out))
       
    outputpath = out['full_uri']
    if(mapfrom)
        puts "INFO: mapping paths from #{mapfrom} to #{mapto}"
        outputpath.gsub!(/#{mapfrom}/,mapto)
        puts "INFO: new output path is #{outputpath}"
    end
    
    outputdir = File.dirname(outputpath)
    if($debug)
        puts "INFO: output directory is #{outputdir}"
    end
    unless(Dir.exists?(outputdir))
        puts "-WARNING: output directory does not exist on this host! Expect breakage!"
    end
    
    begin
        metacontent = $store.export_meta
        
        outputmeta = outputpath+".meta"
        
        puts "INFO: Writing metadata to #{outputmeta}"
        fpmeta = File.open(outputmeta,"w")
        fpmeta.write(metacontent)
        fpmeta.close()
    #FIXME: should this be a fatal error? Should it be tunable? Should we only catch certain exceptions?
    rescue Exception=>e
    	puts e.backtrace
        puts "-ERROR: Unable to output metadata to #{outputmeta}: #{e.message}"
        outputmeta = ""
    end
    
    puts "INFO: Name modifier is #{out['name_modifier']}"
    if(specific_chain_table[out['name_modifier']])
       specific_route = specific_chain_table[out['name_modifier']]
       puts "INFO: Chaining to #{specific_route} due to specific_chain_route instruction"
       #cmdline="/usr/local/bin/cds_run.pl --route \"#{specific_route}\" --input-meta \"#{outputmeta}\" --input-media \"#{outputpath}\" >/dev/null 2>&1 </dev/null"
       #pid = spawn(cmdline)
       
       #if(asynchronous_chain)
       #    Process.detach(pid)
       #    else
       #    pids_to_wait << pid
       #end
       tempFile.write("chain=#{specific_route},#{outputpath},,#{outputmeta}\n")
       
    elsif(chainroute)
    #cmdline="/usr/local/bin/cds_run.pl --route \"#{chainroute}\" --input-meta \"#{outputmeta}\" --input-media \"#{outputpath}\" >/dev/null 2>&1 </dev/null"
    #    pid = spawn(cmdline,{:pgroup=>0,:in=>:close,:out=>:close,:err=>:close})
    #    if(asynchronous_chain)
    #        Process.detach(pid)
    #    else
    #        pids_to_wait << pid
    #    end
        tempFile.write("chain=#{chainroute},#{outputpath},,#{outputmeta}\n")
    else
        if(batch)
            puts "INFO: Outputting files in batch mode. Please ensure that elemental_transcode is called as an INPUT method to make sure that this works"
            tempFile.write(outputpath+","+outputmeta+"\n")
        else
            puts "INFO: Only one output so not using batch mode"
            tempFile.write("cf_media_file=#{outputpath}\n")
            tempFile.write("cf_meta_file=#{outputmeta}\n")
        end
        #raise StandardError,"Batch mode functionality not yet implemented"
    end
rescue Exception=>e
    puts "-ERROR: #{e.message}"
    puts e.backtrace
    did_fail = true
end
end #jobinfo.output_list.each

pids_to_wait.each do |pid|
    puts "INFO: Waiting for sub-route pid #{pid} to exit"
    Process.wait(pid)
    rtncode = $?.exitstatus
    if(rtncode != 0)
        puts "WARNING: Subroute #{pid} failed, exit status was #{rtncode}"
    end
end

tempFile.close()

if(did_fail)
    exit(1)
else
    exit(0)
end
