#This module contains routines that make it easier to work with HLS (.m3u8, Apple HTTP Live Streaming) media

require 'uri'
require 'fileutils'

class HLSIterator
attr_accessor :indexfile
attr_accessor :basepath

def initialize(filename,basepath)
    @indexfile = filename
    
    if(basepath)
        @basepath = basepath
    else
        @basepath = ""
    end
    
    unless(File.exists?(@indexfile))
        raise IOError, "Master index file '#{@indexfile}' does not exist."
    end
end

def readIndexFile(fn,b)
    fp = File.open(URI.unescape(fn),"r")
    while(line=fp.gets)
        if(line=~/^#/)
           next
        end
        uri=URI(line)
        filename=File.join(@basepath,File.basename(uri.path))
        b.call(filename,line)
           
        if(line=~/\.m3u8$/)
           self.readIndexFile(filename,b)
        end
    end #while
end #readIndexFile

#This should be called from a loop, as HTSIterator.each do |filename,uri|
def each(&b)
    readIndexFile(@indexfile,b)
end #def each

def rebaseIndexFile(fn,oldbase,newbase)
    unescaped_file = URI.unescape(fn)
    fp = File.open(URI.unescape(unescaped_file),"r")
    out=""
    while(line=fp.gets)
       if(line=~/^#/)
          out+=line
          next
        end
          
        uri=URI(line)
        if(line=~/\.m3u8$/)
            filename=File.join(@basepath,File.basename(uri.path))
            self.rebaseIndexFile(filename,oldbase,newbase)
        end
        
        line.gsub!(oldbase,newbase)
          #validate the new URI. This should throw a URI::* exception if the uri is not valid.
          uri=URI(line)
        out+=line
    end
    fp.close()
    FileUtils.cp(unescaped_file,"#{unescaped_file}.orig")
    fp=File.open(unescaped_file,"wb")
    fp.write(out)
    fp.close()
end #def rebaseIndexFile
          
def rebase(oldbase,newbase)
    unless(newbase=~/\/$/)
          if(oldbase=~/\/$/)
            newbase += "/"
          end
    end
    rebaseIndexFile(@indexfile,oldbase,newbase)
end #def rebase
           
end #class HLSIterator