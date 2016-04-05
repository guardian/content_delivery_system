require 'net/http'
require 'date'
require 'awesome_print'
require 'nokogiri'

#type of tag feed
TF_R2_KEYWORDS = 1
TF_RCS_SUPPLIER = 2
TF_RCS_ROLE = 3

class XMLChopper
attr_accessor :root_name
attr_accessor :item_name
attr_accessor :chunksize

def initialize(chunksize)
    @chunksize=chunksize
    @root_name=nil
    @item_name=nil
    @chunks=Array.new
    @chunk_in_progress=nil
end #def initialize


end #class Chopper

class BasicParser < Nokogiri::XML::SAX::Document
attr_accessor :debug
attr_accessor :root_name
attr_accessor :item_name
attr_accessor :chunks
attr_accessor :docheader
attr_accessor :maxchunks

def initialize(maxchunks)
    @current_tree=Array.new
    @chunks=Array.new
    @maxchunks=maxchunks
end #def initialize

def output_ready?
    #puts "BasicParser::output_ready: got #{chunks.length}"
    if(chunks.length>=@maxchunks)
        return true
    end
    return false
end

def output
rtn=@docheader
n=0

begin
    while(n<@maxchunks)
        rtn+=chunks.shift
        n+=1
    end #while
rescue TypeError=>e #this is thrown when we get to the end of the list

end

rtn+="</"+@root_name+">"
return rtn

end #def output

def start_document()
    if(@debug)
        puts "BasicParser: startDocument"
    end
    @root_name=nil
    @item_name=nil
    @in_items=false
    @accumulator=""
    @docheader=""
end

def end_document
    if(@debug)
        puts "BasicParser: endDocument"
    end
end

def rebuild_tag(name,attrs = [])
rtn='<'
rtn+=name
attrs.each do |a|
    rtn+=' '+a[0]+'="'+a[1]+'"'
end
rtn+='>'

end #rebuild_tag

def start_element(name,attrs = [])
    if(@debug)
        puts "BasicParser: startElement: #{name} #{attrs}"
        ap @current_tree
    end
    
    @current_tree << name
    if(@root_name==nil)
        @root_name=name
    elsif(@item_name==nil)
        @item_name=name
    end
    
    unless(@in_items)
        if(name==@item_name)
            @in_items=true
        else
            @docheader+=self.rebuild_tag(name,attrs)
        end
    end
    if(@in_items)
        @accumulator+=self.rebuild_tag(name,attrs)
    end
end

def end_element(name)
    if(@debug)
        puts "BasicParser: endElement: #{name}"
    end
    @accumulator+="</"+name+">"
    
    if(@current_tree.length==2)
        #puts "------END OF ITEM"
        @chunks << @accumulator
        @accumulator=""
    end
    @current_tree.shift
end

def characters(string)
    if(@debug)
        puts "BasicParser: characters"
    end
    
    if(@in_items)
        @accumulator+=string
        else
        @docheader+=string
    end
end

def cdata_block(string)
    if(@debug)
        puts "BasicParser: cdata_block: #{string}"
    end
    if(@in_items)
        @accumulator+=string
    else
        @docheader+=string
    end
end

end #class BasicParser

class TagFeed
attr_accessor :url
attr_accessor :username
attr_accessor :pasword
attr_accessor :feedtype
attr_accessor :encoding

def initialize(url,feedtype: feedtype, username: username, encoding: encoding)
    @url=url
    @feedtype=feedtype
    if(username)
        @username=username
    else
        @username=nil
    end
    if(@password)
        @password=password
    else
        @password=nil
    end
    @encoding=encoding
end #def initialize

#You should call this as a block, such as feed.download!(50) |
def download!(chunksize)
    uri=URI(@url)
    
    #    chopper=XMLChopper.new(chunksize)
    saxclass=BasicParser.new(chunksize)
    saxclass.debug=false
    
    if(@encoding)
        parser = Nokogiri::XML::SAX::PushParser.new(saxclass,nil, @encoding)
    else
        raise StandardError,"Test"
        parser = Nokogiri::XML::SAX::PushParser.new(saxclass)
    end
    
    Net::HTTP.start(uri.host,uri.port) do |http|
        req=Net::HTTP::Get.new uri
        
        http.request(req) do |response|
            response.read_body do |segment|
                parser << segment
                while(saxclass.output_ready?)
                    yield saxclass.output
                end
                #                chopper.input(segment)
                #if(chopper.output_ready?)
                #    yield chopper.output
                #end
            end #res.read_body
        end #http.request
        parser.finish
        yield saxclass.output
    end #Net::HTTP.start
    
    #puts "Root XML node is #{saxclass.root_name}, item XML node is #{saxclass.item_name}"
    if(@debug)
        ap saxclass.chunks
    end
end #def download!

end #class TagFeed