#!/usr/bin/env ruby

#This CDS method will create a commission.

#Arguments:
#  <commission_name>blah - create a commission with this name. Ruby date parameters are supported (see http://ruby-doc.org/stdlib-2.0.0/libdoc/date/rdoc/Date.html#method-i-strftime)
#  <project_type>blah - set the project type of the commission to this type (Premiere, Cubase, etc.).
#  <commissioner_name>blah - set the commissioner's name to this.
#  <working_group>blah - set the working group to this.
#  <subscribing_group_ids>n|n|n|.... - set the subscribing groups to these numbers.  Only accepts numeric IDs right now.
#  <owner_id>n - set the owner to this numeric user ID
#  <gnm_category>name - Set the "category" field in PLUTO to this value. Essential for proper media management
#  <extra_metadata>field_name=value|another_field_name=another_value|... [OPTIONAL] - set the given fields on a commission. For valid field names, refer to the Metadata Editor in Cantemo Portal  
#  <vidispine_host>hostname [OPTIONAL] - host to communicate with (defaults to localhost)
#  <vidispine_port>portnum [OPTIONAL] - port to communicatewith Vidispine on (defaults to 8080)
#  <vidispine_user>username- username for Vidispine
#  <vidispine_password>pass - password for Vidispine
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
        n=0
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
         	 n+=1
             if n>$retry_times
             	print "-ERROR: Unable to communicate with vidispine after #{$retry_times} attempts, giving up."
             	exit(1)
             end
             print e.backtrace
             print "-ERROR: #{e.message}.  Sleeping for #{$retry_delay} before retrying."
             sleep($retry_delay)
             retry
        end
        puts "INFO: Created #{comm.id}"
    end
    return comm
end #def commissionFindOrCreate


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
$store=Datastore.new('pluto_create_commission')
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

dt = DateTime.now()
commissionNameTpl = $store.substitute_string(ENV['commission_name'])
commissionName = dt.strftime(commissionNameTpl)



$retry_times = "6"
if ENV['retry_times']
  $retry_times = $store.substitute_string(ENV['retry_times'])
end

$retry_delay = "10"
if ENV['retry_delay']
  $retry_delay = $store.substitute_string(ENV['retry_delay'])
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
puts "\tExtra Meta: #{$extraMeta}"

#once asset is imported, should update the metadata with project & commission names, etc.
#exit(7)


#puts "#{commissionName} #{projectName}"


$retry_times = Integer($retry_times) 
$retry_delay = Integer($retry_delay)

$retry_delay = $retry_delay * 60

$changeme = 0

commissionRef = commissionFindOrCreate(commissionName,
									commissionerUID: commissionerID,
									workingGroupUID: workingGroupID,
									client: $commissionClientName,
									projectTypeUID: projectTypeID,
									subscribingGroupIDs: '24',
									ownerID: '10',
									extraMeta: $extraMeta
									)
     	


