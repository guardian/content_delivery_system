#!/usr/bin/env ruby

#This CDS method will import the given media file to Vidispine and then set it
#up as a PLUTO master. Designed for use with the PlutoExport Premiere Pro panel.
#
#Arguments:
#  <video_input>/path/to/media/file - filepath to the media file to be imported
#  <storage_id>vsid - Vidispine ID of the storage
#  <transcode_tags>lowres|WebM|.... [OPTIONAL] - transcode to these formats, identifed as vidispine "tags" (Transcode Format in Portal)
#  <gnm_category>name - Set the "category" field in PLUTO to this value. Essential for proper media management
#  <extra_metadata>field_name=value|another_field_name=another_value|... [OPTIONAL] - set the given fields on a piece of media as it is ingested. For valid field names, refer to the Metadata Editor in Cantemo Portal
#  <vidispine_host>hostname [OPTIONAL] - host to communicate with (defaults to localhost)
#  <vidispine_port>portnum [OPTIONAL] - port to communicatewith Vidispine on (defaults to 8080)
#  <vidispine_user>username - username for Vidispine
#  <vidispine_password>pass - password for Vidispine
#  <xml_input>/path/to/xml/file - filepath to the Final Cut Pro XML file to be imported
#  <project>vsid - Vidispine ID of the project to import the new master into
#  <attempts>n [OPTIONAL] - retry this many times before failing (default: 80)

#END DOC

require 'date'
require 'PLUTO/Entity'
require 'Vidispine/VSStorage'
require 'Vidispine/VSMetadataElements'
require 'Vidispine/VSCollection'
require 'Vidispine/VSItem'
require 'CDS/Datastore'
require 'yaml'
require 'awesome_print'
require 'fileutils'
require 'net/http'

class InvalidMetadataError < StandardError
end

class CDSFormatter < Logger::Formatter
    def call(severity, time, progname, msg)
        case severity
        when 'INFO'
            prefix=""
        when 'WARNING'
            prefix="-"
        when 'ERROR'
            prefix="-"
        else
            prefix=""
        end
        
        if ENV['cf_datastore_location']
           "#{prefix}#{severity}: #{msg}\n" #we're running in CDS, most likely
        else
            "#{time} #{severity}: #{msg}\n"
        end
    end
end

#START MAIN
$store=Datastore.new('import_master')
$host="localhost"
if ENV['vidispine_host']
  $host = $store.substitute_string(ENV['vidispine_host'])
end

$port = 8080
if ENV['vidispine_port']
  begin
    $port = Integer($store.substitute_string(ENV['vidispine_port']))
  rescue Exception=>e
    puts "WARNING: #{e.message}"
  end
end

$user = $store.substitute_string(ENV['vidispine_user'])
$passwd = $store.substitute_string(ENV['vidispine_password'])
$destination_storage = $store.substitute_string(ENV['storage_id'])

$mediafileinput = $store.substitute_string(ENV['video_input'])
$xmlfileinput = $store.substitute_string(ENV['xml_input'])
$project = $store.substitute_string(ENV['project'])
$categoryName = $store.substitute_string(ENV['gnm_category'])
$username = $store.substitute_string(ENV['user'])

if ($store.substitute_string(ENV['transcode_tags']) != nil)
	$transcodeTags = $store.substitute_string(ENV['transcode_tags']).split(/\|/)
end

$max_attempts = 80
if ENV['attempts']
    begin
	$max_attempts = Integer(ENV['attempts'])
    rescue StandardError=>e
	print "WARNING: #{e.message}"
    end
end

$logger=Logger.new(STDERR)
$logger.formatter = CDSFormatter.new

$extraMeta = {}
if ENV['extra_metadata']
  ENV['extra_metadata'].split(/\|/).each {|entry|
    parts = entry.match(/^\s*([^=]+)=(.*)\s*$/)
    if parts
      key = $store.substitute_string(parts[1])
      value = $store.substitute_string(parts[2])
      $extraMeta[key]=value
    else
      $logger.error("Invalid metadata specification: #{entry}.  Does not appear to be in the form key=value or key={meta:substitued_field}")
    end
  }
  if ENV['debug']
    puts "DEBUG: extra metadata supplied:"
    ap($extraMeta)
  end
  
