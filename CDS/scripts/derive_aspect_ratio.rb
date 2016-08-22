#!/usr/bin/env ruby

#This script attempts to derive the aspect ratio of a piece of content based on
#other metadata.  It is output as a string in the form x/y, where the / seperator can be over-ridden
#Arguments:
# <width_key>blah [OPTIONAL] - use this key for the width (defaults to media:width)
# <height_key>blah [OPTIONAL] - use this key for the height (defaults to media:height)
# <output_key>blah [OPTIONAL] - use this key to output the result (defaults to meta:aspect_ratio)
# <separator>c [OPTIONAL] - use this character instead of / as a seperator

#END DOC

require 'CDS/Datastore'
require 'awesome_print'

class InvalidKey < StandardError
end

#if this works, fold it into main Datastore
class CDSPath
    attr_accessor :section
    attr_accessor :subsection
    attr_accessor :key
    
    def initialize(string)
        @section = "meta"
        @subsection = nil
        @key = nil
        
        #puts "CDSPath::initialize: got " + string
        if(m = /^([^:]+):([^:]+):(.*)$/.match(string))
            #puts "threeway path: " + m.to_s
            @section=m[1]
            @subsection=m[2]
            @key=m[3]
        elsif(m = /^([^:]+):(.*)$/.match(string))
        #puts "twoway path: " + m.to_s
            @section=m[1]
            @key=m[2]
        else
        #puts "key only: " + string
            @key=string
        end #if(regex)
        
    end # def initialize
    
    def to_s(absolute: false)
        str = ""
        if(@section)
            str += @section + ":"
        elsif(@absolute)
            str += "meta:"
        end
        if(@subsection)
            str += @subsection + ":"
        end
        if(@key)
            str += @key
        else
            raise InvalidKey, "No key section to path"
        end
        return str
    end
    
end #class CDSPath

#START MAIN
$store = Datastore.new('derive_aspect_ratio')

#first set up routefile arguments
begin
    width_ref = CDSPath.new($store.substitute_string(ENV['width_key']))
    height_ref = CDSPath.new($store.substitute_string(ENV['height_key']))
    output_ref = CDSPath.new($store.substitute_string(ENV['output_key']))
    sep = $store.substitute_string(ENV['separator'])
rescue Exception=>e
    print e.backtrace
    print "-ERROR: Unable to set up arguments: "+e.to_s
    exit(1)
end

#ap width_ref

puts width_ref.instance_of?(CDSPath)

puts "debug: got following keys:"
puts "\twidth_ref: " + width_ref.to_s
puts "\theight_ref: " + height_ref.to_s
puts "\toutput_key: " + output_ref.to_s

begin
    if(width_ref.subsection)
        width = $store.get(width_ref.section,width_ref.subsection,width_ref.key)
    else
        width = $store.get(width_ref.section,width_ref.key)
    end
    if(height_ref.subsection)
        height = $store.get(height_ref.section,height_ref.subsection,height_ref.key)
    else
        height = $store.get(height_ref.section,height_ref.key)
    end
rescue Exception=>e
    ap e.backtrace
    puts "-ERROR: Unable to collect values: "+e.to_s
    exit(1)
end

original_ratio = "#{width}/#{height}"
puts "INFO: original aspect ratio from #{width_ref.to_s} and #{height_ref.to_s} is #{original_ratio}"

#we convert the string into a rational, which automatically reduces to lowest terms.
aspect = original_ratio.to_r

puts "INFO: got aspect ratio #{aspect}"

if(sep)
    aspect = aspect.gsub(%r{'/'},sep)
end
puts "INFO: got output #{aspect}"

if(output_ref.subsection)
    $store.set(output_ref.section,output_ref.subsection,output_ref.key,aspect)
else
    $store.set(output_ref.section,output_ref.key,aspect)
end

puts "+SUCCESS: Output derived aspect ratio information to #{output_ref}"
