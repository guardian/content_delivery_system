#!/usr/bin/env ruby

#This module uploads image(s) to the Guardian's R2 CMS.
#Images MUST be in .jpg, .gif, .png and .bmp format or the CMS will not accept them
#CMS IDs and URLs are output into the Datastore.
#
#Arguments:
# <take-files>media - can upload the media file if it is an image. Don't use <take-files> if you don't want to treat the media file as an image
# <server>hostname [OPTIONAL] - connect to this server. Defaults to cms.guprod.gnl.
# <rootpath>/url/path/to/cmstools [OPTIONAL] - use this as the base path for the Newspaper Integration endpoints. Defaults to "/tools/newspaperintegration".
# <extra-files>file1|file2|/path/to/file3|{meta:filepaths} [OPTIONAL] - upload these files too, in a | separated list
# <site>guardian.co.uk [OPTIONAL] - tell R2 that the images are associated to this site. Can be a | separated list to correspond to individual files being uploaded
# <groupID>nnnn [OPTIONAL] - tell R2 that the images should be uploaded to this group. This must be a numeric ID. Can be a | separated list to correspond to individual files being uploaded
# <altText>text|{meta:altText} [OPTIONAL] - tell R2 to set the altText for the image to this value. Substitutions encouraged; defaults to the file name if not specified. Can be a | separated list to correspond to individual files being uploaded
# <caption>text|{meta:altText} [OPTIONAL] - tell R2 to set the caption for the image to this value. Substitutions encouraged; defaults to the alt text if not specified. Can be a | separated list to correspond to individual files being uploaded
# <source>sourceValue [OPTIONAL] - tell R2 what the image source is. Defaults to 'guardian.co.uk'.Can be a | separated list to correspond to individual files being uploaded
# <photographer>name [OPTIONAL] - tell R2 the photographer's name. Can be a | separated list to correspond to individual files being uploaded
# <comments>text [OPTIONAL] - set comments on the image. Can be a | separated list to correspond to individual files being uploaded
# <picdarID>nnnn [OPTIONAL] - tell R2 the Picdar ID of the image. Can be a | separated list to correspond to individual files being uploaded
# <copyright>text [OPTIONAL] - tell R2 about the copyright of the image. Can be a | separated list to correspond to individual files being uploaded
# <supplierRef>text [OPTIONAL] - give R2 a supplier reference for the image.  Can be a | separated list to correspond to individual files being uploaded
# <output_id_key>keyname [OPTIONAL] - output CMS IDs of the uploaded images to this datastore key. Defaults to 'r2_image_ids'
# <output_url_key>keyname [OPTIONAL] - output uploaded URLs of the images to this datastore key. Defaults to 'r2_image_urls'
#END DOC

require 'CDS/Datastore'
require 'R2NewspaperIntegration/R2'
require 'awesome_print'


def extractListParam(store,paramName,defaultValue)
    rtn=Array.new
    if(ENV[paramName])
        ENV[paramName].split('|').each do |value|
           rtn << store.substitute_string(value).encode('US-ASCII',{:invalid=>:replace,:undef=>:replace,:replace=>''}) #force Ruby to treat values from datastore as ASCII in order to try to satisfy whatever is bombing out join((
        end
    else
	if(defaultValue.is_a?(String))
           rtn << defaultValue.encode('US-ASCII',{:invalid=>:replace,:undef=>:replace,:replace=>''})
        else
           rtn << defaultValue
        end
    end
    return rtn
end #def extractListParam

#returns either the nth element of array, or the last one if index is out of bounds.
def obtainValue(array,index)
    begin
	if(ENV['debug'])
		puts "obtainValue: got value #{array[index]}"
	end
	if(array[index]=="" or array[index]==nil)
		return array[-1]
	end
        return array[index]
    rescue IndexError=>e
	if(ENV['debug'])
		puts "obtainValue: got value #{array[-1]}"
	end
        return array[-1]
    end
end

#START MAIN
store=Datastore.new('r2_image_upload')

if(ENV['rootpath']=="true" or ENV['rootpath'].downcase=="true")
	rootpath=""
