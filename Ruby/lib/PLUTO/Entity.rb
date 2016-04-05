require 'Vidispine/VSItem'
require 'Vidispine/VSCollection'
require 'Vidispine/VSSearch'
require 'json'
require 'awesome_print'

#Pluto class constants
PLUTO_COMMISSION = "Commission"
PLUTO_PROJECT = "Project"
PLUTO_MASTER = "Master"
PLUTO_CROP = "CroppedImage"

#This module implments basic code common to all PLUTO objects.  PLUTO commissions, masters and projects inherit from here.

class PLUTOException < StandardError
end

class PLUTONotFound < PLUTOException
end

class SuperProxy
    def initialize(obj)
        @obj = obj
    end
    
    def method_missing(meth, *args, &blk)
        @obj.class.superclass.instance_method(meth).bind(@obj).call(*args, &blk)
    end
end

def isUUID(str,noraise: true)
    if(str.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i))
        return true
    end
    raise ValueError unless(noraise)
    return false
end #def isUUID
    
#"container" objects - commissions, projects - inherit from here
class PLUTOContainerEntity < VSCollection
    attr_accessor :title
    attr_accessor :id
    attr_accessor :status
    
    def sup
        SuperProxy.new(self)
    end
    
    def populate(itemid)
        super
        #if title
        #@title=title
            #else
            @title = @metadata['title']
            #end
        @status = @metadata['status']
    end
    
    def populateByTitle(plutoClass,title)
        search = VSSearch.new(@host,@port,@user,@passwd)
        search.debug=true
        search.addCriterion({'gnm_type' => plutoClass},invert: false)
        search.addCriterion({'title' => "\"#{title}\""},invert: false)
        search.searchType("collection")
        n=0
        search.results(start:'1', number: '1') do |item|
            n+=1
            self.populate(item.id)
        end #search.results
        if(@id==nil)
            raise PLUTONotFound
        end
    end #def populateByTitle
    
    def refresh
        super
        @title = @metadata['title']
        @status = @metadata['status']
    end
    
    def create!(plutoClass,title,commissionerUID: nil,
                workingGroupUID: nil,client: nil,
                projectTypeUID: nil,subscribingGroupIDs: nil,
                ownerID: nil, extraMeta: nil,noraise: false)
        
        #puts "Data at point PLUTOContainerEntity create!"
        #puts "plutoClass: #{plutoClass}"
        #puts "title: #{title}"
        #puts "commissionerUID: #{commissionerUID}"
        #puts "workingGroupUID: #{workingGroupUID}"
        #puts "client: #{client}"
        #puts "projectTypeUID: #{projectTypeUID}"
        #puts "subscribingGroupIDs: #{subscribingGroupIDs}"
        #puts "ownerID: #{ownerID}"
        #puts "extraMeta: #{extraMeta}"
        #puts "noraise: #{noraise}"
        
        metadata = {}
        
        case plutoClass
            when PLUTO_COMMISSION
                metadata['gnm_type'] = PLUTO_COMMISSION
                metadata['gnm_commission_title'] = title
                metadata["gnm_commission_commissioner"] = commissionerUID if(commissionerUID and isUUID(commissionerUID,noraise: noraise))
                metadata["gnm_commission_workinggroup"] = workingGroupUID if(workingGroupUID and isUUID(workingGroupUID,noraise: noraise))
                metadata["gnm_commission_client"] = client if(client and client.is_a?(String))
                metadata["gnm_commission_projecttype"] = projectTypeUID if(projectTypeUID and isUUID(projectTypeUID,noraise: noraise))
                metadata["gnm_commission_owner"] = ownerID
                #metadata.merge!(extraMeta) #should probably validate the fields somehow but this will probably work for now
            when PLUTO_PROJECT
                metadata['gnm_type'] = PLUTO_PROJECT
                metadata['gnm_project_headline'] = title
                metadata['gnm_project_type']= projectTypeUID if(projectTypeUID and isUUID(projectTypeUID,noraise: noraise))
                metadata["gnm_project_username"] = ownerID
            else
                raise ValueError, "A PLUTO container must be a commission or project"
        end #case plutoClass
        
        #puts "Here is the contents of extraMeta at point 1: - #{extraMeta}"
        
        metadata.merge!(extraMeta) #should probably validate the fields somehow but this will probably work for now
        
        argtype = metadata['gnm_type'].downcase
        

        metadata["gnm_#{argtype}_subscribing_groups"] = subscribingGroupIDs
        metadata["gnm_#{argtype}_status"] = "New"
        

        begin
            super(title,metadata,groupname: nil)    #call VSCollection's create! method and return the ID
            self.refresh
        rescue VSException=>e
            puts e.to_s
            exit(1)
        end
        
        @title = title
        @status = @metadata["gnm_#{argtype}_status"]
        
    end #def do_create!
    
    def itemSearchWithin(criteria,start: nil, number:nil, &block)
        s = VSSearch.new(@host,@port,@user,@passwd)
        s.debug = @debug
        criteria.each do |k,v|
            s.addCriterion({ k => v },invert: false)
        end
        
        s.results(start: start,number: number,withinCollection: @id) do |r|
            block.call(r)
        end #s.results
    end #def searchWithin
    
    def containerSearchWithin(criteria,start: nil, number:nil, &block)
        s = VSSearch.new(@host,@port,@user,@passwd)
        s.debug = @debug
        s.searchType('collection')
        s.addCriterion({'__parent_collection'=>@id},invert: false)
        criteria.each do |k,v|
            s.addCriterion({ k => v },invert: false)
        end
        
        s.results(start: start,number: number) do |r|
            r.refresh!
            if r.metadata['gnm_type']=='Project'
                rtn = PLUTOProject.new(@host,@port,@user,@passwd,from_collection: r)
                block.call(rtn)
            elsif r.metadata['gnm_type']=='Commission'
                rtn = PLUTOCommission.fromCollection(r)
                block.call(rtn)
            else
                block.call(r)
            end
        end #s.results
    end
    def containerFor(itemId)
        #code
    end
