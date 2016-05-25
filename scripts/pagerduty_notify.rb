#!/usr/bin/env ruby
$: << 'Ruby/lib'
#  This method is intended for use as a failure-method and will send an alert to the PagerDuty service (http://www.pagerduty.com)
#
#Arguments:
# <service_key> - The "integration key" from your PagerDuty service
# <event_type>{trigger|acknowledge|resolve} - which action to perform on PagerDuty
# <message>text - message to send to PD, which will be sent on in the form of SMS alerts etc. Substitutions supported and encouraged but the maximum length is 1024 chars (PagerDuty limit)
# <incident_key>blah [OPTIONAL] - set the "incident key" in PD.  Events with the same incident key will be considered dupes.  So, you can group errors by route by setting this to {routename} or similar
# <include_media_section/> [OPTIONAL] - dump the entire "media" section of the datastore into the extra_data part
# <include_all_metadata/> [OPTIONAL] - include every piece of metadata in the extra_data report. This might be quite large!
# <extra_data>key=value|key2={meta:moredata} [OPTIONAL] - arbitary key-value data to include in the incident report
# <client_url>http://blah [OPTIONAL] - set the Client URL field in PagerDuty

require 'net/http'
require 'json'
require 'CDS/Datastore'
require 'awesome_print'

class ArgumentMissing < StandardError
  #code
end

def check_arguments(arglist)
  arglist.each {|a|
    raise ArgumentMissing, a if(not ENV[a])
  }
end

PD_URI = URI('https://events.pagerduty.com/generic/2010-04-15/create_event.json')

#START MAIN
begin
  check_arguments(['service_key','event_type','message'])
rescue ArgumentMissing=>e
  puts("-ERROR: You need to specify <#{e.message}> in the route file.")
  exit(1)
end

retry_delay=10
if ENV['retry_delay']
  retry_delay=ENV['retry_delay'].to_i
end

retry_limit=5
if ENV['retry_limit']
  retry_limit=ENV['retry_limit'].to_i
end

$store = Datastore.new('pagerduty_notify')
output_data = {}
output_data['service_key'] = $store.substitute_string(ENV['service_key'])
output_data['event_type'] = $store.substitute_string(ENV['event_type'])
output_data['description'] = $store.substitute_string(ENV['message'])

#truncate message field if it's over length
if output_data['description'].length > 1024
  output_data['description'] = output_data['description'][0..1021] + "..."
end

if ENV['incident_key']
  output_data['incident_key'] = $store.substitute_string(ENV['incident_key'])
end

if ENV['client_url']
  output_data['client_url'] = $store.substitute_string(ENV['client_url'])
end

extra_data = {}
if ENV['extra_data']
  ENV['extra_data'].split(/\|/).each {|e|
    parts = $store.substitute_string(e).match(/^([^=]+)=(.*)$/)
    if parts
      extra_data[parts[1]] = parts[2]
    end
  }
end


output_data['details'] = extra_data

ap output_data if(ENV['debug'])
#JSON.dump(output_data)

h=Net::HTTP.new(PD_URI.host, PD_URI.port)
h.use_ssl=true

  request = Net::HTTP::Post.new(PD_URI)
  request.body = JSON.dump(output_data)
  
  n=0
  success=false
  begin
    n+=1
    response = h.request(request)
    response_data = nil
    begin
      response_data = JSON.parse(response.body)
    rescue StandardError=>e
      puts "-WARNING: Unable to parse server response: #{e.message}"
      puts "Response was: #{response.data}"
    end
    
    ap response_data if(ENV['debug'])
    code=response.code.to_i
    if code == 400
      if response_data
        puts("-ERROR: PagerDuty server rejected request: #{response_data['errors'].join(', ')} ")
      else
        puts("-ERROR: PagerDuty server rejected request: #{response.data}")
      end
      exit(1)
    end
    if code>=500 and code<600
      if response_data
        puts("-WARNING: Pagerduty reported internal server error: #{response_data['errors'].join(', ')}. Retrying in #{retry_delay}s.")
      else
        puts("-WARNING: Pagerduty reported internal server error: #{response.data}")
      end
      
    end
    
    if code==200 or code==201
      success=true
      break
    end
    
    sleep(retry_delay)
  end while(n<=retry_limit)
  
if success==false
  puts("-ERROR: Unable to communicate with PagerDuty after #{retry_limit} attempts.")
end

