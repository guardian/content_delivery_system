#!/usr/bin/env ruby

require 'aws-sdk'
require 'aws-sdk-resources'
require 'CDS/Datastore-Episode5'

#This CDS method pushes the route's metadata onto an Amazon SNS topic for further processing in the cloud.
#
#Arguments:
#  <aws_key>blah [OPTIONAL]- Amazon api key to access the queue (default is to use local/role configurations)
#  <secret>blah [OPTIONAL]- Secret key portion ("password") corresponding to <key> to access the queue
#  <region>blah [OPTIONAL] - AWS region to connect to. Default: eu-west-1
#  <topic>topicARN- ARN of the SNS topic to push to
#  <meta_format/> - use .meta format
#  <inmeta_format/> - use .inmeta format
#  <json_format/> - use JSON format
#END DOC

#START MAIN
$store = Datastore::Episode5.new('sns_send')

region = "eu-west-1"
region = $store.substitute_string(ENV['region']) if ENV['region']

if(ENV['aws_key'] and ENV['secret'])
  key = $store.substitute_string(ENV['aws_key'])
  secret = $store.substitute_string(ENV['secret'])
  snscli = Aws::SNS::Client.new(region: region, access_key_id: key, secret_access_key: secret)
else
  snscli = Aws::SNS::Client.new(region: region)
end

sns = Aws::SNS::Resource.new(client: snscli)

topic = sns.topic($store.substitute_string(ENV['topic']))

if(ENV['meta_format'])
  payload = $store.export_meta
elsif(ENV['inmeta_format'])
  payload = $store.export_inmeta
else
  raise RuntimeError, "Need to specify either meta or inmeta format"
end

puts "INFO: Sending message to #{topic}"
m = topic.publish(:message=>payload)
puts "+SUCCESS: Message sent with message id #{m.message_id}"