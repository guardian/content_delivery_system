#!/usr/bin/env ruby

require 'trollop'
require 'awesome_print'
require 'logger'
$: << './lib'
require 'PLUTO/Entity'

#START MAIN
$log = Logger.new(STDERR)
opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string, :default=>"admin"
  opt :password, "Vidispine password", :type=>:string
  opt :commission, "Commission to interrogate", :type=>:string, :default=>"VX-1896"
  opt :name,"Search for subprojects with this name", :type=>:string
end

if opts[:password]==nil
  $log.error("You must specify a Vidispine password")
  exit(1)
end

comm = PLUTOCommission.new(opts[:host],opts[:port],opts[:username],opts[:password])
comm.debug = false

comm.populate(opts[:commission])
ap comm.metadata

criteria={'gnm_type'=>'project'}
if opts[:name]!=nil
  criteria['title']=opts[:name]
end

comm.containerSearchWithin(criteria) do |result|
  ap result
end