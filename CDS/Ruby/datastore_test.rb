#!/usr/bin/env ruby

require './lib/CDS/Datastore'
require 'pp'
require 'date'

store=Datastore.new('datastore_test')

datahash=store.get_template_data

pp datahash

dt=DateTime.now

store.set('meta','testkey','first value')
testval=store.get('meta','testkey')
puts "Got value #{testval} for meta:testkey"

store.set('meta','testkey','second value')
testval=store.get('meta','testkey')
puts "Got value #{testval} for meta:testkey"

store.set('meta','testkey','third value')
testval=store.get('meta','testkey')
puts "Got value #{testval} for meta:testkey"

exit 1

testval=store.get('meta','anothertestkey')
puts "Got value #{testval} for meta:anothertestkey"

testval=store.get('media','duration')
puts "Got value #{testval} for movie:duration"

testval=store.get('media','escaped_path')
puts "Got value #{testval} for movie:escaped_path"

store.set('meta','now',dt.rfc2822())
puts "Set value for 'Now'"

testval=store.get('meta','now')
puts "Got value #{testval} for meta:now"

subbed=store.substitute_string("Testkey is {meta:testkey}, anothertestkey is {meta:anothertestkey} on {day}/{month}/{year} at {hour}:{min}:{sec}")
puts "Got subbed value #{subbed}"