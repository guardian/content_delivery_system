require 'rspec'
require 'aws-sdk-resources'
require './lib/cds_elastic_output.rb'

class SimpleTest
  attr_accessor :bit_rate
  attr_accessor :codec

  def initialize(bit_rate,codec)
    @bit_rate = bit_rate
    @codec = codec
  end
end

describe 'CDSElasticOutput' do
  it 'should generate a basic output hash and increment the filename' do
    mockpreset = instance_double(Aws::ElasticTranscoder::Types::Preset)
    mockpreset.stub(:video).and_return(SimpleTest.new(4096,"vp8"))
    mockpreset.stub(:container).and_return("webm")
    mockpreset.stub(:id).and_return("id-1234567")

    out = CDSElasticOutput.new(mockpreset,"/path/to/testfilename.mxf","/path/to/a/watermark.tif")

    (out.to_hash).should eq({:preset_id=>"id-1234567",
                             :key=>"/path/to/testfilename_4M_vp8.webm",
                             :thumbnail_pattern=>"",
                             :input_key=>"/path/to/a/watermark.tif"}
                         )
    out.increment!
    (out.to_hash).should eq({:preset_id=>"id-1234567",
                             :key=>"/path/to/testfilename_4M_vp8-1.webm",
                             :thumbnail_pattern=>"",
                             :input_key=>"/path/to/a/watermark.tif"}
                         )
    out.increment!
    (out.to_hash).should eq({:preset_id=>"id-1234567",
                             :key=>"/path/to/testfilename_4M_vp8-2.webm",
                             :thumbnail_pattern=>"",
                             :input_key=>"/path/to/a/watermark.tif"}
                         )
  end

  it 'should generate an HLS hash and increment the filename' do
    mockpreset = instance_double(Aws::ElasticTranscoder::Types::Preset)
    mockpreset.stub(:video).and_return(SimpleTest.new(4096,"h264"))
    mockpreset.stub(:container).and_return("ts")
    mockpreset.stub(:id).and_return("id-1234567")

    out = CDSElasticOutput.new(mockpreset,"/path/to/testfilename.mxf","/path/to/a/watermark.tif",segment_duration: 10)

    (out.to_hash).should eq({:preset_id=>"id-1234567",
                             :key=>"/path/to/testfilename_4M_h264_",
                             :thumbnail_pattern=>"",
                             :input_key=>"/path/to/a/watermark.tif",
                             :segment_duration=>10}
                         )
    out.increment!
    (out.to_hash).should eq({:preset_id=>"id-1234567",
                             :key=>"/path/to/testfilename_4M_h264-1_",
                             :thumbnail_pattern=>"",
                             :input_key=>"/path/to/a/watermark.tif",
                             :segment_duration=>10}
                         )
    out.increment!
    (out.to_hash).should eq({:preset_id=>"id-1234567",
                             :key=>"/path/to/testfilename_4M_h264-2_",
                             :thumbnail_pattern=>"",
                             :input_key=>"/path/to/a/watermark.tif",
                             :segment_duration=>10}
                         )
  end
end