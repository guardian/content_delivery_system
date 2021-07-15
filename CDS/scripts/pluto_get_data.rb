#!/usr/bin/env ruby

# This CDS method gets the commission and working group names from the pluto-core API for a given project id. and puts them in the meta data.
#
# Arguments:
#    <project_id>int - look up this project id.
#    <server>hostname - talk to pluto-core on this computer
#END DOC

require 'CDS/Datastore'
require 'awesome_print'
require 'net/http'
require 'json'

#START MAIN
$store = Datastore.new('pluto_get_data')

# Get the project data

uri = URI('https://' + $store.substitute_string(ENV['server']) + '/pluto-core/api/project/' + $store.substitute_string(ENV['project_id']))

Net::HTTP.start(uri.host, uri.port,
  :use_ssl => uri.scheme == 'https',
  :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
  request = Net::HTTP::Get.new uri
  $response = http.request request
end

returned_json = JSON.parse($response.body)

# Get the commission data

commission_uri = URI('https://' + $store.substitute_string(ENV['server']) + '/pluto-core/api/pluto/commission/' + returned_json["result"]["commissionId"].to_s)

Net::HTTP.start(commission_uri.host, commission_uri.port,
  :use_ssl => commission_uri.scheme == 'https',
  :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
  request = Net::HTTP::Get.new commission_uri
  $commission_response = http.request request
end

commission_returned_json = JSON.parse($commission_response.body)

# Get the working group data

group_uri = URI('https://' + $store.substitute_string(ENV['server']) + '/pluto-core/api/pluto/workinggroup/' + returned_json["result"]["workingGroupId"].to_s)

Net::HTTP.start(group_uri.host, group_uri.port,
  :use_ssl => group_uri.scheme == 'https',
  :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
  request = Net::HTTP::Get.new group_uri
  $group_response = http.request request
end

group_returned_json = JSON.parse($group_response.body)

$store.set('meta',{ "commission" => commission_returned_json["result"]["title"], "workinggroup" => group_returned_json["result"]["name"]})
