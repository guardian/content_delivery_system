require 'Vidispine/VSApi'
require 'Vidispine/VSItem'
require 'Vidispine/VSCollection'

require 'nokogiri'
require 'awesome_print'

class SearchParser < Nokogiri::XML::SAX::Document
    attr_accessor :debug
    attr_accessor :vsConnection
    attr_accessor :items
    attr_accessor :hits
    
    def start_document()
        if(@debug)
            puts "SearchParser: startDocument"
        end
        @current_tree = []
        @root_name = nil
        @item_name = nil
        
        @current_item = nil
        @items = Array.new
        @hitsstring = ""
        @hits = 0
        @type_override = ""
        @current_name = ""
    end
    
    def end_document
        if(@debug)
            puts "SearchParser: endDocument"
        end
    end
    
    def start_element(name,attrs = [])
        if(@debug)
            puts "SearchParser: startElement: #{name} #{attrs}"
        end
        
        @current_tree << name
        if(@debug)
            ap @current_tree
        end
        
        if(@root_name==nil)
            @root_name=name
        elsif(@item_name==nil)
            @item_name=name
        end
        
        case name
            when 'item'
                @current_item = VSItem.new(vsConnection.host,vsConnection.port,vsConnection.user,vsConnection.passwd)
                @current_item.id = attrs['id']
            when 'collection'
                @current_item = VSCollection.new(vsConnection.host,vsConnection.port,vsConnection.user,vsConnection.passwd)
                @current_item.id = ""
                @current_item.name = ""
            when 'content'
                @current_item = VSItem.new(vsConnection.host,vsConnection.port,vsConnection.user,vsConnection.passwd)
                @current_item.id=""
                #@current_item.name=""
            else
        end #case name
    end #def start_element
    
    def end_element(name)
        if(@debug)
            puts "SearchParser: endElement: #{name}"
        end

        ending_tag = @current_tree.pop
        ap @current_tree
        
        case ending_tag
            when 'collection'
                @items << @current_item
                @current_item = nil
            when 'item'
                @items << @current_item
                @current_item = nil
            when 'content'
                if(@type_override=="collection")
                    coll = VSCollection.new(vsConnection.host,vsConnection.port,vsConnection.user,vsConnection.passwd)
                    coll.id = @current_item.id
                    coll.name = @current_name
                    @items << coll
                else
                    @items << @current_item
                end
                @current_name = ""
                @current_item = nil
            when 'hits'
                @hits = @hitsstring.to_i
        end #case ending_tag
            #if(block_given?)
            #yield @current_item
            #end
    end
    
    def characters(string)
        if(@debug)
            puts "SearchParser: characters"
        end
    
        current_tag = @current_tree[-1]
        parent_tag = @current_tree[-2]
        if(@debug)
            puts "\tparent tag: #{current_tag}"
        end
        
        case current_tag
            when 'id'
                if(parent_tag == 'collection' or
                       parent_tag == 'item' or
                       parent_tag == 'content')
                @current_item.id += string
                end #if
            when 'name'
                if(@current_item.is_a?(VSCollection))
                    @current_item.name += string
                else
                    @current_name += string
                end
            when 'hits'
                @hitsstring += string
            when 'type'
                puts "type: #{string}, #{current_tag}, #{parent_tag}"
                if(parent_tag == 'content')
                    puts "type override: #{@type_override}"
                    @type_override += string
                end #if(parent_tag)
        end #case current_tag
    end
    
    def cdata_block(string)
        if(@debug)
            puts "SearchParser: cdata_block: #{string}"
        end
    end
    
end #class SearchParser

class VSSearchCriterion
    def initialize(mdhash,invert,parent)
        @mdhash=mdhash
        @invert=invert
        @parent=parent
    end #def initialize
    
    def output_xml(xmlbuilder)
        if(@invert)
            xmlbuilder.operator("operation"=>"NOT"){
                @parent.call_make_xml(xmlbuilder,@mdhash)
            }
        else
            @parent.call_make_xml(xmlbuilder,@mdhash)
        end
    end #to_xml
        
end #class VSSearchCriterion

class InvalidSearchType < StandardError
end

