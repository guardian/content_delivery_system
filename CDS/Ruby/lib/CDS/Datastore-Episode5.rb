#require './Datastore.rb'
require 'CDS/Datastore'

require 'nokogiri'

class Datastore::Episode5 < Datastore

def import_episode(metafile,truncate=false)

raise MethodNotImplementedError,"Datastore::Episode5::import_episode has not been implemented yet"
end

require 'awesome_print'

def export_episode(template,output)

raise MethodNotImplementedError,"Datastore::Episode5::import_episode has not been implemented yet"
end

#FIXME - should implement some named args, e.g. :pedantic - raise an exception if the data isn't what we expect

def export_meta()

templatedata=self.get_template_data(1)
builder = Nokogiri::XML::Builder.new do |xml|
xml.doc.create_internal_subset('meta-data',nil,"meta.dtd")
xml.send(:'meta-data',:version=>"1.0") {
        xml.meta(:name=>"meta-source",:value=>"inmeta") {
                templatedata['meta'].each do |key,value|
                        xml.meta(:name=>key,:value=>value)
                end #templatedata.each
        }
        xml.meta(:name=>"movie",:value=>templatedata['escaped_path']) {
                templatedata['movie'].each do |key,value|
                        xml.meta(:name=>key,:value=>value)
                end
        }
        if templatedata['tracks']
                ap(templatedata['tracks'])
                templatedata['tracks'].each do |trackname,trackdata|
                        ap(trackdata)
                        begin
                                xml.meta(:name=>"track",:value=>trackdata['index']){
                                        trackdata.each do |key,value|
                                                xml.meta(:name=>key,:value=>value)
                                        end #trackdata.each
                                }
                        rescue Exception=>e
                                puts e.backtrace
                                puts "-WARNING: #{e.message}"
                        end #exception handling
                end #templatedata.each
        end #if templatedata['tracks']
}
end #Nokogiri::XML::Builder.new

builder.to_xml

end #export_meta

def export_inmeta()
templatedata=self.get_template_data(1)
builder = Nokogiri::XML::Builder.new do |xml|
xml.doc.create_internal_subset('meta-data',nil,"inmeta.dtd")
xml.send(:'meta-data') {
	xml.send(:'meta-group',:type=>"movie meta") {
		templatedata['meta'].each do |key,value|
			xml.meta(:name=>key,:value=>value)
		end #templatedata.each
	}
	xml.send(:'meta-movie-info') {
		xml.send(:'meta-movie',:tokens=>"format duration bitrate size tracks")
		xml.send(:'meta-track',:tokens=>"type format start duration bitrate size")
		xml.send(:'meta-video-track',:tokens=>"width height framerate")
		xml.send(:'meta-audio-track',:tokens=>"channels bitspersample samplerate")
		xml.send(:'meta-hint-track',:tokens=>"payload fmtp")
	}
}
end #Nokogiri::XML::Builder.new

builder.to_xml
end #export_inmeta

end #class

