#!/usr/bin/env ruby

#This CDS method will import the given media file to Vidispine and then set it
#up as a PLUTO master.  The named commission and project are created if they do
#not already exist.
#
#Arguments:
#  <take-files>media - you need to take the media file
#  <commission_name>blah - create the master within this commission. Commission is created if it does not exist. Ruby date parameters are supported (see http://ruby-doc.org/stdlib-2.0.0/libdoc/date/rdoc/Date.html#method-i-strftime)
#  <project_name>blah - create the master within this project name. Project is created if it does not exist.  Ruby date parameters are supported (see http://ruby-doc.org/stdlib-2.0.0/libdoc/date/rdoc/Date.html#method-i-strftime)
#  <project_type>blah - create a project of this type (Premiere, Cubase, etc.)
#  <commissioner_name>blah - set the commissioner's name to this. Only used when creating new commissions/projects
#  <working_group>blah - set the working group to this.  Only used when creating new commissions/projects
#  <subscribing_group_ids>n|n|n|.... - set the subscribing groups to these numbers.  Only accepts numeric IDs right now.
#  <owner_id>n - set the owner to this numeric user ID
#  <fail_if_not_exists/> - fail if the commission and project do not exist.
#  <storage_path>/path/to/destination - filepath to the storage to move the file to
#  <storage_id>vsid - Vidispine ID of the storage
#  <keep_original/> - copy, don't move the media file
#  <transcode_tags>lowres|WebM|.... [OPTIONAL] - transcode to these formats, identifed as vidispine "tags" (Transcode Format in Portal)
#  <gnm_category>name - Set the "category" field in PLUTO to this value. Essential for proper media management
#  <extra_metadata>field_name=value|another_field_name=another_value|... [OPTIONAL] - set the given fields on a piece of media as it is ingested. For valid field names, refer to the Metadata Editor in Cantemo Portal
#  <vidispine_host>hostname [OPTIONAL] - host to communicate with (defaults to localhost)
#  <vidispine_port>portnum [OPTIONAL] - port to communicatewith Vidispine on (defaults to 8080)
#  <vidispine_user>username- username for Vidispine
#  <vidispine_password>pass - password for Vidispine
#  <metadata_projection>projection_name [OPTIONAL] - use this (incoming) metadata projection to import sidecar XMLs
#  <field_mappings_file>/path/to/field_mappings [OPTIONAL] - use this YAML format list to perform field->field data interchange once all metadata has been set
#  <nosidecar/> [OPTIONAL] - do not attempt to import sidecar XMLs
#END DOC

require 'date'
require 'PLUTO/Entity'
require 'Vidispine/VSStorage'
require 'Vidispine/VSMetadataElements'
require 'CDS/Datastore'
require 'yaml'
require 'awesome_print'
require 'fileutils'

def commissionFindOrCreate(name,commissionerUID: nil,
                           workingGroupUID: nil,client: nil,
                           projectTypeUID: nil,subscribingGroupIDs: nil,
                           ownerID: nil, extraMeta: nil)
    comm = PLUTOCommission.new($host,$port,$user,$passwd)
    begin
        puts "INFO: Trying to find commission by the name of #{name}"
        comm.populateByTitle(name)
        puts "INFO: Found '#{comm.id}'"
    rescue PLUTONotFound
        puts "INFO: No commission found. Trying to create instead."
        begin
            comm.create!(name,commissionerUID: commissionerUID,
                     workingGroupUID: workingGroupUID,client: client,
                     projectTypeUID: projectTypeUID,subscribingGroupIDs: subscribingGroupIDs,
                     extraMeta: extraMeta, ownerID: ownerID)
            comm.addAccess(VSAccess.new(group: 'AG Multimedia Creator',
                                        permission: ACL_PERM_READWRITE,
                                        recursive: 'true'))
            comm.addAccess(VSAccess.new(group: 'AG Multimedia Admin',
                                        permission: ACL_PERM_READWRITE,
                                        recursive: 'true'))
            comm.addAccess(VSAccess.new(group: 'AG Multimedia Commissioners',
                                        permission: ACL_PERM_READ,
                                        recursive: 'true'))
         rescue VSException => e
             puts e
             exit(1)
        end
        puts "INFO: Created #{comm.id}"
    end
    return comm
