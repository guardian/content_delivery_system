#!/usr/bin/env ruby

#This CDS method pushes the route's metadata onto an Amazon SQS queue for further processing in the cloud.
#
#Arguments:
#  <aws_key>blah - Amazon api key to access the queue - optional if you're in AWS
#  <secret>blah - Secret key portion ("password") corresponding to <key> to access the queue
#  <queue_url>https://queue/url - URL where we can find the queue to push onto.  HTTPS access is HIGHLY recommended
#  <meta_format/> - use .meta format
#  <inmeta_format/> - use .inmeta format
#  <json_format/> - use JSON format
#END DOC

require 'CDS/Datastore-Episode5'
require 'aws-sdk-resources'

#START MAIN
$store = Datastore::Episode5.new('sns_send')

region = "eu-west-1"
region = $store.substitute_string(ENV['region']) if ENV['region']

if(ENV['aws_key'] and ENV['secret'])
  key = $store.substitute_string(ENV['aws_key'])
  secret = $store.substitute_string(ENV['secret'])
  sqscli = Aws::SQS::Client.new(region: region, access_key_id: key, secret_access_key: secret)
else
  sqscli = Aws::SQS::Client.new(region: region)
end

if not ENV['queue_url']
  raise RuntimeError, "you need to pass a queue to send the message to, in <queue_url>"
end

resource = Aws::SQS::Resource.new(client: sqscli)
queue = resource.queue(ENV['queue_url'])

if(ENV['meta_format'])
  payload = $store.export_meta
elsif(ENV['inmeta_format'])
  payload = $store.export_inmeta
else
  raise RuntimeError, "Need to specify either meta or inmeta format"
end

if(ENV['debug'])
  puts "DEBUG: data to send follows:"
  puts payload
end

puts "INFO: Sending message to #{queue.url}"
m = queue.send_message({
                      message_body: payload
                      })
puts "+SUCCESS: Message sent with message id #{m.message_id}"