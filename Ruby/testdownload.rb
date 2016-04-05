#!/usr/bin/env ruby

$: << './lib'
require 'Vidispine/VSItem'
require 'Vidispine/VSShape'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

item = VSItem.new(opts.host,opts.port,opts.username,opts.password)
item.debug=true
puts "Loading item #{ARGV[0]}"
item.populate(ARGV[0])

shape = item.shapes.shapeForTag('original')
shape.debug=true

outfile = ARGV[0]
File.open(outfile,"wb") do |f|
  shape.fileData do |data|
    #puts "got data #{data}"
    f.write(data)
  end
end

puts "Written to #{outfile}"