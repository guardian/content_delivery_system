#!/usr/bin/env ruby

#This method runs Amazon's Elastic Transcoder service on a given asset.
#Due to the way that ETS works, the asset must be available _in an s3 bucket_ before running this method, and finished assets are output to an S3 bucket.
#See the documentation for s3_put and s3_get if you need to transport assets to or from S3 in order to use this method.
#
#At the moment, this only directly runs on servicers that have access to AWS roles for permissions settings, but access_key and secret_key arguments will be supported soon.
#
#Arguments (all support substitutions unless notes):
#  <region>{aws-region} - use this region when connecting to ETS resources.  Defaults to eu-west-1 if no other region is supplied.
#  <pipeline>{name} - use the ETS pipeline with this name for transcoding.  ETS pipelines are configured in the Elastic Transcoder Service panel in the AWS web control system, and the name can be looked up from there.  Internally, this is mapped to the ID number of the pipeline.
#  <preset>{name} - use this ETS preset name for transcoding.  ETS presets are configured in the Elastic Transcoder Service panel in the AWS web control system, and the name can be looked up from there.
#  <presets>{preset1}|{preset2}|... - synonym for preset, useful when you are encoding HLS
#  <preset_append>_{app1}|_{app2}|... - append this value to the output key of each preset to distinguish them. Normally something like the bitrate, e.g. _512k, 768k, 1M, etc.  Needed to encode HLS
#  <playlist>{outputname} [OPTIONAL] - when using multiple presets, link them together in a playlist. Needed to encode HLS
#  <playlist_format>HLSv3|HLSv4|Smooth [OPTIONAL] - use this format for the playlist
#  <segment_duration>10 [OPTIONAL] - when encoding HLS, how long each 'chunk' should be, in seconds. Defaults to 10s.
#  <filename>/path/to/file - transcode this file.  This file must exist in Amazon S3, in the "input bucket" specified in the configuration for your selected pipeline (consult the ETS panel in the Amazon control centre to get at the pipeline configuration)
#  <output_prefix>{path} - Output the transcoded file to this path within the S3 bucket specified as the "output bucket" in the configuration for your selected pipeline.  Files are named by this method according to the following convention: {filebase}_{bitrate}_{codec}.{extension}, where {filebase} is the incoming filename minus its extension, {bitrate} is the video bitrate of the selected preset expressed as either kbit/s or Mbit/s, {codec} is the name of the video codec of the selected preset (with non alphanumeric characters removed) and {extension} is the file extension for the wrapper format specified in the selected preset
# <round_down/> - [optional] Round down the requested duration to the nearest second. Only effective if the media:duration key is set by the datastore at the point where the method is invoked
#  <output_file_key>keyname - NOTE: this refers to a CDS datastore Key, not an S3 bucket key!! Output the final, transcoded filename into this key in the CDS datastore for use by future methods (like s3_get)
#  <acl_public/> - NOT YET IMPLEMENTED - If specified, tells the method to open up the permissions on the output files so that they are world-readable (i.e., published, available to anybody without any login)
#END DOC

require 'aws-sdk-v1'
#require 'yaml'
require 'awesome_print'

class DestinationFileExistsError < StandardError
end

class InvalidSectionError <StandardError
end

class TranscodeFailedError <StandardError
end

def debugmsg(msg)
if ENV['debug'] 
	puts "DEBUG: #{msg}\n"
end
end

def datastore_set(key,value)
`/usr/local/bin/cds_datastore.pl set meta "#{key}" "#{value}"`
end

def substitute_string(string)
`/usr/local/bin/cds_datastore.pl subst "#{string}"`
end

#Section should be one of meta, media or track
def datastore_get(section,key)
if section!="meta" and section!="media" and section!="track"
	raise InvalidSectionError,"Section name '#{section}' is not one of meta, media, or track"
end

`/usr/local/bin/cds_datastore.pl get "" "#{section}" "#{key}"`
end

def lookup_pipeline(name)

page_token=nil
begin
	if page_token
		result=$ets.list_pipelines(:page_token=>page_token)
	else
		result=$ets.list_pipelines()
	end
	result.pipelines.each { |p|
		#debugmsg "got pipeline called #{p.name} with id #{p.id}"
		if p.name==name
			return p.id
		end
	}
	page_token=result['next_page_token']
end while page_token

raise "Couldn't find a pipeline called #{name}"

end

def lookup_preset(name)

page_token=nil
begin
        if page_token
                result=$ets.list_presets(:page_token=>page_token)
        else
                result=$ets.list_presets()
        end
        result.presets.each { |p|
            #debugmsg "got preset called #{p.name} with id #{p.id}"
                if p.name==name
                        return p
                end
        }
        page_token=result['next_page_token']
end while page_token

