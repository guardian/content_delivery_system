require 'aws-sdk-resources'
require 'logger'
require 'filename_utils'

# This class represents a single output for Elastic Transcoder and handles filename generation and updates
class CDSElasticOutput
  # Initialise a new CDSElasticOutput object
  # Parameters:
  # @param preset [Aws::ElasticTranscoder::Types::Preset] preset that this will be linked to
  # @param input_filename [String] filename that is being used as the input. this will be used to generate the base output filename
  # @param watermark [String] S3 path of a still to use as a watermark. nil if you don't want to use a watermark.
  def initialize(preset, input_filename, watermark, segment_duration: nil)
    @preset = preset
    @filenameutil = FilenameUtils.new(input_filename)
    @filenameutil.add_transcode_parts!(preset.video.bit_rate.to_i, preset.video.codec.gsub(/[^\w\d]/, ''))
    @watermark = watermark
    @segment_duration = segment_duration
  end

  def initialize_dup(source)

  end

  # Returns a hash suitable for elastic transcoder output
  # @return [Hash]
  def to_hash
    #if we're not making an HLS wrapper then put in the container as a file extension. If not, append a _ to separate out the sequence numbers
    if @preset.container != 'ts'
      @filenameutil.extension = @preset.container
      output_path_string = @filenameutil.filepath(with_extension: true)
    else
      output_path_string = @filenameutil.filepath(with_extension: false) + '_'
    end
    temp = {
        :preset_id=>@preset.id,
        :key=>output_path_string,
        :thumbnail_pattern=>"",
        :input_key=>@watermark,
    }
    if @segment_duration
      temp[:segment_duration] = @segment_duration
    end
    temp
  end

  # Increments the version number part of the filename
  # @return [Integer] new value of the version number
  def increment!
    @filenameutil.increment!
  end

  def increment

  end
end