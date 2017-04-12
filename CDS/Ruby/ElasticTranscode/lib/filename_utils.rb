
class FilenameUtils
  attr_accessor :filename
  attr_accessor :prefix
  attr_accessor :filebase
  attr_accessor :extension
  attr_accessor :serial

  # Initialise from a path name
  def initialize(fullpath)
    @prefix = File.dirname(fullpath)
    @filename = File.basename(fullpath)

    @fileappend = ""
    parts = @filename.match(/^(?<Name>.*)\.(?<Xtn>[^\.]+)$/x)
    if parts
      @filebase = parts['Name']
      @extension = parts['Xtn']
    else
      @filebase = @filename
      @extension = nil
    end
    @serial=0
  end

  #increments the serial portion of the filename
  def increment!
    @serial+=1
  end

  # Updates the filename objects to represent a transcode output with the given bitrate and codec
  # Parameters:
  # +bitrate+:: (integer) target output bitrate
  # +codec+:: (string) codec that we are transcoding to
  def add_transcode_parts!(bitrate, codec)
    raise ArgumentError, "bitrate must be an integer" unless(bitrate.is_a?(Integer))
    if bitrate > 1024
      brstring=(bitrate/1024).ceil.to_s + 'M'
    else
      brstring=bitrate.ceil.to_s + 'k'
    end

    @fileappend='_' + brstring + '_' + codec.gsub(/[^\w\d]/, '')
  end

  # Returns a reconsituted file path for the object
  def filepath(with_extension: true)
    if @serial>0
      serialpart = "-#{@serial}"
    else
      serialpart = ""
    end

    if @extension and with_extension
      File.join(@prefix,@filebase + @fileappend + serialpart + "." + @extension)
    else
      File.join(@prefix,@filebase + @fileappend + serialpart)
    end
  end

  # Returns an S3 url, for the given bucket name
  # Params:
  #  +bucketname+:: (String) bucket to generate the URL for
  def s3path(bucketname)
    "s3://#{bucketname}" + "/" + self.filepath
  end

end