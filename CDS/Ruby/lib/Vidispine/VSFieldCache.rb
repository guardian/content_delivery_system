require 'Vidispine/VSApi'
require 'awesome_print'
require 'JSON'

class NoFieldsPresentException < VSException
end

class VSFieldCache < VSApi
include Enumerable
#@by_VSName,@by_PortalName,@by_Group

def initialize(host="localhost",port=8080,user="",passwd="")
super
@by_VSName=Hash.new
@by_PortalName=Hash.new
@by_Group=Hash.new

end

def refresh

if(@debug)
	$stderr.puts "Loading field definitions..."
end

data=self.request("/metadata-field",method: "GET",matrix: nil,query: {'data' => 'all'})
#ap data

if(@debug)
	$stderr.puts "Parsing provided data..."
end

data.xpath("//vs:field",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
	field=Hash.new
	field['vs_name']=node.xpath("vs:name",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	field['vs_type']=node.xpath("vs:type",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	field['vs_origin']=node.xpath("vs:origin",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	field['default']=node.xpath("vs:defaultValue",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	
	field['vs_extradata']=node.xpath("vs:data/vs:key[text()='extradata']/../vs:value",'vs'=>"http://xml.vidispine.com/schema/vidispine").inner_text
	
	if(field['vs_extradata'].start_with?('{'))
	begin
		portaldata=JSON.parse(field['vs_extradata'])
		portaldata.each do |key,value|
			field["portal_"+key]=value
		end #portaldata.each
		
		@by_PortalName[field["portal_name"]]=field
		
	rescue JSON::JSONError=>e
		$stderr.puts "WARNING - JSON parsing error: #{e.message}"
		
	end #json parsing block
	end #start_with
	
	@by_VSName[field["vs_name"]]=field
end #data.xpath().each

#ap @by_VSName
#ap @by_PortalName

end #def refresh

def lookupByPortalName(name)

if(@by_PortalName.count()<1)
	self.refresh()
	if(@by_PortalName.count()<1)
		raise NoFieldsPresentException, "No Portal-created fields were found!"
	end
end

if(@by_PortalName[name].is_a?(Hash))
	return @by_PortalName[name]
end

raise VSNotFound, "lookupByPortalName: No field could be found with Portal name #{name}"
end #def lookupByPortalName

def lookupByVSName(name)

if(@by_VSName.count()<1)
	self.refresh()
	if(@by_VSName.count()<1)
		raise NoFieldsPresentException, "No fields were found!"
	end
end

if(@by_VSName[name].is_a?(Hash))
	return @by_VSName[name]
end

raise VSNotFound, "lookupByVSName: No field could be found with name #{name}"
end #def lookupByVSName

def each(&blk)

@by_VSName.each do |vsname,field|
	yield field
end

end

end #class VSFieldCache