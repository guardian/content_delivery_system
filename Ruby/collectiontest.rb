#!/usr/bin/env ruby
$: << './lib'
require 'vidispine/VSCollection'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end


c = VSCollection.new(opts.host,opts.port,opts.username,opts.password)
c.debug = true

c.create!('Andy API test 4',{ 'gnm_type'=>'Commission',
          'gnm_commission_title' => 'API test for PLUTO',
          'gnm_commission_commissioner' => '923a262e-02cc-49f8-bd91-fd32455a1390', #these are UUIDs that refer to MetadataElements
          'gnm_commission_workinggroup' => '6a60568e-7372-404e-9856-2b0022cb5ef2',
          'gnm_commission_client' => 'Guardian Editorial',
          'gnm_commission_projecttype' => '4a450214-8398-4405-8650-147052c4393e',
          'gnm_commission_subscribing_groups' => '24', #=>Multimedia News
          'gnm_commission_status' => 'New',
          'gnm_commission_owner' => '10'    #must refer to an entry in Portal's users table
          #'user' => 'Newswire Daemon'
          })
ap c

