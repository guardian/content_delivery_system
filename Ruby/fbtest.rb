#!/usr/bin/env ruby

$: << 'lib/'
require 'Facebook/fbvideo'
require 'trollop'

#START MAIN
opts = Trollop.options do
  opt :filepath, "Path of file to upload", :type=>:string
  opt :userid, "Facebook user ID", :type=>:integer, :default=>10153587518839328
  opt :token, "Facebook access token", :type=>:string, :default=>"CAACEdEose0cBABwLZAUpyOsja4kZCzIELbSYllcfhzpqm4AJdv0tIUYb6yChNrU2tyn5rEeZBelBEussuok2Du6EWb95NLSTFOTMUQdH2WeSQeJt7py4DLhYrAXN8UvRxQVsIeYSOWmes289m8MwAZCpLKZBrfZBDe4AwvjeHz104LOP9hccsI6puACiZBD2cUZCaVvhxqEpp4RbZBZA5Cm1nwu5mP1AWZCJjFatbvmGKyZBgQZDZD"
end

vid = FacebookVideo.new() #opts.filepath, opts.token, FBUser.new(user_id: opts.userid))
vid.filepath = opts.filepath
vid.token = opts.token
vid.user = FBUser.new(user_id: opts.userid)
vid.title="Test video"
vid.description="Rather short description field"
vid.category="NEWS"
vid.embeddable=false

vid.upload!
