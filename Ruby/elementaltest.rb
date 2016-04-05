#!/usr/bin/env ruby
$:.unshift(File.dirname(__FILE__)+'/lib')
require 'Elemental/Job'
require 'awesome_print'
#user and passwd actually aren't used
#api = ElementalAPI.new("10.235.51.110", user: ***REMOVED***, passwd: ***REMOVED***)
api = ElementalAPI.new("10.235.51.110", login: "***REMOVED***", key: "***REMOVED***")
ap api

testfile = '/srv/Multimedia2/DAM/Media Libraries/Guardian UK Rushes/060_0815_01.mxf'
profilename = 'Output_GNM_h264 mp4_fullset'

begin
    jobinfo = api.submit(testfile,profileid: profilename)
rescue ElementalException=>e
    puts e.message
    exit(1)
end

begin
    sleep(10)
    
    puts "Checking status..."
    jobinfo.refresh_status!
    ap jobinfo.status
rescue ElementalException=>e
    puts e.message
    #puts e.backtrace
    exit(1)
end while(not jobinfo.complete?)

jobinfo.dump
puts "Successfully completed"

exit(0)

























jobid = 157
puts "Getting information for job #{jobid}"
job = api.jobstatus(jobid)
begin
    job.raise_on_error
    job.dump
    
    if(job.cancelled?)
        puts "\n\nJob was cancelled"
    elsif(job.complete?)
        puts "\n\nJob successfully completed"
    end
    
    puts "\n\n\nJob did not error"
rescue ElementalException=>e
    puts e.message
end