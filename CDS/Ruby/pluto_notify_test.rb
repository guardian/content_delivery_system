#!/usr/bin/env ruby

require './lib/PLUTO/Notification'
require 'trollop'
require 'awesome_print'
require 'date'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end
time=DateTime.now
#ap time

#http://stackoverflow.com/questions/10056066/time-manipulation-in-ruby - adding to DateTime is in days, so this adds a fractional amount. Numerator is seconds, denominator is the number of seconds per day

#time+=Rational(60,86400)

#time.advance(:hours=>1)
#ap time

#exit(1)

creds=Credentials.new(server: opts.host,user: opts.username,password: opts.password)

msg=Notification.new('Beep!!...',
                     type: NT_PUBLISH,
                     severity: ST_ATTENTION,
                     object_type: 'Master',
                     object_id: 'KP-3451',
                     groups: ['Multimedia'],
                     expires: time+Rational(1,1440))

#users: ['andy_gallagher','alex_bourn'])
msg.debug=true
msg.send!(creds)