end

puts "Creating with the following metadata values:"
puts "\tMedia File: #{$mediafileinput}"

$logger.info("Looking up target project ID #{$project}")
begin
	proj = PLUTOProject.new($host,$port,$user,$passwd)
	proj.populate($project)
rescue VSNotFound=>e
	$logger.error("Project ID #{$project} does not exist in Pluto!")
	exit(1)
end

$logger.info("Project name is #{proj.metadata['gnm_project_headline']}, commission name is #{proj.metadata['gnm_commission_title']}")


$logger.info("Looking up target storage #{$destination_storage}")
storage = VSStorage.new($host,$port,$user,$passwd,run_as: $username)
begin
	$logger.info("Attempting to add the file with username: #{$username}")
	storage.populate($destination_storage)
rescue
	begin
		$fixedusername = $username.split('_').map(&:capitalize).join('_')
		$logger.info("Attempting to add the file with username: #{$fixedusername}")
		storage = VSStorage.new($host,$port,$user,$passwd,run_as: $fixedusername)
		storage.populate($destination_storage)
	rescue
		$logger.info("Attempting to add the file without a username.")
		storage = VSStorage.new($host,$port,$user,$passwd)
		storage.populate($destination_storage)
	end
end

#ap storage
#raise StandardError("Testing")

storageMethod = nil
storage.methodsOfType("file") do |m|
    #ap m
    next if(m.write!="true")
    storageMethod = m
end

if(storageMethod==nil)
    puts "-ERROR: No writable, file-based storage methods available for #{storage.id}"
    exit(1)
end

$logger.info("Done")

$logger.info("Finding requested media file")
destpath = URI.unescape(storageMethod.uri.path)
$logger.info("Destination path is #{destpath}")
mediaFile = $mediafileinput 
$logger.info("INFO: Looking for media file #{mediaFile}")
unless(File.exists?(mediaFile))
    $logger.error("File does not exist.")
    exit(3)
end

if(destpath.match(/\/$/))
    destpath.chop!
end

if(File.dirname(mediaFile) == destpath)
    puts "INFO: File is already present on storage #{storage.id}, no copy needed"
else
    $logger.info("Copying #{mediaFile} to #{destpath}")
    
    if File.directory?(destpath) and not destpath.end_with?('/')
      destpath += '/'
    end
    FileUtils.cp(mediaFile,destpath)
    
    mediaFile = File.join(File.dirname(destpath),File.basename(mediaFile))
    $logger.info("Done")
end
$logger.info("Done")

$logger.info("Attempting to add Vidispine file object")

storage.createFileEntity(File.basename(mediaFile))

$logger.info("Looking up file reference")
#FIXME: might not work with subdirectories in the storage
attempts = 0
begin
    fileRef = storage.fileForPath(File.basename(mediaFile))
rescue VSNotFound=>e
    attempts += 1
    puts "WARNING: File #{mediaFile} not found on storage #{storage.id} after #{attempts} attempts."
    if(attempts>$max_attempts)
        puts "Not present after #{$max_attempts} attempts, giving up."
        exit(5)
    end
    sleep(10)
    retry
end

ap fileRef

#puts fileRef.size

#puts fileRef.path

#puts fileRef.state

#puts fileRef.methods

#puts "Private Methods: -"

#puts fileRef.private_methods

#puts fileRef.id

ap proj

if(fileRef.memberOfItem!=nil)
    puts "File #{mediaFile} is already linked to item #{fileRef.memberOfItem.id}"
    #begin
    #    fileRef.memberOfItem.refresh
    #rescue VSException=>e
    #    puts e
    #end
    
