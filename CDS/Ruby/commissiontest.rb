#!/usr/bin/env ruby
$: << './lib'

require 'PLUTO/Entity'
require 'awesome_print'
require 'date'
require 'vidispine/VSAcl'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

comm=PLUTOCommission.new(opts.host,opts.port,opts.username,opts.password)
comm.debug=true

comm.populateByTitle('API test commission at 18:41 on 10/11/2014')
ap comm
p = comm.findProject(name: 'API test project at 18:41 on 10/11/2014')
ap p
exit(1)

#begin
#    comm.populate("KP-176")
#rescue VSNotFound=>e
#    puts e.to_s
#    exit(1)
#end

dt = DateTime.now

commissionName=dt.strftime("API test commission at %H:%M on %d/%m/%Y")
#raise StandardError,"Testing: #{commissionName}"
comm.create!(commissionName,
             commissionerUID: '923a262e-02cc-49f8-bd91-fd32455a1390',
             workingGroupUID: '6a60568e-7372-404e-9856-2b0022cb5ef2',
             client: 'Guardian Editorial',
             projectTypeUID: '4a450214-8398-4405-8650-147052c4393e',
             subscribingGroupIDs: '24',
             ownerID: '10'
             )
ap comm

projectName=dt.strftime("API test project at %H:%M on %d/%m/%Y")
comm.newProject(projectName)

comm.projects do |project|
    ap project
end