raise "Couldn't find a preset called #{name}"

end


#START MAIN
$stdout.sync = true
$stderr.sync = true
begin
region='eu-west-1'
if ENV['region']
	region=ENV['region']
end

unless ENV['pipeline']
	raise "You must give the name of an Elastic Transcoder pipeline in the <pipeline> argument in the route file"
end

unless ENV['preset'] or ENV['presets']
	raise "You must give the name of an Elastic Transcoder preset in the <preset> argument in the route file"
end

unless ENV['filename']
	raise "You must give the name of the file to transcode, which should exist in the s3 bucket referred to by the AWS pipeline configuration, in the <filename> argument in the route file"
end


input_path=substitute_string(ENV['filename']).chomp

input_prefix=File.dirname(input_path)
filename=File.basename(input_path)

if ENV['output_prefix']
	prefix=substitute_string(ENV['output_prefix']).chomp + '/'
end

parts = filename.match(/^(?<Name>.*)\.(?<Xtn>[^\.]+)$/x)
debugmsg "matching against #{filename}..."

if parts
	outputbase=parts['Name']
else
	outputbase=filename
end

puts "Using output base filename #{outputbase}"

puts "Using region #{region}"

#using the $ symbol declares ets as a glocal
$ets=AWS::ElasticTranscoder::Client.new(:region=>region);
$s3=AWS::S3.new	#we don't need to specify a region for S3

pipeline_id=lookup_pipeline(substitute_string(ENV['pipeline']).chomp)
puts "Using pipeline ID #{pipeline_id}\n"

presetNames = []
if ENV['presets']
    presetNames = ENV['presets'].split('|')
end
if ENV['preset']
    presetNames << ENV['preset']
end

presetAppends = []
if ENV['preset_append']
    presetAppends=ENV['preset_append'].split('|')
end

segment_duration = 10
if ENV['segment_duration']
    begin #exception handling for string-to-int conversion
        segment_duration = substitute_string(ENV['segment_duration']).to_i
    rescue Exception=>e
        puts "WARNING: Error setting segment duration - #{e.message}"
    end
end #if ENV['segment_duration']
    
outputs = []
output_names = []
containers = []
n = 0
presetNames.each do |presetName|
    preset=lookup_preset(substitute_string(presetName).chomp)
    puts "Output #{n}: Using preset ID #{preset.id}\n"
    
    outputinfo = {}
    
    outputinfo[:preset_id] = preset.id
    #append this into the filename, to distinguish different assets

    #if preset.has_key?('video')
    begin
        bitrate=preset.video.bit_rate.to_f
        raise "Preset #{preset.name} did not specify a valid bitrate" if bitrate == 0
        
        if bitrate > 1024
            brstring=(bitrate/1024).ceil.to_s + 'M'
        else
            brstring=bitrate.ceil.to_s + 'k'
        end

        fileappend='_' + brstring + '_' + preset.video.codec.gsub(/[^\w\d]/,'')
    rescue Exception=>e
        puts "-WARNING: #{e.message}"
        fileappend=""
    end

    presetappend = ""
    if presetAppends[n]
        presetappend = presetAppends[n]
    end
    
    outputinfo[:key]=outputbase + fileappend + presetappend
    outputinfo[:thumbnail_pattern]=""
    if ENV['watermark']
        outputinfo[:input_key]=substitute_string(ENV['watermark'])
    end
    #if we're not making an HLS wrapper then put in the container as a file extension. If not, append a _ to separate out the sequence numbers
    
    if preset.container != 'ts'
        outputinfo[:key] += '.' + preset.container
    else
        outputinfo[:key] += '_'
    end
    
    output_names << outputinfo[:key]
    containers << preset.container
    
    if ENV['playlist']  #if a playlist is specified, assume we're doing HLS and hence need segments
        outputinfo[:segment_duration] = segment_duration.to_s
    end
    outputs << outputinfo
    n += 1
end

tries=0

begin # exception handling for createjob below
	args = { :pipeline_id=>pipeline_id,
			:input=>{ :key=>input_path,
				:frame_rate=>'auto',
				:resolution=>'auto',
				:aspect_ratio=>'auto',
				:interlaced=>'auto',
				:container=>'auto'
			},
            #	:output=>{ :key=>outputname,
			#	:preset_id=>preset.id
			#}
            :outputs=>outputs
		}
    if ENV['playlist']
        playlist_format = "HLSv3"
        if ENV['playlist_format']
            playlist_format = substitute_string(ENV['playlist_format'])
        end
        
        if tries==0
            playlist_name=substitute_string(ENV['playlist']).gsub(/\s*$/,'')
        else
            playlist_name=substitute_string(ENV['playlist']).gsub(/\s*$/,'')+"-#{tries}"
        end
        
        args[:playlists] = [
          {
            :name => playlist_name,
            :format => playlist_format,
            :output_keys => output_names
          }
        ]
    end #if ENV['playlist]
	given_duration=datastore_get('media','duration').chomp
	if given_duration.match(/^[\d\.]+$/)
		puts "INFO: Using provided duration #{given_duration} as requested clip length"
