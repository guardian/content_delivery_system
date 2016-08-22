#!/usr/bin/env ruby
$: << './lib'

require 'Vidispine/VSJob'
require 'nokogiri'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

jobdata="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?> \
<JobDocument xmlns=\"http://xml.vidispine.com/schema/vidispine\"> \
<jobId>KP-4845</jobId> \
<user>admin</user> \
<started>2014-08-15T17:28:28.770Z</started> \
<status>READY</status> \
<type>TRANSCODE</type> \
<priority>MEDIUM</priority> \
</JobDocument>"

job=VSJob.new(opts.host,opts.port,opts.username,opts.password)

print jobdata
job._parse(Nokogiri::XML(jobdata))

ap job