end #def commissionFindOrCreate

def projectFindOrCreate(commission,name)

begin
    puts "INFO: Trying to find project by the name of #{name} within commission"
    commission.debug=true
    project = commission.findProject(name: name)
    puts "INFO: Found #{project.id}"
rescue PLUTONotFound
    puts "INFO: No project found. Trying to create instead."
    project = commission.newProject(name) #inherit other details from commission
    begin
        project.addAccess(VSAccess.new(group: 'AG Multimedia Creator',
                                    permission: ACL_PERM_READWRITE,
                                    recursive: 'true'))
        project.addAccess(VSAccess.new(group: 'AG Multimedia Admin',
                                    permission: ACL_PERM_READWRITE,
                                    recursive: 'true'))
        project.addAccess(VSAccess.new(group: 'AG Multimedia Commissioners',
                                    permission: ACL_PERM_READ,
                                    recursive: 'true'))
    rescue VSException => e
        puts e
        exit(1)
    end
    puts "INFO: Created #{project.id}"
end #exception handling

return project
end #def projectFindOrCreate

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
$store=Datastore.new('pluto_create_master')
$host="localhost"
if ENV['vidispine_host']
  $host = $store.substitute_string(ENV['vidispine_host'])
end

$port = 8080
if ENV['vidispine_port']
  begin
    $port = Integer($store.substitute_string(ENV['vidispine_port']))
  rescue Exception=>e
    puts "WARNING: #{e}"
  end
end

$user = $store.substitute_string(ENV['vidispine_user'])
$passwd = $store.substitute_string(ENV['vidispine_password'])
$destination_storage = $store.substitute_string(ENV['storage_id'])
$mdProjection = $store.substitute_string(ENV['metadata_projection'])
$mappingfile = $store.substitute_string(ENV['field_mappings_file'])

$projectTypeName = $store.substitute_string(ENV['project_type'])
$commissionerName = $store.substitute_string(ENV['commissioner_name'])
$workingGroupName = $store.substitute_string(ENV['working_group'])
$subscribingGroupIDs = $store.substitute_string(ENV['subscribing_group_ids']).split(/\|/)
$ownerID = $store.substitute_string(ENV['owner_id'])
$categoryName = $store.substitute_string(ENV['gnm_category'])

$commissionClientName = 'Guardian Editorial'
$transcodeTags = $store.substitute_string(ENV['transcode_tags']).split(/\|/)

dt = DateTime.now()
commissionNameTpl = $store.substitute_string(ENV['commission_name'])
commissionName = dt.strftime(commissionNameTpl)

projectNameTpl = $store.substitute_string(ENV['project_name'])
projectName = dt.strftime(projectNameTpl)

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

$logger.info("Looking up metadata for parameters...")
globalMeta = VSMetadataElements.new($host,$port,$user,$passwd)

projectTypeID = nil
globalMeta.findName("ProjectType") {|grp|
    #$logger.debug("Got group #{grp.name} #{grp.uuid}")
    if grp['gnm_subgroup_displayname'] == $projectTypeName
        projectTypeID = grp.uuid
        break
    end
}
if not projectTypeID
    raise InvalidMetadataError, "#{$projectTypeName} is not a valid ProjectType"
end

commissionerID = nil
globalMeta.findName("Commissioner"){ |grp|
    if grp['gnm_subgroup_displayname'] == $commissionerName
        commissionerID = grp.uuid
        break
    end
}
if not commissionerID
    raise InvalidMetadataError, "#{$commissionerName} is not a valid Commissioner"
end

workingGroupID = nil
globalMeta.findName("WorkingGroup") {|grp|
    if grp['gnm_subgroup_displayname'] == $workingGroupName
        workingGroupID = grp.uuid
        break
    end
}
if not workingGroupID
    raise InvalidMetadataError, "#{$workingGroupName} is not a valid Working Group"
end

$logger.info("Done.")
puts "Creating with the following metadata values:"
puts "\tProject type: #{$projectTypeName} => #{projectTypeID}"
puts "\tCommissioner: #{$commissionerName} => #{commissionerID}"
puts "\tWorking Group: #{$workingGroupName} => #{workingGroupID}"
puts "\tCommission Name: #{commissionName}"
puts "\tProject Name: #{projectName}"

