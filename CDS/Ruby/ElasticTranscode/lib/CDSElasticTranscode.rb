require 'aws-sdk'
require 'filename_utils'
require 'logger'

#Generic error raised by CDSElasticTranscode.  All other raised errors derive from this
class CDSElasticTranscodeError < StandardError

end

#Error indicating that a requested object could not be looked up
class ObjectNotFound < CDSElasticTranscodeError

end

#This class is a helper object, encapsulating all the necessary API calls to Elastic Transcoder.
class CDSElasticTranscode
  # Allows read access to the list of filenames that will be output to S3
  # @return [Array[String]]
  attr_accessor :output_names
  # Allows read access to the container information about all files that will be output to S3
  # @return [Array[Hash]]
  attr_accessor :containers

  # Initialize a new CDSElasticTranscode helper.  You must pass AWS credentials, or rely on the SDK loading them automatically;
  # no connection is attempted until you call a method that requires access, like lookup_pipeline.
  # @param region [String] AWS region to connect to. Defaults to eu-west-1.
  # @param aws_access_key [String] Explicit AWS credential key.  Defaults to environment specified credentials if is nil or you don't specify
  # @param aws_secret_key [String] Explicit AWS secret.  Defaults to environment specified credentials if is nil or you don't specify
  # @param logger [Logger] Use this logger for outputting messages.  If is nil or unspecified, a new logger will be created pointing to STDOUT.
  def initialize(region: "eu-west-1", aws_access_key: nil, aws_secret_key: nil, logger: nil)
    if aws_access_key and aws_access_key
      @ets = Aws::ElasticTranscoder::Client.new(:region=>region, aws_access_key=>aws_access_key, aws_secret_access_key=>aws_secret_key)
    else
      @ets = Aws::ElasticTranscoder::Client.new(:region => region)
    end
    if logger
      @logger=logger
    else
      @logger=Logger.new(STDOUT)
    end

    @output_names = []
    @containers = []
  end

  # Scans available Elastic Transcoder pipelines and returns the ID of the one with a matching name,
  # or raises ObjectNotFound if it can't be found
  # @param name [String] Pipeline name to look up
  # @return [String] Internal ID of the pipeline with the given name
  def lookup_pipeline(name)
    page_token=nil
    begin
      if page_token
        result=@ets.list_pipelines(:page_token => page_token)
      else
        result=@ets.list_pipelines
      end
      result.pipelines.each { |p|
        if p.name==name
          return p.id
        end
      }
      page_token=result['next_page_token']
    end while page_token

    raise ObjectNotFound, "Couldn't find a pipeline called #{name}"
  end

  # Scans available Elastic Transcoder presets and returns an object representing the one with a matching name,
  # or raises ObjectNotFound if it can't be found
  #
  # @param name [String] Preset name to look up
  # @return [Aws::ElasticTranscoder::Types::Preset] AWS SDK elastic transcoder preset matching the given name
  def lookup_preset(name)
    page_token=nil
    begin
      if page_token
        result=@ets.list_presets(:page_token => page_token)
      else
        result=@ets.list_presets
      end
      result.presets.each { |p|
        if p.name==name
          return p
        end
      }
      page_token=result['next_page_token']
    end while page_token

    raise ObjectNotFound, "Couldn't find a preset called #{name}"
  end

  #  Maps a list of preset names into a list of looked-up objects, raises ObjectNotFound if any of the presets cannot be found.
  # @param name_list [Array] Array of names to look up.
  # @return [Array] Array of +Aws::ElasticTranscoder::Types::Preset+ objects matching the name_list passed in
  def lookup_multiple_presets(name_list)
    page_token=nil
    return_list = []
    begin
      if page_token
        result=@ets.list_presets(:page_token=>page_token)
      else
        result=@ets.list_presets
      end
      return_list += result.presets.select {|p| name_list.include?(p.name) }
      return return_list if return_list.length == name_list.length

    end while page_token
    missing_presets = name_list.select {|incoming_name| not return_list.include?(incoming_name) }
    raise ObjectNotFound, "The following presets could not be found: #{missing_presets}"
  end

  # generates outputs arguments, for the list of presets coming in
  # @param presetNames [Array[String]] list of preset names to look up (if passing from CDS arguments, remember to substitute and chomp)
  # @param output_base [String] base of the filename to use for output, as a String.  This will have bitrate and codec appended to it
  # @param watermark [String] S3 path of a still to use as a watermark. nil if you don't want to use a watermark.
  # @param segment_duration [Integer] if generating an HLS manifest, the duration (in seconds) to use of each video segment
  # @return [Array[Hash]] list of output hashes to pass to ETS
  def presets_to_outputs(preset_names,output_base,watermark: nil,segment_duration: nil)
    n=0
    self.lookup_multiple_presets(preset_names).map do |preset|
      @logger.debug("Output #{n}: Using preset ID #{preset.id}")

      output_path = FilenameUtils.new(output_base)
      output_path.add_transcode_parts!(preset.video.bit_rate.to_i, preset.video.codec.gsub(/[^\w\d]/, ''))

      #if we're not making an HLS wrapper then put in the container as a file extension. If not, append a _ to separate out the sequence numbers
      if preset.container != 'ts'
        output_path.extension = preset.container
        output_path_string = output_path.filepath(with_extension: true)
      else
        output_path_string = output_path.filepath(with_extension: false) + '_'
      end

      @output_names << output_path_string
      @containers << preset.container

      outputinfo = {
          :preset_id=>preset.id,
          :key=>output_path_string,
          :thumbnail_pattern=>"",
          :input_key=>watermark,
      }

      if segment_duration #if a playlist is specified, assume we're doing HLS and hence need segments
        outputinfo[:segment_duration] = segment_duration.to_s
      end
      n+=1
      outputinfo
    end
  end

  # generates an arguments Hash to pass to Elastic Transcoder
  # Parameters:
  # +pipeline_id+:: internal ID of the pipeline to use.  Get this value by calling #lookup_pipeline
  # +input_path+:: FilenameUtils representation of the input key to use
  # +outputs+:: List of output hashes to generate.  Get this value by calling #presets_to_outputs.
  # +playlist+:: (defaults to False) - set to true if generating an HLS manifest
  # +playlist_name+:: (String) set this to the name of the master manifest to output, if generating an HLS manifest
  # +playlist_format+:: (defaults to HLSv3) set this if you want to generate another type of playlist
  def generate_args(pipeline_id, input_path, outputs, playlist: false, playlist_name: nil, playlist_format: "HLSv3")
    raise ArgumentError, "input_path must be a filename_utils object" unless input_path.is_a?(FilenameUtils)
    if playlist_name
      raise ArgumentError, "playlist_name must be a filename_utils object" unless playlist_name.is_a?(FilenameUtils)
    end

    args = {:pipeline_id => pipeline_id,
            :input => {:key => input_path.filepath,
                       :frame_rate => 'auto',
                       :resolution => 'auto',
                       :aspect_ratio => 'auto',
                       :interlaced => 'auto',
                       :container => 'auto'
            },
            :outputs => outputs
    }
    if playlist
      args[:playlists] = [
          {
              :name => playlist_name.filepath,
              :format => playlist_format,
              :output_keys => output_names
          }
      ]
    end
    args
  end
end