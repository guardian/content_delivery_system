require 'Vidispine/VSApi'
require 'logger'
require 'date'

class MetadataGroup
  include Enumerable
  
  #attr_accessor :content
  
  def initialize(node,parent,logger: Logger.new(STDERR))
    @node=node
    @parent=parent
    @log=logger
    #@content = {}
  end
  
  def name
    #puts @node
    @node.xpath('vs:name','vs'=>"http://xml.vidispine.com/schema/vidispine").text
  end
  
  def uuid
    @node['uuid']
  end
  
  def [](key)
    self.each do |name,values|
      if name==key
        return values
      end
    end
  end
  
  #try to convert the argument to a more sensible form. If we fail, return the string.
  def _transformer(str)
    begin
      return Integer(str)
    rescue ArgumentError
    end
    
    begin
      return Float(str)
    rescue ArgumentError
    end
    
    #begin
    #  return Date.parse(str)
    #rescue ArgumentError
    #end
    
    str
  end
  
  def each
    @node.xpath('vs:field','vs'=>"http://xml.vidispine.com/schema/vidispine").each {|fieldnode|
      name=fieldnode.xpath('vs:name','vs'=>"http://xml.vidispine.com/schema/vidispine").text
      values =[]
      fieldnode.xpath('vs:value','vs'=>"http://xml.vidispine.com/schema/vidispine").each {|valnode|
        values << self._transformer(valnode.text) 
      }
      if values.length == 1
        values = values[0]
      end
      yield name,values
    }
  end
  
  #def _addDefinition(node)
  #  node.xpath('vs:field','vs'=>"http://xml.vidispine.com/schema/vidispine").each {|fieldnode|
  #    name=fieldnode.xpath('vs:name','vs'=>"http://xml.vidispine.com/schema/vidispine").text
  #    values =[]
  #    fieldnode.xpath('vs:value','vs'=>"http://xml.vidispine.com/schema/vidispine").each {|valnode|
  #      values << self._transformer(valnode.text) 
  #    }
  #    if values.length == 1
  #      values = values[0]
  #    end
  #    #yield name,values
  #    @content[name] = values
  #    puts "adding #{name}=>#{values} to #{self.name} (#{self.uuid})"
  #    #raise StandardError, "Testing"
  #  }
  #end
end

class VSMetadataElements < VSApi
  include Enumerable
  
  def initialize(host="localhost",port=8080,user="",passwd="",parent: nil)
      super(host,port,user,passwd,parent: parent)
      self.populate
  end #def initialize
      
  def populate
    @logger = Logger.new(STDERR)
    @logger.level = Logger::DEBUG
    
    @logger.debug("requesting global metadata from #{@host}:#{@port}")
    @content = self.request("/metadata")
    @logger.debug("done")
    @groups = {}
    #@content.xpath('//vs:group','vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
      #@logger.debug("Got group node #{node}"
      #if not @groups[node['uuid']]
      #  @groups[node['uuid']] = MetadataGroup.new(node,self)
      #end
      #@groups[node['uuid']]._addDefinition(node)
      #g = MetadataGroup.new(node,self)
      #name = node.xpath('vs:name','vs'=>"http://xml.vidispine.com/schema/vidispine").text
      #if not @groups[name]
      #  @groups[name] = MetadataGroup.new(node,self)
      #end
      #@groups[name]._addDefinition(node)
      #ap @groups
      #raise StandardError, "Testing"
    #end
    
  end
  

  def each
    @content.xpath('//vs:group','vs'=>"http://xml.vidispine.com/schema/vidispine").each do |node|
#      @logger.debug("Got group node #{node}")
      yield MetadataGroup.new(node,self,logger: @logger)
    end
  end
  
  def findName(name)
    self.each {|group|
      #@logger.debug("Got #{group.name} #{group.uuid}")
      yield group if(group.name == name)
    }
  end
  
  def findUUID(id)
    self.each {|group|
      yield group if(group.uuid == id)
    }
  end
end #class MetadataElements

