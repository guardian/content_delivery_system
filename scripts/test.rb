#!/usr/bin/env ruby

require './lib/Datastore'
require './lib/Datastore-Episode5'

#TEST MAIN
ds=Datastore::Episode5.new('datastore test')

print "#{ds.export_meta}"
print "-----------------\n\n"
print "#{ds.export_inmeta}"