$logger.info("Looking up target storage #{$destination_storage}")
storage = VSStorage.new($host,$port,$user,$passwd)
storage.populate($destination_storage)

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
mediaFile = ENV['cf_media_file'] 
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

$logger.info("Looking up file reference")
#FIXME: might not work with subdirectories in the storage
attempts = 0
begin
    fileRef = storage.fileForPath(File.basename(mediaFile))
rescue VSNotFound=>e
    attempts += 1
    puts "WARNING: File #{mediaFile} not found on storage #{storage.id} after #{attempts} attempts."
    if(attempts>10)
        puts "Not present after 10 attempts, giving up."
        exit(5)
    end
    sleep(10)
    retry
end

ap fileRef

if(fileRef.memberOfItem!=nil)
    puts "File #{mediaFile} is already linked to item #{fileRef.memberOfItem.id}"
    #begin
    #    fileRef.memberOfItem.refresh
    #rescue VSException=>e
    #    puts e
    #end
    
else
    puts "File #{mediaFile} is not already linked to an item."
    import_job = fileRef.importToItem( { 'gnm_type' => 'Master',
                         'title' => File.basename(mediaFile),
                         'gnm_master_website_headline' => File.basename(mediaFile),
                         'gnm_asset_category' => $categoryName,
			 'gnm_commission_title' => commissionName,
			 'gnm_project_headline' => projectName,
			 'gnm_commission_workinggroup' => workingGroupID,
			 }.merge!($extraMeta),
                         tags: $transcodeTags,
                         )

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

#once asset is imported, should update the metadata with project & commission names, etc.
#exit(7)


#puts "#{commissionName} #{projectName}"

commissionRef = commissionFindOrCreate(commissionName,
                                       commissionerUID: commissionerID,
                                       workingGroupUID: workingGroupID,
                                       client: $commissionClientName,
                                       projectTypeUID: projectTypeID,
                                       subscribingGroupIDs: '24',
                                       ownerID: '10'
                                       )
projectRef = projectFindOrCreate(commissionRef,projectName)
puts "INFO: Attempting to add video reference..."
projectRef.addChild(fileRef.memberOfItem)

$logger.info("Searching for sidecar XML file...")
sidecarpath = nil
mediaDir = File.dirname(mediaFile)
[ File.basename(mediaFile,".*"), File.basename(mediaFile)].each do |filename|
    tryFile = "#{filename}.xml"
    sidecarpath = File.join(mediaDir,tryFile)
    if File.exists?(sidecarpath)
        break
    end
    
    tryFile = "#{filename}.XML"
    sidecarpath = File.join(mediaDir,tryFile)
    if File.exists?(sidecarpath)
        break
    end
end

if sidecarpath and not ENV['nosidecar']
  begin
    $logger.info("Found sidecar XML at #{sidecarpath}.  Attempting to import...")
    File.open(sidecarpath) do |f|
    begin
        item.importMetadata(f.read,projection: $mdProjection)
    rescue VSException=>e
        $logger.error("Unable to import sidecar XML: #{e.to_s}")
    end
    end
    $logger.info("Done.")
  rescue Errno::ENOENT=>e
    $logger.error("Sidecar #{sidecarpath} does not exist.")
  rescue StandardError=>e
    $logger.error(e.backtrace)
    $logger.error("Error importing sidecar: #{e.message}")
  end
else
    $logger.info("No sidecar XML could be found.")
end

begin
if $mappingfile
    $logger.info("Mapping metadata according to #{$mappingfile}")
    item.refresh!
    File.open($mappingfile) do |f|
        mappings = YAML.load(f.read)
        destMeta = {}
        ap item.metadata
        mappings.each {|dest,src|
            $logger.debug("mapping #{dest} from #{src}")
            destMeta[dest] = item.metadata[src]
        }
        ap destMeta
	item.debug=true
        item.setMetadata(destMeta, groupname: "Asset")
    end
end
rescue VSException=>e
    $logger.error(e.to_s)
end
