#!/usr/bin/env ruby
#
# This method updates the next-generation Pluto Deliverables app with the current status of a job
#
# Arguments:
#  <deliverable_asset>  - ID in pluto-deliverables of the asset to target
#  <project_id>         - ID in pluto-core of the project that it belongs to
#  <platform>           - name of the platform we are updating
#  <completed/>         - if set, signal completion
#  <failed/>            - if set, signal failure
#  <message>            - log message to send
# <uploaded_url> [optional] - set if the upload has succeeded and you want to tell deliverables about the location it's arrived at
#  <sender>             - name of the sender to set. "CDS" unless otherwise specified.
#  <baseurl>            - base URL for pluto-deliverables
#  <user>
#  <passwd>
require 'CDS/Datastore'
require 'net/http'
require 'json'

def get_arg(argname)
  unless ENV[argname]
    puts "-ERROR You must set #{argname} in the routefile"
    exit(1)
  end
  $store.substitute_string(ENV[argname])
end

#START MAIN
$store=Datastore.new('vidispine_notify')

#set up args
$debug=ENV['debug']
asset_id = get_arg("deliverable_asset").to_i
project_id = get_arg("project_id").to_i
platform = get_arg("platform")
message = get_arg("message")
baseurl = get_arg("baseurl")
user = get_arg("user")
passwd = get_arg("passwd")

if ENV["sender"]
  sender = $store.substitute_string(ENV["sender"])
else
  sender = "CDS"
end
if ENV["completed"]
  completed = true
else
  completed = false
end
if ENV["failed"]
  failed = true
else
  failed = false
end

uploaded_url = nil
if ENV["uploaded_url"]
  uploaded_url = $store.substitute_string(ENV["uploaded_url"])
end

uri = URI(baseurl + "/api/bundle/#{project_id}/asset/#{asset_id}/#{platform}/logupdate")
payload = {
    :sender => sender,
    :completed => completed,
    :failed => failed,
    :log => message
}
if uploaded_url
  payload[:uploadedUrl] = uploaded_url
end

json_body = JSON.generate(payload)

puts "DEBUG: uri is #{uri}" if $debug
puts "DEBUG: request is #{json_body}" if $debug

loop do
  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https', :debug_output=>$stdout, :verify_mode=>OpenSSL::SSL::VERIFY_NONE) do |http|
    request = Net::HTTP::Post.new(uri, 'Content-Type'=>'application/json')
    request.basic_auth(user, passwd)
    request.body = json_body
    http.request(request)
  end

  case response.code.to_i
  when 200
    puts "+SUCCESS message sent to pluto-deliverables"
    exit(0)
  when 400
    puts "-FATAL: we had invalid data to send to pluto-deliverables. Request body was #{json_body}, server said #{response.body}"
    exit(3)
  when 404
    puts "-FATAL: record was not found in pluto-deliverables. Id was #{asset_id}, platform was #{platform}, server said #{response.body}"
    exit(3)
  when 500
    puts "-WARNING: server error sending to pluto-deliverables, retrying in 3s. Server said #{response.body}"
    sleep(3)
  when 502, 503, 504
    puts "-WARNING: Timed out sending to pluto-deliverables (#{response.code}), retrying in 3s..."
    sleep(3)
  else
    puts "-FATAL: unexpected return code #{response.code} from pluto-deliverables. Server said #{response.body}"
    exit(3)
  end
end


