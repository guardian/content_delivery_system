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
require 'digest'
require 'openssl'

# Method to sign requests with HMAC authorization

def sign_request(original_headers, method, path, content_type, content_body, shared_secret)
  new_headers = original_headers

  content_hasher = Digest::SHA2.new(384)
  content_hasher.update(content_body.encode("UTF-8"))

  date_time_now = Time.now.utc
  now_date = date_time_now.strftime("%a, %d %b %Y %H:%M:%S GMT")

  check_sum_string = content_hasher.hexdigest()

  new_headers["Digest"] = "SHA-384=" + check_sum_string
  new_headers["Content-Length"] = content_body.length.to_s
  new_headers["Content-Type"] = content_type
  new_headers["Date"] = now_date

  string_to_sign = path + "\n" + now_date + "\n" + content_type + "\n" + check_sum_string + "\n" + method

  puts "Debug: string to sign: " + string_to_sign

  result_data = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), shared_secret.encode("UTF-8"), string_to_sign.encode("UTF-8"))

  puts "Debug: final digest is : " + result_data

  new_headers["Authorization"] = "HMAC " + result_data

  return new_headers
end

# Method to get JSON from a given API URL

def get_json(input_url)
  uri = URI(input_url)

  Net::HTTP.start(uri.host, uri.port,
    :use_ssl => uri.scheme == 'https',
    :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
    request = Net::HTTP::Get.new uri
    new_headers = sign_request({}, 'GET', uri.path, 'application/json', '', $store.substitute_string(ENV['shared_secret']))
    request['Digest'] = new_headers['Digest']
    request['Content-Length'] = new_headers['Content-Length']
    request['Content-Type'] = new_headers['Content-Type']
    request['Date'] = new_headers['Date']
    request['Authorization'] = new_headers['Authorization']
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
