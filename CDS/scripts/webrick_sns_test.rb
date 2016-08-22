#!/usr/bin/env ruby

require 'webrick'
require 'awesome_print'
require 'json'
require 'logger'
require 'aws-sdk-resources'

class SNSServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(request,response)
    puts "Got HTTP post"
    ap request.body
    @logger = Logger.new(STDERR)
    
    begin
      data=JSON.parse(request.body)
      
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = "OK\r\n"
    rescue JSON::ParserError=>e
      @logger.error("Invalid JSON data passed: %p #{e.message}" % request.body)
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = "Invalid JSON\r\n"
    end
    
  end
  
end

#START MAIN
server = WEBrick::HTTPServer.new(:Port=>8000)

server.mount('/',SNSServlet)
trap 'INT' do
  puts "Caught interrupt, shutting down..."
  server.shutdown
end

trap 'TERM' do
  puts "Caught terminate, shutting down..."
  server.shutdown
end

sns = Aws::SNS::Client.new(region: 'eu-west-1')

server.start