end #class PLUTOContainerEntity

class PLUTOBasicEntity < VSItem

end #class PLUTOBasicEntity

class PLUTOMaster < PLUTOBasicEntity
    def add_holding_image(fieldname,image_item, filename: nil)
#        {
#   "url_16x9":"/APInoauth/thumbnail/KP-5/KP-1788214;version=0/0?hash=9e53947f0317bf35e8043c172ba17f4a",
#   "id_16x9":"KP-1788214",
#   "filename_16x9":"image.png",
#   "url_4x3":"/APInoauth/thumbnail/KP-5/KP-1788215;version=0/0?hash=e37a58143c2e93a417408a5ea8794130",
#   "id_4x3":"KP-1788215",
#   "filename_4x3":"image.png"
#}
        if(not image_item.is_a?(VSItem))
            raise TypeError, "you must pass a VSItem to add_holding_image"
        end
        
        ap image_item.getMetadata
        
        if filename==nil
            filename = image_item.getMetadata['originalFilename']
        end
        
        d = {
            'id_16x9'=>image_item.id,
            'filename_16x9'=>filename,
            'url_16x9'=>image_item.getMetadata['representativeThumbnailNoAuth'],
            'id_4x3'=>image_item.id,
            'filename_4x3'=>filename,
            'url_4x3'=>image_item.getMetadata['representativeThumbnailNoAuth'],
        }
        self.setMetadata({fieldname=>JSON.generate(d)}, groupname: nil)
    end

    def project()
        parent_id = self.getMetadata['__collection']
        
        if(parent_id==nil or parent_id=="")
          ap self.getMetadata if(@debug)
          raise ArgumentError, "No parent collection defined" 
        end
        
        project_ref = PLUTOProject.new(@host,@port,@user,@passwd)
        project_ref.debug = @debug
        project_ref.populate(parent_id)
        return project_ref
    end