class VSSearch < VSApi
    attr_accessor :host
    attr_accessor :port
    attr_accessor :user
    attr_accessor :passwd
    attr_accessor :hits
    
    def initialize(host="localhost",port=8080,user="",passwd="",parent: nil)
        #super.initialize(host,post,user,passwd,parent: p)
        super(host,port,user,passwd,parent: parent)
        
        @criteria = []
        @searchType="item"
        @hits = nil
        @timespan_start=nil
        @timespan_end=nil
    end #def initialize

    #add a criterion to the search. The criterion should be specified in a hash consisting of field_name=>value or field_name=>[value 1, value2] pairs.
    #The optional invert argument specifies that Vidispine should search for the fields _not_ to match
    def addCriterion(metadata, invert: false)
        @criteria << VSSearchCriterion.new(metadata,invert,self)
    end #def addCriterion
    
    def timespan(start: "-INF",endtime: "+INF")
        @timespan_start=start
        @timespan_end = endtime
    end

    def searchType(type)
        case type
        when "item"
            @searchType=type
        when "collection"
            @searchType=type
        when "any"
            @searchType="search"
        else
            raise InvalidSearchType, "Search type must be either item, collection or any"
        end #case type
    end #def searchType
    
    def results(start: nil, number: nil,withinCollection: nil,&block)
        builder = Nokogiri::XML::Builder.new do |xml|
            xml.ItemSearchDocument('xmlns'=>'http://xml.vidispine.com/schema/vidispine') {
                if(@timespan_start and @timespan_end)
                    xml.timespan('start'=>'-INF', 'end'=>'+INF'){
                        @criteria.each do |criterion|
                            criterion.output_xml(xml)
                        end #@criteria.each
                    } #xml.timespan
                    xml.highlight
                else
                    @criteria.each do |criterion|
                        criterion.output_xml(xml)
                    end #@criteria.each
                end
            } #xml.MetadataDocument

        end #Nokogiri::XML::Builder.new
        xmlbody = builder.to_xml
        
        if(@debug)
            puts "debug: VSSearch::results - request body to send:"
            puts xmlbody
        end
        
        params = {}
        params['start'] = start if(start!=nil)
        params['number'] = number if(number!=nil)
        
        saxclass = SearchParser.new
        #saxclass.debug = @debug
        saxclass.vsConnection = self
        
        parser = Nokogiri::XML::SAX::PushParser.new(saxclass,nil,'Latin-1')
        
        url = "/#{@searchType}"
        method = "PUT"
        if(withinCollection)
            #puts "got withinCollection arg"
            if(withinCollection.is_a?(VSCollection))
                url = "/collection/#{withinCollection.id}/item"
                #method = "POST"
            elsif(withinCollection.is_a?(String))
                url = "/collection/#{withinCollection}/item"
                #method = "POST"
            else
                raise ArgumentError("withinCollection argument should be a collection or a string")
            end
        end

        #calling this as a block should pass us chunks of data as they are receieved from the server
        self.raw_request(url,method,
                     params, nil, xmlbody) do |response|
            if(@debug)
                puts "Returned response: #{response}"
            end
            #response.read_body do |segment|
                if(@debug)
                    #puts "Returned XML segment: #{response}"
                end
                sanitisedText = ""
                
                begin #exception block
                    #not _quite_ sure why this works, but it does!
                    #ref. http://stackoverflow.com/questions/23309669/ruby-encode-xc3-from-ascii-8bit-to-utf-8-encodingundefinedconversionerr
                    sanitisedText = response.force_encoding('ISO-8859-1').encode('UTF-8')
                rescue Encoding::UndefinedConversionError=>e
                #if(sanitisedText.gsub!(/#{e.error_char}/,'?')==nil)
                #        yield StandardError,"Unable to sanitise string"
                #   end
                    #retry
                    puts "error char: #{e.error_char}"
                    sanitisedText = sanitisedText.dump()
                    ap e
                    retry
                end
                
                begin
                    parser << sanitisedText
                rescue Nokogiri::XML::SyntaxError=>e
                    puts "-WARNING: #{e.to_s} at column #{e.column} on line #{e.line}"
                    if(e.fatal?)
                        raise StandardError, "Fatal error"
                    end
                    #ensure #if we error, output everything that we got up till that point
                end #exception block
                while(saxclass.items.length > 0)
                    @hits = saxclass.hits
                    foundItem = saxclass.items.shift
                    if(@debug)
                        ap foundItem
                        puts "Yielding item #{foundItem.id}"
                    end
                    
                    yield foundItem
                end
                #end #response.read_body
        end #self.request
        if(@debug)
            puts "Got a total of #{saxclass.hits} hits"
        end
    end #def results
    
    def call_make_xml(xmlbuilder,mdhash)
        self.output_xml_fieldgroup(xmlbuilder,mdhash,top: false)
    end
end #class VSSearch