else
	rootpath=store.substitute_string(ENV['rootpath'])
end

ni=R2NewspaperIntegration.new(host: store.substitute_string(ENV['server']),
                              rootpath: rootpath)

if(ENV['debug'])
	ni.debug=true
end

filesToUpload=Array.new
if(ENV['cf_media_file'] and ENV['cf_media_file']!="")
    filesToUpload << ENV['cf_media_file']
end

if(ENV['extra-files'])
    specifier=store.substitute_string(ENV['extra-files'])
    if(ENV['debug'])
	puts "Got extra files specifier #{specifier}."
    end

    specifier.split('|').each do |filename|
       if(ENV['debug'])
	puts "Adding #{filename}..."
       end
       filesToUpload << store.substitute_string(filename)
    end
end

retry_max=10
if(ENV['retries'])
    retry_max=store.substitute_string(ENV['retry_delay']).to_i()
end

retry_delay=2
if(ENV['retry_delay'])
    retry_delay=store.substitute_string(ENV['retry_delay']).to_i()
end

puts "INFO: Files to upload:"
ap filesToUpload

siteList=extractListParam(store,'site','guardian.co.uk')
groupIDList=extractListParam(store,'groupID',3232)
altTextList=extractListParam(store,'altText',nil)
captionList=extractListParam(store,'caption',nil)
sourceList=extractListParam(store,'source','guardian.co.uk')
photographerList=extractListParam(store,'photographer',nil)
commentsList=extractListParam(store,'comments',nil)
picdarIdList=extractListParam(store,'picdarID',nil)
copyrightList=extractListParam(store,'copyright',nil)
supplierRefList=extractListParam(store,'supplierRef',nil)

n=0
success=0
fail=0

id_output=""
url_output=""

filesToUpload.each do |filename|
    site=obtainValue(siteList,n)
    groupID=obtainValue(groupIDList,n)
    altText=obtainValue(altTextList,n)
    caption=obtainValue(captionList,n)
    source=obtainValue(sourceList,n)
    photographer=obtainValue(photographerList,n)
    comments=obtainValue(commentsList,n)
    picdarID=obtainValue(picdarIdList,n)
    copyright=obtainValue(copyrightList,n)
    supplierRef=obtainValue(supplierRefList,n)
    
    retries=0
    begin
        retries+=1
        id, url = ni.uploadImage(filename, site: site, groupID:groupID, altText: altText,
                   caption: caption, source: source, photographer: photographer,
                   comments: comments, picdarId: picdarID, copyright: copyright, ref: supplierRef)
        
        id_output+="#{id}|"
        url_output+="#{url}|"
        
    rescue HTTPError=>e
        puts "WARNING: #{retries}/#{retry_max}: An HTTP or transport error occurred during uploading: #{e.message}."
        if(retries>=retry_max)
            puts "-ERROR: #{e.message}. Giving up after #{retries} attempts."
            fail+=1
            next
        end
        sleep retry_delay
        retry
        
    rescue R2Error=>e
        puts "-ERROR: #{retries}/#{retry_max}: R2 said #{e.message}."
        fail+=1
        next
        
    rescue Exception=>e
        puts "-ERROR: #{retries}/#{retry_max}: #{e.message}."
        puts e.backtrace
        fail+=1
        next
        
    end
    success+=1
    n+=1
end #filesToUpload.each

puts "INFO: Out of #{n} uploads, #{success} succeeded and #{fail} failed"

if(success==0)
    puts "-ERROR: No image uploads succeeded."
    exit 1
end

id_key='r2_image_ids'
if(ENV['output_id_key'] and ENV['output_id_key']!="")
    id_key=ENV['output_id_key']
end

url_key='r2_image_urls'
if(ENV['output_url_key'] and ENV['output_url_key']!="")
    url_key=ENV['output_url_key']
end

store.set('meta',id_key,id_output.chop(),url_key,url_output.chop())

if(fail>0)
    puts "-WARNING: #{fail} images failed to upload."
    if(ENV['all_must_work'])
        exit 1
    end
end

puts "+SUCCESS: Uploaded #{n} images and output information to meta:#{id_key} and meta:r2_image_urls"





