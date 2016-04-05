#!/usr/bin/env ruby

#r2_map_tag_ids $Rev: 1140 $ $LastChangedDate: 2015-01-14 13:25:19 +0000 (Wed, 14 Jan 2015) $

#This CDS method maps from a set of R2 numeric tag IDs to their CAPI ids or vice-versa,
#using Composer's tags api.
#Arguments:
#  <input>tag1|tag2|{meta:tagfield}|.... - map these tags
#  <input_key>keyname - map tag values from this key only. If <input> is specified as well, then <input> takes precedence
#  <output_key>keyname - output mapping result to this datastore key
#  <output_names_key>keyname [OPTIONAL] - output "external" tag names to this key
#  <output_internal_names_key>keyname [OPTIONAL] - output "internal" tag names to this key
#  <output_delimiter>c [OPTIONAL] - used the given character c as the output delimiter. Defaults to |
#  <case_sensitive/> - when checking if the internal/external name actually matches, do the check case-sensitive
#  <invert/>  -  map from CAPI ids to numeric ids as opposed to vice-versa
#  <db_host>hostname
#  <db_user>username
#  <db_pass>password
#  <db_port>portnum [OPTIONAL]
#END DOC

require 'CDS/Datastore'
require 'net/http'
require 'json'
require 'cgi'
require 'awesome_print'
require 'pg'

$store = Datastore.new('r2_map_capi_tags')
$reject_types = [ /Newspaper/ ]
def should_reject(str)
	$reject_types.each do |t|
		return true if(t.match(str))
	end
	false
end

def lookup_by_capi(db,capi_name)
	db.exec("select r2_id,type,internalname,externalname from tags where capi_id='#{capi_name}'") do |res|
	#	ap res
		res.each do |r|
	#		ap r
			next if should_reject(r['type'])
			return r['r2_id'],r['internalname'],r['externalname']
		end #res.each
	end #result.each_row
	return nil	
end #lookup_by_capi

def lookup_by_r2(db,r2_id)

end #lookup_by_r2

def record_notfound(db,ids,video_id)

if(ids.length==0)
	return 0
end

ids.each do |id|
	db.exec("insert into missing_mappings (capi_id,video_id) values ('#{id}','#{video_id}')")
end

end

def check_args(arglist)

arglist.each do |arg|
	if(not ENV[arg])
		raise StandardError, "You need to specify <#{arg}> in the routefile"
	end #if(not ENV[arg])
end #arglist.each

end #def check_args

#START MAIN
begin
	check_args(['db_host','db_user','db_pass','output_key','asset_id'])
rescue Exception => e
	puts "-ERROR: #{e.message}"
	exit(1)
end

dbhost = $store.substitute_string(ENV['db_host'])
dbuser = $store.substitute_string(ENV['db_user'])
dbpasswd = $store.substitute_string(ENV['db_pass'])

dbport = 5432
if(ENV['db_port'])
	dbport = $store.substitute_string(ENV['db_host']).to_i
end

db = PGconn.connect(dbhost,dbport,nil,nil,'tagmapper',dbuser,dbpasswd)

assetid = $store.substitute_string(ENV['asset_id'])

input_data = ""
if(ENV['input_key'])
	input_data = $store.get('meta',ENV['input_key'])
end
if(ENV['input'])
	input_data = $store.substitute_string(ENV['input']) # $store.substitute_string(ENV['input'])
end

results = []
internal_names = []
external_names = []
notfound = []

input_data.split(/[\|,]/).each do |k|
	if(ENV['invert'])
		r,internal_name,external_name = lookup_by_capi(db,k)
		if(r==nil)
			puts "WARNING: Unable to find a mapping for #{k}"
			notfound << k
			next
		end
		results << r
		internal_names << internal_name
		external_names << external_name
	else
		results << lookup_by_r2(db,k)
	end #if(ENV['invert'])
end #input_data.split.each

if(results.length<1)
	puts "-ERROR: Not able to translate any tags!"
	exit(1)
end

record_notfound(db,notfound,assetid)

delim = "|"
delim = ENV['delimiter'] if(ENV['delimiter'])

outstring = ""
results.each do |r|
	outstring += "#{r}#{delim}"
end
outstring.chop!

$store.set('meta',ENV['output_key'],outstring)
puts "+SUCCESS: Set #{ENV['output_key']} to #{outstring}"

if(ENV['output_names_key'])
	outstring = ""
	external_names.each do |r|
		outstring += "#{r}#{delim}"
	end
	outstring.chop!

	$store.set('meta',ENV['output_names_key'],outstring)
	puts "+SUCCESS: Set #{ENV['output_names_key']} to #{outstring}"
end

if(ENV['output_internal_names_key'])
	outstring = ""
	internal_names.each do |r|
		outstring += "#{r}#{delim}"
	end
	outstring.chop!

	$store.set('meta',ENV['output_internal_names_key'],outstring)
	puts "+SUCCESS: Set #{ENV['output_internal_names_key']} to #{outstring}"
end

