#!/usr/bin/env ruby

version='$Rev: 959 $ $LastChangedDate: 2014-07-31 16:10:05 +0100 (Thu, 31 Jul 2014) $'
#This CDS method outputs a notification into the PLUTO notification area for the given user(s) and group(s)
#Arguments:
# <cantemo_host>cantemo.hostname.com - contact Cantemo on this server
# <cantemo_user>username - use this username (must be an admin for this to work)
# <https/> - use an https connection insead of http
# <cantemo_passwd>password - use this password
# <message>blah - text of the message to output
# <type>commission|project|master|publish - what the message refers to
# <severity>info|attention|urgent - which icon to show in the notification area
# <url>http://path/to/something [OPTIONAL] - URL that the user gets sent to when they click on the message. If a Vidispine object is given but the URL is not, then the message will link through to the vidispine object's page
# <object_id>KP-nnnn [OPTIONAL] - Vidispine ID of the object that this notification refers to
# <object_type>commission|master|project|vs/item [OPTIONAL] - What type of object is referred to by object_id.  Needed to build a URL to the object
# <users>user1|user2|{meta:user3} etc.... [OPTIONAL] - Send the message to these user(s)
# <groups>group1|group2| etc. [OPTIONAL] - Send the message to these user groups
# <expires_in>nn [OPTIONAL] - tell PLUTO that the message expires after this many MINUTES.
#END DOC

require 'CDS/Datastore'
require 'PLUTO/Notification'
require 'date'

#START MAIN
$store=Datastore.new('pluto_notify')

#Sort out arguments
unless(ENV['cantemo_host'] and ENV['cantemo_user'] and ENV['cantemo_passwd'])
    puts "-ERROR: You need to specify cantemo login details with <cantemo_host>, <cantemo_user> and <cantemo_passwd>"
    exit(1)
end
creds=Credentials.new(server: $store.substitute_string(ENV['cantemo_host']),
                      user: $store.substitute_string(ENV['cantemo_user']),
                      password: $store.substitute_string(ENV['cantemo_passwd']),
                      https: ENV.key?("https"))

unless(ENV['message'])
    puts "-ERROR: You need to specify a message with <message>"
    exit(1)
end

msg=$store.substitute_string(ENV['message'])
puts "INFO: Message is #{msg}"

unless(ENV['type'])
    puts "-ERROR: You need to specify a message type with <type>"
    exit(1)
end
unless(ENV['severity'])
    puts "-ERROR: You need to specify a message severity with <severity>"
    exit(1)
end

type=$store.substitute_string(ENV['type']).downcase
case type
    when 'commission'
        type=NT_COMMISSION
    when 'project'
        type=NT_PROJECT
    when 'master'
        type=NT_MASTER
    when 'publish'
        type=NT_PUBLISH
    else
        puts "-ERROR: <type> must be one of commission, project, master or publish"
        exit(1)
end

sev=$store.substitute_string(ENV['severity']).downcase
case sev
    when 'info'
        sev=ST_INFO
    when 'attention'
        sev=ST_ATTENTION
    when 'urgent'
        sev=ST_URGENT
    else
        puts "-ERROR: <severity> must be one of info, attention or urgent"
        exit(1)
end

users=Array.new
if(ENV['users'])
    users=$store.substitute_string(ENV['users']).split('|')
end

groups=Array.new
if(ENV['groups'])
    groups=$store.substitute_string(ENV['groups']).split('|')
end

ot=nil
if(ENV['object_type'])
    ot=$store.substitute_string(ENV['object_type'])
end
oid=nil
if(ENV['object_id'])
    oid=$store.substitute_string(ENV['object_id'])
    unless(oid=~/^[A-Za-z]{2}-\d+$/)
        puts "-WARNING: The value #{oid} passed as <object_id> does not appear to be a valid Vidispine object ID. Continuing with no object ID set"
        oid=nil
        ot=nil
    end
end

url=nil
if(ENV['url'])
	url=$store.substitute_string(ENV['url'])
end

expires=nil
begin
    if(ENV['expires'])
        exp_mins=$store.substitute_string(ENV['expires']).to_i
        nowtime=DataTime.now
        expires=nowtime+Rational(exp_mins,1440)
    end
rescue Exception=>e
    if(ENV['debug'])
        puts e.backtrace
    end
    puts "-WARNING: Expiry time #{ENV['expires']} is not a valid number of minutes: #{e.message}. Continuing with no expiry time set."
end

begin
    notification=Notification.new(msg,
                                  type: type,
                                  severity: sev,
                                  object_type: ot,
                                  object_id: oid,
				  url: url,
                                  users: users,
                                  groups: groups,
                                  expires: expires)

    notification.debug=ENV['debug']
    notification.send!(creds)

rescue Exception=>e
    if(ENV['debug'])
        puts e.backtrace
    end
    puts "-ERROR: Unable to send message to PLUTO: #{e.message}"
    exit(1)
end

puts "+SUCCESS: Message output to PLUTO"
exit(0)