end #class PLUTOMaster

class PLUTOCommission < PLUTOContainerEntity
    def initialize(host,port,username,passwd,parent: nil,from_collection: nil)
        super(host,port,username,passwd,parent: parent)
        if from_collection!=nil
            @metadata=from_collection.metadata
        end
    end
        
    def create!(title,commissionerUID: nil,
                workingGroupUID: nil,client: nil,
                projectTypeUID: nil,subscribingGroupIDs: nil,
                ownerID: nil, extraMeta: nil,noraise: false)
        super(PLUTO_COMMISSION,title,
                      commissionerUID: commissionerUID,
                      workingGroupUID: workingGroupUID,
                      client: client,
                      projectTypeUID: projectTypeUID,
                      subscribingGroupIDs: subscribingGroupIDs,
                      ownerID: ownerID,
                      extraMeta: extraMeta,
                      noraise: noraise)
        
        #puts "Data at point PLUTOCommission create!"
        #puts "title: #{title}"
        #puts "commissionerUID: #{commissionerUID}"
        #puts "workingGroupUID: #{workingGroupUID}"
        #puts "client: #{client}"
        #puts "projectTypeUID: #{projectTypeUID}"
        #puts "subscribingGroupIDs: #{subscribingGroupIDs}"
        #puts "ownerID: #{ownerID}"
        #puts "extraMeta: #{extraMeta}"
        #puts "noraise: #{noraise}"  
    end #def create!
    
    def newProject(title,commissionerUID: nil,
                   workingGroupUID: nil,client: nil,
                   projectTypeUID: nil,subscribingGroupIDs: nil,
                   ownerID: nil, extraMeta: nil,noraise: false)
        project = PLUTOProject.new(@host,@port,@user,@passwd)
    
        #puts "Data at point PLUTOCommission newProject"
        #puts "title: #{title}"
        #puts "commissionerUID: #{commissionerUID}"
        #puts "workingGroupUID: #{workingGroupUID}"
        #puts "client: #{client}"
        #puts "projectTypeUID: #{projectTypeUID}"
        #puts "subscribingGroupIDs: #{subscribingGroupIDs}"
        #puts "ownerID: #{ownerID}"
        #puts "extraMeta: #{extraMeta}"
        #puts "noraise: #{noraise}"    
    
        #puts "Here is the contents of extraMeta at point 4: - #{extraMeta}"
        
        commissionerUID=@metadata['gnm_commission_commissioner'] if(commissionerUID==nil)
        workingGroupUID=@metadata['gnm_commission_workinggroup'] if(workingGroupUID==nil)
        projectTypeUID=@metadata['gnm_commission_projecttype'] if(projectTypeUID==nil)
        client=@metadata['gnm_commission_client'] if(client==nil)
        subscribingGroupIDs=@metadata['gnm_commission_subscribing_groups'] if(subscribingGroupIDs==nil)
        ownerID=@metadata['gnm_commission_owner'] if(ownerID==nil)
        
        project.create!(self,title,
                        commissionerUID: commissionerUID,
                        workingGroupUID: workingGroupUID,
                        client: client,
                        projectTypeUID: projectTypeUID,
                        subscribingGroupIDs: subscribingGroupIDs,
                        ownerID: ownerID,
                        extraMeta: extraMeta,
                        noraise: noraise)
        
        #puts "Data at point PLUTOCommission newProject project.create!"
        #puts "title: #{title}"
        #puts "commissionerUID: #{commissionerUID}"
        #puts "workingGroupUID: #{workingGroupUID}"
        #puts "client: #{client}"
        #puts "projectTypeUID: #{projectTypeUID}"
        #puts "subscribingGroupIDs: #{subscribingGroupIDs}"
        #puts "ownerID: #{ownerID}"
        #puts "extraMeta: #{extraMeta}"
        #puts "noraise: #{noraise}"
        
        project.setParentMeta(@metadata)
        return project
    end #def newProject
    
    def populateByTitle(title)
        super(PLUTO_COMMISSION,title)
    end
        
    def findProject(name: nil)
        raise ArgumentError unless(name.is_a?(String))
        #search=VSSearch.new(@host,@port,@user,@passwd)
        #search.debug=@debug
        
        #search.addCriterion({ 'gnm_type' => PLUTO_PROJECT },invert: false)
        ##search.addCriterion({ 'title' => name },invert: false)
        #search.addCriterion({ '__parent_collection' => @id },invert: false)
        #search.searchType("collection")
        
        #n = 0
        #search.results(start: "1", number: "1") do |result|
        #    project=PLUTOProject.new(@host,@port,@user,@passwd)
        #    project.populate(result.id)
        #    project.parent = self
        #    
        #    if(block_given?)
        #        yield project
        #    else
        #        return project
        #    end
        #    n+=1
        #end #search.results
        
        n = 0
        self.containerSearchWithin({'gnm_type' => PLUTO_PROJECT, 'title' => "\"#{name}\""},start: nil) do |result|
            ap result
            n+=1
            if block_given?
                yield result
            else
                return result 
            end
        end
        if(n==0)
            raise PLUTONotFound
        end
    end #def findProject
    
    def projects(&block)
        #self.searchWithin({ 'gnm_type' => PLUTO_PROJECT }) do |result|
        #    block.call(result)
        #end #self.searchWithin
        
        self.each do |item|
            if(item.is_a?(VSCollection))
                puts "debug: got collection at id #{item.id}"
                item.refresh
                md = item.metadata
                ap md
                if(md['gnm_type']==PLUTO_PROJECT)
                    block.call(item)
                end
            else
                puts "debug: returned item #{item.id} NOT a collection"
                ap item
            end #if(item.is_a?(VSCollection))
        end #self.each
    end #def projects
    
