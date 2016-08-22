#!/usr/bin/env ruby
$: << "./lib"
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
# <map_elemental_path>/path/on/elemental [OPTIONAL] - often the path to an output file is different on Elemental than on the local CDS node.  In this case, you can put the different part of the path into this argument and it will get replaced by the contents of the <map_cds_path> argument below
# <map_cds_path>/path/on/cds [OPTIONAL] - see map_elemental_path
# <profileid>profile - Name, numeric ID or permalink of an Elemental Output Profile.  This is how the system determines the properties of the transcoded file(s)
#<chain_route>routename [OPTIONAL] - use the given route name to continue processing transcoded media files, executing in parallel (see notes above). This route is invoked with --input-media set to the transcoded media file and --input-inmeta set to a freshly created .inmeta file with the current state of the datastore.  If you don't use this option, then call elemental_transcode as an input-method to take advantage of batch mode processing.
#<asynchronous_chain/> [OPTIONAL] - when using <chain_route>, don't wait for the chained routes to terminate but exit as soon as they're up and going
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

$store=Datastore::Episode5.new('testm3u8')
api = ElementalAPI.new("dc1-elemental-01",passwd: "",user:"")
mapfrom = nil
export_meta = nil

#Get the full job info now it's completed
jobinfo = api.job(50)
if($debug)
    puts jobinfo.dump
end

did_fail = false

tempFile = open(ENV['cf_temp_file'],'w')
batch = false

if(jobinfo.output_list.count>1)
    batch = true
    tempFile.write("batch=true\n")
end

chainroute = false

output_file_list = []
m3u8_master = ""

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
            puts "INFO: potential master name is #{potential_master}"
            if(potential_master == m3u8_master)
                puts "INFO: Already got master m3u8 #{potential_master}, skipping this output."
                next
            end
            if(m3u8_master=="")
                m3u8_master = potential_master
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
        rescue Exception=>e
            puts "-ERROR: Unable to output metadata to #{outputmeta}: #{e.message}"
            outputmeta = ""
        end
        
        if(chainroute)
            raise StandardError,"ChainRoute functionality not yet implemented"
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

tempFile.close()

if(did_fail)
    exit(1)
    else
    exit(0)
end
