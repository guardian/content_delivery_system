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

# Method to get JSON from a given API URL

def get_json(input_url)
  uri = URI(input_url)

  Net::HTTP.start(uri.host, uri.port,
    :use_ssl => uri.scheme == 'https',
    :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
    request = Net::HTTP::Get.new uri
    $method_response = http.request request
  end

  return JSON.parse($method_response.body)
end

#START MAIN
$store = Datastore.new('pluto_get_data')

# Get the project data

returned_json = get_json('https://' + $store.substitute_string(ENV['server']) + '/pluto-core/api/project/' + $store.substitute_string(ENV['project_id']))

# Get the commission data

commission_returned_json = get_json('https://' + $store.substitute_string(ENV['server']) + '/pluto-core/api/pluto/commission/' + returned_json["result"]["commissionId"].to_s)

# Get the working group data

group_returned_json = get_json('https://' + $store.substitute_string(ENV['server']) + '/pluto-core/api/pluto/workinggroup/' + returned_json["result"]["workingGroupId"].to_s)

$store.set('meta',{ "commission" => commission_returned_json["result"]["title"], "workinggroup" => group_returned_json["result"]["name"]})
