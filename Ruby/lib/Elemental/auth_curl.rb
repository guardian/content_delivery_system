#!/usr/bin/ruby
## ---------------------------------------------------------------------------
## Elemental Technologies Inc. Company Confidential Strictly Private
##
## ---------------------------------------------------------------------------
##                           COPYRIGHT NOTICE 
## ---------------------------------------------------------------------------
## Copyright 2011 (c) Elemental Technologies Inc.
##
## Elemental Technologies owns the sole copyright to this software. Under
## international copyright laws you (1) may not make a copy of this software
## except for the purposes of maintaining a single archive copy, (2) may not
## derive works herefrom, (3) may not distribute this work to others. These
## rights are provided for information clarification, other restrictions of
## rights may apply as well.
##
## This is an unpublished work.
## ---------------------------------------------------------------------------
##                              WARRANTY 
## ---------------------------------------------------------------------------
## Elemental Technologies Inc. MAKES NO WARRANTY OF ANY KIND WITH REGARD TO THE
## USE OF THIS SOFTWARE, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
## THE IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR
## PURPOSE.
## ---------------------------------------------------------------------------
##****************************************************************************
##*************** START OF PUBLIC TYPE AND SYMBOL DEFINITIONS ****************
##****************************************************************************

require 'digest/md5'
require 'uri'

def help
  puts "Usage:"
  puts "auth_curl [OPTIONS]"
  puts
  puts "OPTIONS:"
  puts "  all regular curl options"
  puts "  --login <login>: User login"
  puts "  --api-key <key>: User API Key"
  exit(0)
end

login = nil
key = nil
curl_args = []

#Parse command line arguments
skip_next=false
ARGV.each_with_index do |arg, idx|

  if skip_next
    skip_next=false
    next
  end

  if arg == "--login"
    login=ARGV[idx+1]
    skip_next=true
    next
  elsif arg == "--api-key"
    key=ARGV[idx+1]
    skip_next=true
    next
  end

  case arg
  when "--help", "-h", "-?"
    help
  else
    curl_args << arg
  end
end

ARGV.clear

if login.nil?
  puts 'Login is missing'
  help
end

if key.nil?
  puts 'API key is missing'
  help
end

begin
  url = URI::parse(URI.escape(curl_args.last))
  unless url.path
    puts "There was an issue parsing the path"
    exit(0)
  end
rescue Exception => e
  puts "There was an issue parsing the path"
  exit(0)
end

expires = Time.now.utc.to_i + 30
path_without_api_version = url.path.sub(/\/api(?:\/[^\/]*\d+(?:\.\d+)*[^\/]*)?/i, '')

hashed_key = Digest::MD5.hexdigest("#{key}#{Digest::MD5.hexdigest("#{path_without_api_version}#{login}#{key}#{expires}")}")

# format curl_args
curl_args = curl_args.map do |a|
  if a =~ /^(-\w)(.+)/
    "#{$1}'#{$2}'"
  elsif a =~ /^-\w/
    a
  else
    "'#{a}'"
  end
end

puts `curl -H "X-Auth-User: #{login}" -H "X-Auth-Expires: #{expires}" -H "X-Auth-Key: #{hashed_key}" #{curl_args.join(' ')}`
# uncomment to display command
#puts "curl -H 'X-Auth-User: #{login}' -H 'X-Auth-Expires: #{expires}' -H 'X-Auth-Key: #{hashed_key}' #{curl_args.join(' ')}"
