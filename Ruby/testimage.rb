#!/usr/bin/env ruby
require './lib/R2NewspaperIntegration/R2'

ni=R2NewspaperIntegration.new(host: 'cms.gucode.gnl')

unless(ARGV[0])
    puts "Tests r2 image upload. Usage: ./testimage.rb {filename}"
    exit 1;
end

unless(File.exists?(ARGV[0]))
    puts "ERROR: File #{ARGV[0]} does not exist to upload."
    exit 2;
end

print "140x84 trailpic for Brother of British woman freed in Iran is \'very happy\' \u2013\u00A0video"
exit(1)

id, url = ni.uploadImage(ARGV[0],
                         altText: "140x84 trailpic for Brother of British woman freed in Iran is \'very happy\' \u2013\u00A0video",
                         caption: "140x84 trailpic for Brother of British woman freed in Iran is \'very happy\' \u2013\u00A0video")

puts "Uploaded #{ARGV[0]} to cms.gucode.gnl with id #{id} and at URL\n#{url}"