#		args[:output][:time_span]={
#						:duration=>given_duration
#						};
		if ENV['round_down']
			numeric_duration=given_duration.to_f
			given_duration=numeric_duration.floor.to_s
		end

		args[:output][:composition]=[
				{
					:time_span=>{
						:duration=>given_duration
					}
				}
		];
	else
		puts "-WARNING: Provided duration '#{given_duration}' is either blank or not valid"
	end
	if prefix
		args[:output_key_prefix]=prefix
	end
	
	ap args

	result=$ets.create_job(args)
	
	#puts result.to_yaml
	
	puts "Status of job: #{result.job.status}"
	jobid=result.job.id
	
	debugmsg "Job ID: #{jobid}"
	
	is_running=true
	while is_running
		sleep(10)
		result=$ets.read_job(:id=>jobid)
		print "Job status is: #{result.job.status}\n"
		if result.job.status=='Error'
			ap result.job
			begin #exception block
				if result.job!=nil and result.job[:output] != nil and result.job[:output][:status_detail] !=nil
					status_detail = result.job[:output][:status_detail]
					if status_detail.match(/The specified object could not be saved in the specified bucket because an object by that name already exists/)
						raise DestinationFileExistsError, "AWS said #{result.job[:output][:status_detail]}"
					end
					if result.job.playlists != nil and result.job.playlists[0][:status_detail] != nil and result.job.playlists[0][:status_detail].match(/The specified object could not be saved in the specified bucket because an object by that name already exists/)
						raise DestinationFileExistsError, "AWS said #{result.job[:output][:status_detail]}"
					end
        end
			rescue NoMethodError=>e	#sometimes status_detail gives a NoMethodError but I'm not sure where
				print "WARNING: #{e.message}"
				print "#{e.backtrace}"
      end #exception block
      begin
        status_detail = result.job[:output][:status_detail]
        raise TranscodeFailedError, "Transcode failed: " + status_detail
      rescue Exception=>e
        raise TranscodeFailedError, "Unable to get detailed error information: #{e.message}"
      end
		end
		if result.job.status=='Complete'
			is_running=false
		end
  end

rescue DestinationFileExistsError=>e	#ETS won't over-write an existing file. If we detect this is the problem, then bump a number onto the end of the output filename and try again
	puts "Requested output file already exists: #{e.message}"
	tries=tries+1
    #FIXMEFIXMEFIXME
    #this line needs to be changed to update all of the potential filenames in outputs
    n=0
    output_names = []
    outputs.each { |o|
        if o[:key].sub!(/-\d+\.#{containers[n]}$/,"-#{tries.to_s}.#{containers[n]}")
            output_names << o[:key]
            next
        end
        if o[:key].sub!(/\.#{containers[n]}$/,"-#{tries.to_s}.#{containers[n]}")
            output_names << o[:key]
            next
        end
        if o[:key].sub!(/-\d+(.{0,1})$/,"-#{tries.to_s}\\1")
            output_names << o[:key]
            next
        end
        if o[:key].sub!(/_$/,"-#{tries.to_s}_")
            output_names << o[:key]
            next
        end
        o[:key] += "-#{tries.to_s}"
        output_names << o[:key]
        
        n+=1
    }
    
	#outputname=outputbase + fileappend + '-' + tries.to_s + '.'+ preset.container
	retry
end

jobinfo = $ets.read_job(:id=>jobid).data

jobinfo = jobinfo[:job]
puts "DEBUG: returned job information: "
ap jobinfo

ap jobinfo[:playlists][0]

if jobinfo[:playlists].length > 0
    outputname = jobinfo[:output_key_prefix] + jobinfo[:playlists][0][:name] + ".m3u8"
else
    outputname = jobinfo[:outputs][0][:key]
end

if ENV['output_file_key']
	puts "INFO: outputting transcoded file name #{outputname} to datastore key #{ENV['output_file_key']}"
	datastore_set(ENV['output_file_key'],outputname)
end

if ENV['acl_public']
	puts "INFO: setting stored output file to public read access"
#FIXME: need to look up the bucket name from the pipeline config, and then use the key field from the job status
	puts "-WARNING: not yet implemented."
end

puts "+SUCCESS: File #{filename} was successfully transcoded to #{outputname}"

rescue Exception=>e
	puts "\n\n-ERROR: #{e.message} at #{e.backtrace}\n"
	exit 1
ensure

end

