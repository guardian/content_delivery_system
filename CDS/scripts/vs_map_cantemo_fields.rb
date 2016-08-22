#!/usr/bin/env ruby

#This method connects to Vidispine and translates the names of keys in the datastore from
#Cantemo Portal's default portal_mf{number} format to the display name as they are
#shown in Cantemo
#
#Arguments:
# <vidispine_host>hostname - [OPTIONAL] - talk to Vidispine on this server. Defaults to 'localhost'
# <vidispine_port>nnn - [OPTIONAL] - talk to Vidispine on this TCP port. Defaults to 8080
# <vidispine_user>username - [OPTIONAL] - talk to Vidispine on this server. Defaults to 'admin'
# <vidispine_password>password - [OPTIONAL] - talk to Vidispine on this server.
# <debug/> - [OPTIONAL] - ouput loads of debugging info
#END DOC

require 'CDS/Datastore'
require 'Vidispine/VSFieldCache'

def get_options(opts,item)
	if(ENV[item])
		keyname=item.gsub('vidispine_','')
		opts[keyname]=$store.substitute_string(ENV[item])
	end
end

#START MAIN
$store=CDS::Datastore.new('vs_map_cantemo_fields')

opts={"host"=>"localhost",
	"port"=>8080,
	"user"=>"admin",
	"password"=>"" }
['vidispine_host','vidispine_port','vidispine_user','vidispine_password'].each { |item|
	opts=get_options(opts,item)
}

fc=VSFieldCache.new(host=opts['host'],port=opts['port'],user=opts['user'],passwd=opts['password'])
fc.debug(ENV['debug'])

fc.refresh

md=$store.get_meta_hashref

md.each { |key,value|
	if(key.match('^portal_'))
		begin
			field=fc.lookupByVSName(key)
			$store.set('meta',field["portal_name"],value)
		rescue VSException=>e
			puts "-WARNING: Unable to map '#{key}': #{message}"
		rescue Exception=>e
			puts "-ERROR: #{e.message}"
			if(ENV['debug'])
				puts e.backtrace
				exit 1
			end
			
		end #begin
	end #if(key.match())
}

