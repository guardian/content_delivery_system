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
  it 'should generate a basic output hash' do
    mockpreset = instance_double(Aws::ElasticTranscoder::Types::Preset)
    mockpreset.stub(:video)
        .and_return(SimpleTest.new(4096,"vp8"))
    mockpreset.stub(:container).and_return("webm")
    mockpreset.stub(:id).and_return("id-1234567")

    out = CDSElasticOutput.new(mockpreset,"/path/to/testfilename.mxf","/path/to/a/watermark.tif")

    (out.to_hash).should eq({:preset_id=>"id-1234567",
                             :key=>"/path/to/testfilename_4M_vp8.webm",
                             :thumbnail_pattern=>"",
                             :input_key=>"/path/to/a/watermark.tif"}
                         )
  end


end