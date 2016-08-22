#!/usr/bin/env ruby

require './lib/PLUTO/Tags'

tf=TagFeed.new('http://gnmapps:7777/plrcs/rcs_suppliers.xml_supplier_list',feedtype: TF_RCS_ROLE, encoding: "ISO-8859-1")

n=0
fragsize=100

tf.download!(fragsize) do |frag|
    puts frag
    puts "----------------"
    n+=1
end

puts "Got #{n} fragments of #{fragsize} items"