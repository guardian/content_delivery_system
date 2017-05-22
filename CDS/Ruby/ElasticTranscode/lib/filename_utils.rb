
class FilenameUtils
  attr_accessor :filename
  attr_accessor :prefix
  attr_accessor :filebase
  attr_accessor :extension
  attr_accessor :serial

  # Initialise from a path name
  # @param fullpath [String] A file path to break down and represent
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

  def fileappend
    @fileappend
  end

  # Initialise from another FilenameUtils object
  # @param source [FilenameUtils] Source object to duplicate from
  def initialize_dup(source)
    puts "initialize_dup: #{source}"
    @prefix = source.prefix
    @filename = source.filename
    @fileappend = source.fileappend
    @filebase = source.filebase
    @extension = source.extension
    @serial = source.serial
    super
  end

  # increments the serial portion of the filename, modifying this object in-place.
  # The filename returned by #filepath will be changed to file-{number}.xxx
  # @return [Integer] new serial number value
  def increment!
    @serial+=1
  end

  # increments the serial portion of the filename, returning a new copy of the object with an updated serial
  # @return [FilenameUtils] new FilenameUtils object
  def increment
    new_one = self.dup
    new_one.serial +=1
    new_one
  end

  # Updates the filename objects to represent a transcode output with the given bitrate and codec
  # Parameters:
  # @param bitrate [Integer] target output bitrate
  # @param codec [String] codec that we are transcoding to
  # @return [String] portion that is appended to the filename
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
  # @param with_extension [Boolean] whether or not to include the file extension in the result
  # @return [String] New file path, including any serial number an codec/bitrate portions
  def filepath(with_extension: true)
    if @serial>0
      serialpart = "-#{@serial}"
    else
      serialpart = ""
    end


    if @extension and with_extension
      simple_path = @filebase + @fileappend + serialpart + "." + @extension
    else
      simple_path = @filebase + @fileappend + serialpart
    end
    if @prefix != '.'
      File.join(@prefix,simple_path)
    else
      simple_path
    end

  end

  # Returns an S3 url, for the given bucket name
  # @param bucketname [String] bucket to generate the URL for
  # @return [String] Unchecked S3 url for the bucket and path
  def s3path(bucketname)
    "s3://#{bucketname}" + "/" + self.filepath
  end

end