require 'Vidispine/VSApi'
require 'awesome_print'
require 'uri'
require 'date'

class VSShapeCollection < VSApi
include Enumerable

def initialize(host="localhost",port=8080,user="",passwd="",parent: nil)
    #super.initialize(host,post,user,passwd,parent: p)
    super(host,port,user,passwd,parent: parent)
    
    puts "debug: VSShapeCollection::initialize"
    @shapes=Array.new
end #def initialize

def populate(itemid)
    if(itemid!=nil)
        urlpath="/item/#{itemid}/shape"
        vsdoc=self.request(urlpath,method: "GET")
        
        #ap vsdoc
        
        vsdoc.xpath("//vs:uri",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
            #ap node
            begin
                shapename=node.inner_text
                newshape=VSShape.new(@host,@port,@user,@passwd)
                newshape.populate(itemid,shapename)
                @shapes << newshape
            rescue Exception=>e
                puts "-WARNING: an error occurred setting up new shape: #{e.message}"
            end #exception block
        end #xpath search
    end #if(itemid!=nil)
end #def populate

def each(&eachblock)
    @shapes.each { |s| yield s }
end

def shapeForTag(tagname, scheme: nil, mustExist: false, noraise: false, refresh: false)
    @shapes.each { |s|
        if(s.tag == tagname)
            if(refresh)
                s.refresh!
            end
            #check if the file actually exists. If not, keep lookin'...
            #            if(scheme and not File.exists?(URI.unescape(s.fileURI(scheme: scheme).path)))
            #    next
            #end
            if(scheme)
                s.eachFileURI(scheme: scheme) do |u|
                    unless(mustExist)
                        return s
                    end
                    if(File.exists?(URI.unescape(u.path)))
                        return s
                    end
                end #s.eachFileURI
                next
            end #if(scheme)
            return s
        end
    }
    if(noraise)
        return nil
    end
    
    raise VSNotFound, "No shape with tag #{tagname} could be found"
    
end #shapeForTag

def eachShapeForTag(tagname, noraise: false, refresh: false,&block)
    @shapes.each { |s|
        if(s.tag == tagname)
            if(refresh)
                s.refresh!
            end
            block.call(s)
        end
    }
    if(noraise)
        return nil
    end
    raise VSNotFound, "No shape with tag #{tagname} could be found"
end #def eachShapeForTag

end #class VSShapeCollection

class VSShape < VSApi
attr_accessor :id,:tag
    
def initialize(host="localhost",port=8080,user="",passwd="",parent: p)
    super
    @id=nil
    @tag=nil
    @item=nil
end #def initialize

def populate(itemid,shapeid)
        urlpath="/item/#{itemid}/shape/#{shapeid}"
        @item=itemid
        @processed_xml=self.request(urlpath,method: "GET")
        @processed_xml.xpath("//vs:ShapeDocument/vs:tag",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
            @tag=node.inner_text
        end
        @processed_xml.xpath("//vs:ShapeDocument/vs:id",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
            @id=node.inner_text
        end
end

def refresh!
    self.populate(@item,@id)
end

def eachFileURI(scheme: nil,&block)
    @processed_xml.xpath("//vs:containerComponent/vs:file",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
        uriNode=node.xpath("vs:uri",'vs'=>"http://xml.vidispine.com/schema/vidispine")
        if(uriNode)
            uri=URI(uriNode.inner_text)
        else
            uri=nil
        end
        storageNode=node.xpath("vs:storage",'vs'=>"http://xml.vidispine.com/schema/vidispine")
        if(storageNode)
            storageName=storageNode.inner_text
        else
            storageName=nil
        end
        #yield URI(node.inner_text)
        #if the caller has requested a specific scheme, check that we match
        if(scheme)
            if(uri.scheme!=scheme)
                next
            end
        end #if(scheme)
        yield uri,storageName
    end
    return URI("")
end #def eachFileURI

#kept for backwards compatibility
def fileURI(scheme: nil)
    self.eachFileURI(scheme: scheme) do |u|
        return u
    end
end #def fileURI

def fileData(&block)
    @processed_xml.xpath("//vs:containerComponent/vs:file",'vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
        idNode = node.xpath("vs:id",'vs'=>"http://xml.vidispine.com/schema/vidispine")
        if not idNode
            next
        end
        
        url = "/storage/file/#{idNode.inner_text}/data"
        self.request(url,method: "GET",accept: "*") do |data|
            #puts "fileData: request"
            yield data
        end
        return
    end
    raise VSNotFound, "No shapes with valid container components found"
end
end #class VSShape

class StreamingImport < VSApi
    attr_accessor :stream, :chunkSize
    
    class ImportInProgress < StandardError
    end
    
    class NoImportStarted < StandardError
    end
    
    def initialize(host="localhost",port=8080,user="",passwd="",parent: nil,stream: nil)
        super(host,port,user,passwd,parent: parent)
        @stream=stream
        @importLength=-1
        @chunkSize=1e6  #1mb chunk size by default
        @transferId=nil
        @total_imported=0
        @targetItem = nil
        @shapeTag = 'original'
    end #def initialize
    
    def start(targetItem: nil, shapeTag: 'original',importLength: 0)
        if @transferId != nil
            raise ImportInProgress
        end
        
        if not shapeTag.is_a?(string)
            raise TypeError, 'shapeTag must be a string'
        end
        if importLength <= 0
            raise ValueError, 'importLength must be > 0'
        end
        
        @targetItem = targetItem
        if @targetItem
            @transferId = @targetItem + ":" + shapeTag + "_" + date.strftime("%y%m%d%H%M%S")
        else
            @transferId = "NEW" + ":" + shapeTag + "_" + date.strftime("%y%m%d%H%M%S")
        end
        
        @importLength=importLength
        @shapeTag = shapeTag
    end
    
    def write_chunk(data, length: nil)
        if @transferId == nil
            raise NoImportStarted
        end
        
        if @targetItem
            url = "/item/#{@targetItem}/shape/essence/raw"
        else
            raise StandardError("Streaming import to a new item not supported yet")
        end
        
        if length == nil
            length = @chunkSize
        end
        
        if data.is_a?(IO)
            to_write = data.read(length)
        else
            to_write = data
        end
        
        self.request(url, method: "POST",query: {
                        "transferId" => @transferId,
                        "tag" => @shapeTag
                     }, headers: {
                        "Content-Type" => 'application/octet-stream',
                        "size" => length,
                        "index" => @total_imported
                     },
                     body: to_write)
        
        @total_imported += length
    end
    
    def write(&block) #expects a block that should return a length, data tuple. Return 0, nil to complete.
        while(true)
            length, data = block.call()
            break if data==nil
            
            self.write_chunk(data, length: length)
        end 
    end
    
    def end(args)
        #code
    end
end