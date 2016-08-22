#!/usr/bin/env ruby


$: << './lib' #add the pwd's lib subdir to module search path, to test dev versions

require './lib/Vidispine/VSApi'
require './lib/Vidispine/VSItem'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

item=VSItem.new(opts.host,opts.port,opts.username,opts.password)
item.debug=1

begin
    item.populate(ARGV[0])
rescue VSNotFound=>e
    puts "Item '#{ARGV[0]}' could not be found"
    exit(1)
rescue VSException=>e
    puts e.message
    puts e.backtrace
    exit(2)
end

ap item.metadata

puts "----------------------------------------"
puts "Shapes held:"

item.shapes.each do |s|
    #specify a url scheme (e.g., file, http, omms, s3, etc.) to only return URIs that match that scheme
        s.eachFileURI(scheme: nil) do |u|
            # puts "\t#{s.id} (#{s.tag}): "+URI.unescape(u.path)+" on #{storage}\n";
            puts "\t#{s.id} (#{s.tag}): #{u.to_s}\n";
        end
end

originalshape = item.shapes.shapeForTag("original", scheme: "file", refresh: true)
puts "original: #{originalshape.id} (#{originalshape.tag}): #{originalshape.fileURI(scheme: "file").path}\n"
raise StandardError, "Not attempting to transcode"

have_transcoded=false

if(ARGV[1])
    begin
        puts "Looking for shape tag #{ARGV[1]}..."
        s = item.shapes.shapeForTag(ARGV[1],scheme: "file")
        #if path is empty then it must be transcoding, so wait for it.
        while(s.fileURI.path.length==0)
            sleep(5)
            puts "Waiting for shape to have a valid path..."
            s = item.shapes.shapeForTag(ARGV[1])
        end
        puts "Found #{s.id} at "+URI.unescape(s.fileURI.path)
    rescue VSNotFound=>e
        puts "Shape not found!!"
        if(have_transcoded)
            puts "Attempt at transcoding must have failed, so bailing"
            exit(3)
        end
        have_transcoded=true
        begin
            item.transcode!(ARGV[1])
            retry
        rescue VSNotFound=>e
            puts "ERROR: Shape tag #{ARGV[1]} does not exist."
            exit(4)
        end
        #item.shapes.each do |s|
        #    puts "\t#{s.id} (#{s.tag}): "+URI.unescape(s.fileURI.path)+"\n";
        #end
        #sleep(2)
    end
end
