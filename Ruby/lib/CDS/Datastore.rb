require 'sqlite3'
require 'date'

class Datastore
attr_accessor :valid
attr_accessor :debug
CONFIG_DEFINITIONS_DIR = "/etc/cds_backend/conf.d/"

def initialize(modulename)

@modulename=modulename
@version="v1.1"
@debug=false

@defs = {}
#self.message("Datastore::initialize - loading definitions")
self.loadDefs(CONFIG_DEFINITIONS_DIR)

db=ENV['cf_datastore_location']
unless db
	print "CDS::Datastore->new - ERROR - cf_datastore_location is not set. Expect problems.\n"
	@valid=0
	return
end


@dbh=SQLite3::Database.new(db)
@valid=1

#if an error occurs, we raise SQLite3::Exception.
#don't catch it here, pass it back up the chain.
end #initialize

def isValid #for compatibility with Perl version
return @valid
end

def warn(string)
puts $stderr,"WARNING: #{string}"	#fixme: do this better!
end #warn

def error(string)
raise StandardError,string

end #error

def message(string)
puts string

end #message

def debugmsg(string)
if @debug
	puts $stderr,"DEBUG: #{string}"
end
end #def debug

def loadDefs(dir)
  Dir.glob("#{dir}/**/*") do |filename|
