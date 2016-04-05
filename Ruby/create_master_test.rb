#!/usr/bin/env ruby

require 'date'
$: << './lib'
require 'PLUTO/Entity'
require 'Vidispine/VSStorage'
#require 'vidispine/VSAcl'
require 'Vidispine/VSMetadataElements'
require 'yaml'
require 'trollop'

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
opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

$host = opts.host
$port = opts.port.to_i
$user = opts.username
$passwd=opts.password
$destination_storage = "VX-5"
$mdProjection = "ITN_V7"
$mappingfile = "field_mappings.yaml"

$projectTypeName = "Premiere"
$commissionerName = "Mustafa Khalili"
$workingGroupName = "Multimedia News"
$subscribingGroupIDs = "24"
$ownerID = "10"

$logger=Logger.new(STDERR)
$logger.formatter = CDSFormatter.new

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
    raise InvalidMetadataError, "#{$workingGroupName} is not a valid Commissioner"
end

dt = DateTime.now()
commissionNameTpl = "API test newswire commission for %b %Y"
commissionName = dt.strftime(commissionNameTpl)

projectNameTpl = "API test newswire project for %a %d %b"
projectName = dt.strftime(projectNameTpl)

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
if(ARGV.length<1)
    $logger.error("You need to specify a media file on the commandline")
    exit(2)
end
mediaFile = ARGV[0]
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
    puts "ERROR: copy not implemented at present"
    exit(4)
end
$logger.info("Done")

$logger.info("Looking up file reference")
#FIXME: might not work with subdirectories in the storage
attempts = 0
begin
    fileRef = storage.fileForPath(File.basename(mediaFile))
rescue VSNotFound=>e
    attempts += 1
    puts "WARNING: File #{mediaFile} not found after #{attempts} attempts."
    if(attempts>10)
        puts "Not present after 10 attempts, giving up."
        exit(5)
    end
    sleep(5)
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
    storage.debug = true
    puts "File #{mediaFile} is not already linked to an item."
    fileRef.debug = true
    import_job = fileRef.importToItem( { 'gnm_type' => 'Master',
                         'title' => File.basename(mediaFile),
                         'gnm_master_website_headline' => File.basename(mediaFile),
                         'gnm_asset_category' => 'ITN',
			 'gnm_master_language' => 'en',
			 'gnm_master_generic_source' => 'ITN',
			 'gnm_commission_title' => commissionName,
			 'gnm_project_headline' => projectName,
			 'gnm_commission_workinggroup' => workingGroupID,
			 'gnm_master_licensor' => 'Independent Television News',
			 'gnm_storage_rule_deletable' => 'storage_rule_deletable',
			 'gnm_master_generic_intendeduploadplatforms' => 'website'
			 },
                         tags: ['lowres'],
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
                                       client: 'Guardian Editorial',
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

if sidecarpath
    $logger.info("Found sidecar XML at #{sidecarpath}.  Attempting to import...")
    File.open(sidecarpath) do |f|
        item.importMetadata(f.read,projection: $mdProjection)
    end
    $logger.info("Done.")
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