else
    puts "File #{mediaFile} is not already linked to an item."
    if ($store.substitute_string(ENV['transcode_tags']) != nil)
		import_job = fileRef.importToItem( { 'gnm_type' => 'Master',
			'title' => File.basename(mediaFile),
			'gnm_master_website_headline' => File.basename(mediaFile),
			'gnm_asset_category' => $categoryName,
			'gnm_commission_title' => proj.metadata['gnm_commission_title'],
			'gnm_project_headline' => proj.metadata['gnm_project_headline'],
			'gnm_commission_workinggroup' => proj.metadata['gnm_commission_workinggroup'],
#			'__collection' => $project,
#			'__ancestor_collection' => $project,	
			}.merge!($extraMeta),
			tags: $transcodeTags,
		)
    else
		import_job = fileRef.importToItem( { 'gnm_type' => 'Master',
			'title' => File.basename(mediaFile),
			'gnm_master_website_headline' => File.basename(mediaFile),
			'gnm_asset_category' => $categoryName,
			'gnm_commission_title' => proj.metadata['gnm_commission_title'],
			'gnm_project_headline' => proj.metadata['gnm_project_headline'],
			'gnm_commission_workinggroup' => proj.metadata['gnm_commission_workinggroup'],
#			'__collection' => $project,
#			'__ancestor_collection' => $project,
			}.merge!($extraMeta),
			tags: [],
		)
    end
	
	#puts $host
	
	#puts fileRef['id']
	
	#url = URI.parse('http://#{$host}/API/storage/file/#{fileRef["id"]}/state/CLOSED')
	#req = Net::HTTP::Get.new(url.to_s)
  	#http.request(req)

  	fileRef.close()
  	
  uri = URI.parse("http://#{$host}:#{$port}/API/storage/file/#{fileRef.id}/state/CLOSED")
  request = Net::HTTP::Put.new uri.path
  request.basic_auth($user, $passwd)
  #response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }
  #ap response.body 

  	
  	#puts fileRef.state
  	
    while(not import_job.finished?)
        puts "Importing, status: #{import_job.status}"
        sleep(5)
        import_job.refresh
        if(import_job.failed?)
            puts "-ERROR: Import job failed."
            exit(7)
        end
    end
end

puts "Import job succeeded"
fileRef = storage.fileForPath(File.basename(mediaFile))
item = fileRef.memberOfItem

begin
    item.addAccess(VSAccess.new(group: 'AG Multimedia Creator',
                                   permission: ACL_PERM_READWRITE,
                                   recursive: 'true'))
    item.addAccess(VSAccess.new(group: 'AG Multimedia Admin',
                                   permission: ACL_PERM_READWRITE,
                                   recursive: 'true'))
    item.addAccess(VSAccess.new(group: 'AG Multimedia Commissioners',
                                   permission: ACL_PERM_READ,
                                   recursive: 'true'))
rescue VSException => e
    puts e
    exit(1)
end

puts "Imported asset can be found at #{fileRef.memberOfItem.id}"

$store.set('meta', {'master_id' => fileRef.memberOfItem.id})

#once asset is imported, should update the metadata with project & commission names, etc.
#exit(7)

itemimported=VSItem.new($host,$port,$user,$passwd) 

begin
    itemimported.populate(fileRef.memberOfItem.id)
rescue VSException=>e
    puts "-ERROR: Unable to look up Vidispine item '#{vsid}'"
    puts e.to_s
    #exit(1)
rescue Exception=>e
    puts "-ERROR: Unable to look up Vidispine item '#{vsid}'"
   puts e.message
    puts e.backtrace
    #exit(1)
end


collection = VSCollection.new($host,$port,$user,$passwd)

collection.populate($project)

collection.addChild(fileRef.memberOfItem)

itemimported.setMetadata({ 'gnm_master_generic_status' => 'None' }, groupname: nil)

def post_xml url_string, xml_string
  uri = URI.parse url_string
  request = Net::HTTP::Post.new uri.path
  request.body = xml_string
  request.content_type = 'text/xml'
  request.basic_auth($user, $passwd)
  response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }
  response.body
end

fcpxml = File.read($xmlfileinput)

#puts fcpxml

puts "Attempting to import Final Cut Pro XML file"

#post_xml("http://#{$host}/nle/item/#{fileRef.memberOfItem.id}/sidecar/?platform=mac&nle=ppro",fcpxml)

require 'rest_client'

$resturl = "http://#{$user}:#{$passwd}@#{$host}/master/#{fileRef.memberOfItem.id}/ingest/upload_edl/"

response = RestClient.post $resturl, :edl_file => File.new($xmlfileinput)

puts response.to_str

