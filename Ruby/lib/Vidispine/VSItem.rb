require 'Vidispine/VSApi'
require 'Vidispine/VSShape'
require 'Vidispine/VSJob'
require 'nokogiri'
require 'cgi'

class VSTranscodeError < VSException
end #VSTranscodeError

class VSItem < VSApi
    attr_accessor :id
    
    def initialize(host="localhost",port=8080,user="",passwd="",parent: nil)
        #super.initialize(host,port,user,passwd,parent: p)
        super
        
        @processed_xml=nil
        @shapes=nil
        @metadata=Hash.new
        @vs_object_class="item" 
    end #def initialize
    
    def populate(itemid, refreshShapes: false)
        if(@shapes==nil or refreshShapes)
            @shapes=VSShapeCollection.new(@host,@port,@user,@passwd)
            @shapes.populate(itemid)
        end
        
        #urlpath="/item/#{itemid}/metadata"
        #@processed_xml=self.request(urlpath,"GET")
        @metadata, @groupname=self.get_metadata("/item/#{itemid}")
        @id=itemid
    end #def populate
 
    def import_raw(data, filename, shape_tags: [],initial_metadata: nil,metadata_group: 'Asset',original_shape: nil, thumbs: true, storage_id: nil, priority: 'MEDIUM')
	qparms = {
		    "filename"=>File.basename(filename),
		}
	
	if thumbs
	    qparms['thumbnails'] = 'true'
	end
	
	if shape_tags!=nil
	    if not shape_tags.is_a?(Array)
		shape_tags = [shape_tags]
	    end
	    qparms['tag'] = shape_tags.join(',')
	end
	
	if shape_tags!=nil and original_shape!=nil
	    if not shape_tags.include?(original_shape)
		raise ArgumentError, "When importing a file, if original_shape is specified it must be one of the transcode shapes supplied"
	    end
	    qparms['original'] = original_shape
	end
	
	if storage_id !=nil
	    qparms['storageId'] = storage_id
	end
	
	if priority!=nil
	    qparms['priority'] = priority
	end
	
	jobDocument = self.request("/import/raw", method: "POST", query: qparms, body: data, content_type: 'application/octet-stream')
	
	jobdesc = self._waitjob(jobDocument)
	@id = jobdesc.itemId
	self.populate(@id)
    end
    
    def import_uri(uri,shape_tags: [],initial_metadata: nil,metadata_group: 'Asset',original_shape: nil, thumbs: true, storage_id: nil, priority: 'MEDIUM')
	qparms = {
		    "uri"=>URI.escape(uri),
		    "filename"=>File.basename(uri),
		}
	
	if thumbs
	    qparms['thumbnails'] = 'true'
	end
	
	if shape_tags!=nil
	    if not shape_tags.is_a?(Array)
		shape_tags = [shape_tags]
	    end
	    qparms['tag'] = URI.escape(shape_tags.join(','))
	end
	
	if shape_tags!=nil and original_shape!=nil
	    if not shape_tags.include?(original_shape)
		raise ArgumentError, "When importing a file, if original_shape is specified it must be one of the transcode shapes supplied"
	    end
	    qparms['original'] = original_shape
	end
	
	if storage_id !=nil
	    qparms['storageId'] = URI.escape(storage_id)
	end
	
	if priority!=nil
	    qparms['priority'] = priority
	end
	
	filebase = File.basename(uri)
	if initial_metadata==nil
	    raise ArgumentError, "import_uri: you must set some initial metadata by providing a hash to initial_metadata:, i.e. initial_metadata: {'title': 'rhubarb'}"
	end
	if not initial_metadata.is_a?(Hash) or initial_metadata.length<1
	    raise ArgumentError, "import_uri: initial_metadata must be a Hash of fieldname-value pairs containing at least one element (hint: {'title'=>'my title'})"
	end
	if not initial_metadata.include?('originalFilename')
	    initial_metadata['originalFilename'] = filebase
	end
	
	builder = Nokogiri::XML::Builder.new do |xml|
	    xml.MetadataDocument({:xmlns=>"http://xml.vidispine.com/schema/vidispine"}) {
		xml.group(metadata_group)
		xml.timespan({:start=>'-INF', :end=>'+INF'}){
		    initial_metadata.each {|k,v|
			xml.field {
			    xml.name(k)
			    xml.value(v)
			} #xml.field
		    } #initial_metadata.each
		} #xml.timespan
	    } #xml.MetadataDocument
	end #Nokogiri::XML::Builder.new
	
	jobDocument = self.request("/import", method: "POST", query: qparms, body: builder.to_xml)
	
	self._waitjob(jobDocument)
    end
    
    def refresh(refreshShapes: true)
        return self.populate(@id, refreshShapes: refreshShapes)
    end #def refresh
    
    def refresh!(refreshShapes: true)
        self.refresh(refreshShapes: refreshShapes)
    end
    
    def metadata
        @metadata
    end
    
    def shapes
        @shapes
    end #def shapes
    
    def get(key)
	@metadata[key]
    end
    
    def include?(key)
	@metadata.include?(key)
    end
    def getMetadata
        return @metadata
    end #def getMetadata
    
    def _waitjob(jobDocument)
        if(@debug)
	    puts jobDocument.to_xml(:indent=>2)
	end
        jobid=-1
        jobDocument.xpath("//vs:jobId",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |idnode|
            jobid=idnode.inner_text
            #puts "found id #{idnode.inner_text}"
        end #jobId
        
        if(jobid==-1)
            raise NameError, "Unable to get job ID!!"
        end
        
        #puts "found job at id #{jobid}"
        begin
            job = VSJob.new(@host,@port,@user,@passwd)
            job.populate(jobid)
            #unless(silent)
           #     ap job
                puts "Job #{jobid} has status #{job.status}"
                #end
            
            if(job.finished?(noraise: false)) #this will raise VSJobFailed if there was an error
                #reload our shapes
                @shapes=VSShapeCollection.new(@host,@port,@user,@passwd)
                @shapes.populate(@id)
                break
            end
            
            sleep(20)
        end while true
        job
    end
    
    def transcode!(shapetag,priority: 'MEDIUM', silent: 'false')
        jobDocument = self.request("/item/#{@id}/transcode",method: "POST",
                                   query: {'priority'=>priority,
                                    'tag'=>URI.escape(shapetag) })
        #it's up to the caller to catch exceptions...
        
        self._waitjob(jobDocument)

        #reload our shapes
        @shapes=VSShapeCollection.new(@host,@port,@user,@passwd)
        @shapes.populate(@id)
    end #def transcode!
    
    #sets metadata fields on this item. Should be called as item.setMetadata({'field': 'value', 'field2': 'value2' etc.})
    #will throw exceptions (VS* or HTTPError) and not update the internal representation if the Vidispine update fails
    def setMetadata(mdhash,groupname: @groupname,vsClass: "item")
    raise ArgumentError if(vsClass.match(/[^a-z]/
        
    begin
        #we can't use self.set_metadata as this gives a SimpleMetadataDocument, wherase we need the full monty for items
        #self.set_metadata("/item/#{@id}",mdhash,groupname)
        xmlBuilder = Nokogiri::XML::Builder.new(:encoding=>'UTF-8') do |xml|
            xml.MetadataDocument('xmlns'=>"http://xml.vidispine.com/schema/vidispine") {
                xml.timespan('start'=>'-INF','end'=>'+INF') {
                    if(groupname)
                        xml.group {
                            xml.name groupname
                            mdhash.each do |key,value|
                                xml.field {
                                    xml.name key
                                    if(value.is_a?(Array))
                                        value.each do |v|
                                            xml.value v
                                        end #value.each
                                    else
                                        xml.value value
                                    end #if value.is_a?(Array)
                                }
                            end #mdhash.each
                        }
                    else
                        mdhash.each do |key,value|
                            xml.field {
                                xml.name key
                                if(value.is_a?(Array))
                                    value.each do |v|
                                        xml.value v
                                    end #value.each
                                else
                                    xml.value value
                                end #if value.is_a?(Array)
                            }
                        end #mdhash.each
                    end #if(groupname)
                } #<timespan>
            } #<MetadataDocument>
        end #Nokogiri::XML::Builder.new

        doc=xmlBuilder.to_xml
        
        if(@debug)
            puts "item::setMetadata: debug: xml to send:\n"
            puts doc
        end
        self.request("/#{vsClass}/#{@id}/metadata",method: "PUT", body: doc) #,matrix={'projection'=>'default'} )
        
        mdhash.each do |key,value|
            @metadata['key']=value
        end

    end
    end #def setMetadata
    
    #downloads file content and yields to block
    def fileData(shapeTag: 'original',&block)
	requiredShapes = self.shapes.shapeForTag(shapeTag) #should raise an exception if shapetag is not found
	requiredShapes.fileData(block)
    end
    
    def addAccess(access)
        super("/#{@vs_object_class}/#{@id}",access)
    end
    
    def importMetadata(readyXML,projection: nil)
    begin
	#validate the XML with Nokogiri before passing it to Vidispine
	Nokogiri::XML(readyXML) { |config| config.strict }
    rescue Nokogiri::XML::SyntaxError => e
	    if @logger
		@logger.error("Invalid XML passed to importMetadata: #{e}")
	    else
		$stderr.puts "Invalid XML passed to importMetadata: #{e}"
	    end
    end

    if projection
	self.request("/#{@vs_object_class}/#{@id}/metadata", method: "PUT", matrix: {'projection'=>projection},body: readyXML)
    else
	self.request("/#{@vs_object_class}/#{@id}/metadata", method: "PUT", body: readyXML)
    end
end

end
