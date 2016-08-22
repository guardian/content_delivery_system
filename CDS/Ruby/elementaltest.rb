#!/usr/bin/env ruby
$:.unshift(File.dirname(__FILE__)+'/lib')
require 'Elemental/Job'
require 'awesome_print'
require 'trollop'

options = Trollop::options do
	opt :host, "Host to contact Elemental on", :type=>:string
	opt :username, "Username to use on Elemental", :type=>:string, :default=>"elemental"
	opt :password, "Password to use on Elemental", :type=>:string
end

if not options.host
	print "You need to specify an Elemental transcoder by using the --host option"
	exit(1)
end

if not options.password
	print "You need to specify a password for the user #{options.username} on the Elemental transcoder at #{host} by using the --password option"
	exit(1)
end

api = ElementalAPI.new(options.host, user: options.username, passwd: options.password, overlay_image: "/srv/Multimedia2/Media Production/Assets/Branding/Bugs/Bug_Nov15_White.png")

ap api

testfile = '/srv/Multimedia2/DaveTest3.mxf'
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


#'/srv/Multimedia2/Media Production/Assets/Branding/Bugs/Bug_Nov15_White.png'






















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