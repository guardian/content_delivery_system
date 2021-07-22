#!/usr/bin/env ruby

# This CDS method gets the commission and working group names from the pluto-core API for a given project id. and puts them in the meta data.
#
# Arguments:
#    <project_id>int - look up this project id.
#    <base_url>URL - talk to pluto-core at this URL
#    <shared_secret>blah - secret to use for encoding HMAC authorization header

#END DOC

require 'CDS/Datastore'
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
  result_data = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), shared_secret.encode("UTF-8"), string_to_sign.encode("UTF-8"))
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

# Check if we have input data

if $store.substitute_string(ENV['project_id']) == ''
  puts 'Error: No project_id set so exiting.'
  exit
end

if $store.substitute_string(ENV['server']) == ''
  puts 'Error: No server set so exiting.'
  exit
end

if $store.substitute_string(ENV['shared_secret']) == ''
  puts 'Error: No shared_secret set so exiting.'
  exit
end

# Get the project data

returned_json = get_json($store.substitute_string(ENV['base_url']) + '/api/project/' + $store.substitute_string(ENV['project_id']))

# Get the commission data

begin
  commission_returned_json = get_json($store.substitute_string(ENV['base_url']) + '/api/pluto/commission/' + returned_json["result"]["commissionId"].to_s)
  commisson_to_use = commission_returned_json["result"]["title"]
rescue
  commisson_to_use = ''
  puts 'Warning: the commission title could not be loaded.'
end

# Get the working group data

begin
  group_returned_json = get_json($store.substitute_string(ENV['base_url']) + '/api/pluto/workinggroup/' + returned_json["result"]["workingGroupId"].to_s)
  group_to_use = group_returned_json["result"]["name"]
rescue
  group_to_use = ''
  puts 'Warning: the working group name could not be loaded.'
end

$store.set('meta',{ "commission" => commisson_to_use, "workinggroup" => group_to_use})