begin
    File.open(filename).each do |line|
	next if(/^#/.match(line))
	parts = /^\s*([^=]+)\s*=\s*(.*)$/.match(line.chomp())
	if(parts)
	  @defs[parts[1].strip()] = parts[2]
	else
	  self.warn("Unable to parse line in #{filename}: #{line}")
	end if(parts)
    end #File.open
rescue StandardError=>e
    self.debugmsg(e.backtrace)
    self.warn("Datastore::loadDefs - An error occurred processing file #{filename}: #{e.message}")
end #exception handling
  end #Dir.glob 
end #loadDefs

def get_meta_hashref

rtn=Hash.new
rtn['meta']=Hash.new

st=@dbh.prepare("SELECT key,value,type,ctime FROM meta left join sources on source_id=sources.id order by ctime desc,meta.id desc,key")
result=st.execute
result.each do |row|
	#p row
	unless rtn['meta'][row[0]]
		rtn['meta'][row[0]]=row[1]
	end
end #st.execute
return rtn

end #get_meta_hashref

def get_movie_hashref
rtn=Hash.new
st=@dbh.prepare("select key,value,type,ctime from media left join sources on source_id=sources.id order by ctime desc,media.id desc,key")
result=st.execute
result.each do |row|
	unless rtn[row[0]]
		rtn[row[0]]=row[1]
	end
end #result.each
return rtn

end #get_movie_hashref

def get_tracks_hashref
rtn=Hash.new

ntrack=0
begin #open a loop here
	rows = 0
	record=Hash.new
	st=@dbh.prepare("SELECT key,value,type,ctime FROM tracks left join sources on source_id=sources.id where track_index=? order by ctime desc,tracks.id desc,key")
	st.bind_param 1,ntrack
	result=st.execute
	
#	unless result.any?
#		break
#	end
	
	result.each do |row|
		unless record[row[0]]
			record[row[0]]=row[1]
		end
		rows+=1
	end #result.each
	
	#p record
	if not record['index']
		record['index']=ntrack
	end
	if(record['type'] and record['type']!="")
		rtn[record['type']]=record
	else
		self.warn("get_tracks_hashref - track #{ntrack} had no type field.")
	end #record['type']
	
	ntrack+=1
end while rows>0
ntrack-=1
self.warn("get_tracks_hashref - returned #{ntrack} results")

return rtn

end #get_tracks_hashref


def get_template_data(inhibit_translate=false,array_keys=nil)
rtn=Hash.new

metasection=self.get_meta_hashref
#p metasection

rtn['tracks']=self.get_tracks_hashref

if array_keys
	array_keys.each do |key|
		newkey=key+"_list"
		metasection['meta'][newkey]=metasection['meta'][key].split(%r{/[,\|]/})
	end #array_keys.each
end

#this code is verbatim from the Perl version, where Template Toolkit
#chokes on spaces or hyphens.
#Included here for compatibility
unless inhibit_translate
	metasection.each do |key,value|
		newkey=key
		newkey=key.tr(' ','_')
		newkey.tr!('-','_')
			
		unless key==newkey
			metasection['meta'][newkey]=metasection['meta'][key]
			metasection['meta'].delete(key)
		end
	end #metasection.each
end #inhibit_translate

rtn['meta']=metasection['meta']
rtn['movie']=self.get_movie_hashref

#now for 'special exceptions' e.g. filenames etc. that are in the media table
['filename','path','escaped_path'].each do |key|
	if rtn['movie'][key]
		rtn[key]=rtn['movie'][key]
	end
end

return rtn
end #get_template_data

def getSource(type,filename="",filepath="")

#look up to see if we're in the db already
begin
	st=@dbh.prepare("SELECT id FROM sources WHERE type='?' and provider_method='?' and filename='?'")
	#st.bind_params(type,@modulename,filename)
	@dbh.results_as_hash=true
	result=st.execute
	
	result.each do |row|
		p row
		if row[0]
			return row[0]
		end
	end

rescue SQLite3::Exception=>e
	self.warn(e.message)
	return nil
	
end

dt=DateTime.now

#if not, then we need to add ourselves...
@dbh.execute("INSERT INTO sources (type,provider_method,ctime,filename,filepath) values (?,?,?,?,?)",
	type,@modulename,dt.to_time.to_i,filename,filepath)
return @dbh.last_insert_row_id

end #def getSource

#gets the id number for the given track name
def getTrackId(sourceid,tracktype)
begin
	st = @dbh.prepare("SELECT track_index,value from tracks where key='type' order by track_index")
	@dbh.results_as_hash = true

	result=st.execute
	max_track_index=0
	result.each do |row|
		if(row['value']==tracktype)
			return row['track_index']
		end
		max_track_index=row['track_index'].to_i+1
	end

	#if we get here then a track doesn't exist yet.
	puts "INFO: Creating new track record at index #{max_track_index} with type #{tracktype}"
	
	@dbh.execute("INSERT INTO tracks (source_id,track_index,key,value) VALUES (?,?,?,?)",
		sourceid,max_track_index,'type',tracktype)
	return max_track_index

rescue SQLite3::BusyException=>e
	puts "-WARNING: CDS::Datastore - #{e.message}"
	sleep(5)
	retry
rescue SQLite3::CantOpenException=>e
	puts "-WARNING: CDS::Datastore - #{e.message}"
	sleep(5)
	retry
rescue SQLite3::Exception=>e
	self.warn(e.message)
	return nil
end #exception block
end

def internalSet(sourceid,type,*args)

unless sourceid and sourceid.is_a? Numeric
	raise InvalidSource,"An invalid source ID was sent to internalSet"
end

if type=='movie'
	type='media'
end

begin #exception handling
@dbh.transaction do |db|		
	case type
	when 'meta'
		extra_fields=""
	when 'media'
		extra_fields=""
	when 'track'
		track=args.shift
		trackIndex=self.getTrackId(sourceid,track)
		
		extra_fields="track_index,"
		extra_args="#{trackIndex},"
		basequery = "INSERT INTO tracks (source_id,track_index,key,value)"
	else
		raise InvalidType,"An invalid type identifier was sent to internalSet"
	end #case type
	
	unless(basequery)
		basequery="INSERT INTO #{type} (source_id,#{extra_fields}key,value) "
	end

	realargs = []
	#if we have been given arrays or hashes, pull the data out so we can process
	args.each do |a|
		if(a.is_a?(Array))
			a.each do |b|
				realargs << b
			end
		elsif(a.is_a?(Hash))
			a.each do |k,v|
				realargs << k << v
			end
		else
			realargs << a
		end
	end

	realargs.each_slice(2) do |key,value|
		newkey=key.tr("'","''")
		newvalue=value.tr("'","''") unless(value==nil)
		
		#querystr=basequery+" VALUES (#{sourceid},#{extra_args}'#{newkey}','#{newvalue}')"
		if extra_args
			querystr = basequery + " VALUES (?,?,?,?)"
		else
			querystr = basequery + " VALUES (?,?,?)"
		end
		
		if(@debug)
			puts "About to run #{querystr}..."
		end
        
		if extra_args
			@dbh.execute(querystr,sourceid,extra_args,key,value)
		else
			@dbh.execute(querystr,sourceid,key,value)
		end
		
		#@dbh.execute(querystr)
	end #args.each_slice
end #@dbh.transaction

rescue SQLite3::BusyException=>e
	puts "-WARNING: Database busy when attempting update (#{e.message}). Retry in 5s."
	sleep(5)
	@dbh.rollback
	retry

end #exception handling
end #internalSet

def set(type,*args)

if type==nil or not type.is_a?(String)
	raise ArgumentError, "You need to pass a type parameter to set, one of either meta, media or track"
end

#throws TypeNotFound if type record doesn't exist and it couldn't be added
sourceid=self.getSource(type)
self.internalSet(sourceid,type,*args)

end #set

def get(type,*args)

if type=='movie'
	type='media'
end

if args.length==1
	needArray=0
	rtn=""
else
	needArray=1
	rtn=Array.new
end

case type
	when 'config' #config substitutions don't need to touch the database
		args.each {|key|
		  next if @defs[key] == nil
		  if needArray==1
			rtn << @defs[key]
		  else
			rtn = @defs[key]
		  end
		}
		return rtn
	when 'meta'
		endclause="order by ctime desc, sources.id desc"
	when 'media'
		endclause="order by ctime desc"
	when 'movie'
		endclause="order by ctime desc"
	when 'track'
		track=args.shift
		trackindex=self.getTrackId(nil,track,1)
		endclause="and track_index=#{trackindex} order by ctime desc"
	else
		raise InvalidType,"An invalid type identifier was sent to get. Please use one of meta,media or track."
end #case type


args.each do |key|
	newkey=key.tr("'","''")
	querystr="SELECT value FROM #{type} left join sources on source_id=sources.id WHERE key='#{newkey}' #{endclause}"

    if(@debug)
        puts "About to run #{querystr}..."
    end
	st=@dbh.prepare(querystr)
	result=st.execute
	result.each do |row|
		if needArray==1
			rtn.append(row[0])
		else
			rtn=row[0]
            break
		end
	end #result.each
	st.close
end #args.each_slice

return rtn
end #get

def _substitute_part(str,sec)
rtn=str
while(parts=rtn.match(/{#{sec}:([^\}]+)}/)) do
	#puts "substitute_string: got #{parts[1]}"
	replacement=self.get(sec,parts[1])
	rreg="{#{sec}:#{parts[1]}}"
	#puts "Replacing #{rreg} with #{replacement}"
	rtn.gsub!(rreg,replacement)
	#puts "Final value is #{rtn}"
	#raise StandardError,"test"
end
return rtn
end

def substitute_string(str)
nowtime=DateTime.now

if(str==nil)
	return nil
end

rtn=str.dup

days=['Zero','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']

months=['Zero','January','February','March','April','May','June','July','August','September','October','November','December']

mon=sprintf("%02d",nowtime.month);
mday=sprintf("%02d",nowtime.mday);
hour=sprintf("%02d",nowtime.hour);
min=sprintf("%02d",nowtime.min);
sec=sprintf("%02d",nowtime.sec);

begin
rtn.gsub!('{route-name}',ENV['cf_routename'])
rtn.gsub!('{year}',nowtime.year.to_s);
rtn.gsub!('{month}',mon.to_s);
rtn.gsub!('{day}',mday.to_s);
rtn.gsub!('{hour}',hour.to_s);
rtn.gsub!('{min}',min.to_s);
rtn.gsub!('{sec}',sec.to_s);
#rtn=rtn.gsub!('{is-dst}',isdst/g;
rtn.gsub!('{weekday}',days[nowtime.cwday]);
rtn.gsub!('{monthword}',months[nowtime.month]);
rtn.gsub!('{nextweek}',(nowtime + 7).strftime('%F'));
rescue Exception=>e
puts "-WARNING: #{e.message}"
puts e.backtrace
end


filepath=""
filebase=""
fileextn=""

if ENV['cf_media_file']!=nil
	if(parts=ENV['cf_media_file'].match(/^(.*)\/([^\/]+)\.([^\/\.]*)$/))
		filepath=parts[1]
		filebase=parts[2]
		fileextn=parts[3]
	elsif(parts=ENV['cf_media_file'].match(/^(.*)\/([^\/]+)$/))
		filepath=parts[1]
		filebase=parts[2]
		fileextn=""
	elsif(parts=ENV['cf_media_file'].match(/^([^\/]+)\.([^\/\.]*)$/))
		filepath=ENV['PWD']
		filebase=parts[1]
		fileextn=parts[2]
	end
end

rtn.gsub!('{filepath}',filepath)
rtn.gsub!('{filebase}',filebase)
rtn.gsub!('{fileextn}',fileextn)
rtn.gsub!('{filename}',"#{filebase}.#{fileextn}")

if(ENV['cf_failed_method'])
    rtn.gsub!('{failed-method}',ENV['cf_failed_method'])
end

if(ENV['cf_last_error'])
    rtn.gsub!('{last-error}',ENV['cf_last_error'])
elsif(ENV['cf_last_line'])
    rtn.gsub!('{last-error}',ENV['cf_last_line'])
else
    rtn.gsub!('{last-error}',"[no error set]")
end

#if($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)\.([^\/\.]*)$/){
#	$filepath=$1;
#	$filebase=$2;
#	$fileextn=$3;
#} elsif($ENV{'cf_media_file'}=~/^(.*)\/([^\/]+)$/){
#	$filepath=$1;
#	$filebase=$2;
#	$fileextn="";
#} elsif($ENV{'cf_media_file'}=~/^([^\/]+)\.([^\/\.]*)$/){
#	$filepath=$ENV{'PWD'};
#	$filebase=$1;
#	$fileextn=$2;
#}

rtn=_substitute_part(rtn,'config')
rtn=_substitute_part(rtn,'meta')
rtn=_substitute_part(rtn,'media')
rtn=_substitute_part(rtn,'track')

return rtn

end

def each(section,&blk)

end #def each

end #class

class InvalidSource < StandardError
end

class InvalidType < StandardError
end