end #class PLUTOCommission

class PLUTOProject < PLUTOContainerEntity
    attr_accessor :parent
    
    def create!(parentCommission,title,commissionerUID: nil,
                workingGroupUID: nil,client: nil,
                projectTypeUID: nil,subscribingGroupIDs: nil,
                ownerID: nil, extraMeta: nil,noraise: false)
        super(PLUTO_PROJECT,title,
                commissionerUID: commissionerUID,
                workingGroupUID: workingGroupUID,
                client: client,
                projectTypeUID: projectTypeUID,
                subscribingGroupIDs: subscribingGroupIDs,
                ownerID: ownerID,
                extraMeta: extraMeta,
                noraise: noraise)
        parentCommission.addChild(self)
        
        #puts "Data at point PLUTOProject create!"
        #puts "parentCommission: #{parentCommission}"
        #puts "title: #{title}"
        #puts "commissionerUID: #{commissionerUID}"
        #puts "workingGroupUID: #{workingGroupUID}"
        #puts "client: #{client}"
        #puts "projectTypeUID: #{projectTypeUID}"
        #puts "subscribingGroupIDs: #{subscribingGroupIDs}"
        #puts "ownerID: #{ownerID}"
        #puts "extraMeta: #{extraMeta}"
        #puts "noraise: #{noraise}"
        
        #puts "Here is the contents of extraMeta at point 2: - #{extraMeta}"
    end #def create!
    
    def initialize(host,port,username,passwd,parent: nil,from_collection: nil)
        super(host,port,username,passwd,parent: parent)
        if from_collection!=nil
            @metadata=from_collection.metadata
            @id=from_collection.id
            @debug=from_collection.debug
        end
    end
    
    #called by parent commission when setting up
    def setParentMeta(mdhash)

        mdToSet = Hash.new
    ['gnm_commission_title',"gnm_commission_commissioner","gnm_commission_workinggroup","gnm_commission_client"].each do |fieldname|
            mdToSet[fieldname]=mdhash[fieldname]
        end
        self.setMetadata(mdToSet,vsClass: "collection")
    end #setParentMeta
    
    def masters(&block)
        
    end #def masters
end #class PLUTOProject
