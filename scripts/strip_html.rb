#!/usr/bin/env ruby

#This script removes HTML
#Arguments:
# <stripme>blah - string to have HTML removed from
# <output_key> - key name to use for output

#END DOC

require 'CDS/Datastore'
require 'awesome_print'


#START MAIN
$store = Datastore.new('strip_html')

#
# <process-method name="strip_html">
#   <stripme>{meta:field_to_process}</stripme>
#   <output_key>html_free</output_key>
# </process-method>
#
# <output-method name="something">
#   <input_text>{meta:htmlfree}</input_text>
# </output-method>



stripme = $store.substitute_string(ENV['stripme'])


stripped_text = stripme


$store.set('meta',ENV['output_key'],stripped_text)
