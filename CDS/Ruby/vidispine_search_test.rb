#!/usr/bin/env ruby

$: << './lib'

require './lib/Vidispine/VSSearch'
require 'awesome_print'
require 'trollop'

opts = Trollop::options do
  opt :host, "Vidispine hostname", :type=>:string, :default=>"localhost"
  opt :port, "Vidispine port", :type=>:integer, :default=>8080
  opt :username, "Vidispine username", :type=>:string
  opt :password, "Vidispine password", :type=>:string
end

search=VSSearch.new(opts.host,opts.port,opts.username,opts.password)
search.debug=false

search.addCriterion({ 'gnm_type' => 'commission' }, invert: false)
#search.addCriterion({ 'title' => 'johan*' }, invert: false)

search.searchType("collection")

#should return VSItems
n=0
search.results do |res|
    n+=1
    puts "Got commission #{n}:"
    puts "\tID: #{res.id} Name: #{res.name}"
    if(res.is_a?(VSCollection))
        res.each do |item|
            puts "\t\tContained item ID: #{item.id}"
            begin
                item.refresh
                ap item.getMetadata
            rescue VSNotFound=>e
                puts e.to_s
            end
        end #res.each
    end #if
end

puts "Yielded a total of #{n} items out of #{search.hits} total hits"
