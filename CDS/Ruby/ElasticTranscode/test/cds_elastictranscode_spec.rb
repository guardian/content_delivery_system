require 'rspec'
require './lib/CDSElasticTranscode.rb'
require 'awesome_print'

describe 'Elastic transcode class' do
  it 'should look up pipelines' do
    ets = CDSElasticTranscode.new(region:'eu-west-1')
    result = ets.lookup_pipeline('UploadToCDNPipeline')

    puts result
    expect(result).to eq '1387374465645-ghr310'
  end

  it 'should raise a not found error on invalid pipeline name' do
    ets = CDSElasticTranscode.new(region:'eu-west-1')
    expect {
      ets.lookup_pipeline('dsalkdas')
    }.to raise_error(ObjectNotFound)
  end

  it 'should look up presets' do
    ets = CDSElasticTranscode.new(region: 'eu-west-1')
    result = ets.lookup_preset('GNM - 4mbit 1280x720 MP4 [mobile]')

    expect(result.is_a?(Aws::ElasticTranscoder::Types::Preset)).to eq true
    expect(result.id).to eq '1387374573575-dzvtfo'

    result_list = ets.lookup_multiple_presets(['GNM - 4mbit 1280x720 MP4 [mobile]','GNM - 1mbit 1024x576 MP4 [mobile]'])
    puts result_list
  end

  it 'should convert a list of presets into a list of outputs' do
    ets = CDSElasticTranscode.new(region: 'eu-west-1')

    output_list = ets.presets_to_outputs(['GNM - 4mbit 1280x720 MP4 [mobile]','GNM - 1mbit 1024x576 MP4 [mobile]'],
                                         "/output/path/location/file")
    ap output_list
    hash_list = output_list.map{|o| o.to_hash}
    expect(hash_list).to eq [{
                                   :preset_id => "1387374573575-dzvtfo",
                                   :key => "/output/path/location/file_3M_H264.mp4",
                                   :thumbnail_pattern => "",
                                   :input_key => nil
                               }, {
                                   :preset_id => "1387374661930-nnw3wn",
                                   :key => "/output/path/location/file_768k_H264.mp4",
                                   :thumbnail_pattern => "",
                                   :input_key => nil
                               }
                              ]
  end


  it 'should convert a list of presets into a list of outputs, specifying a watermark' do
    ets = CDSElasticTranscode.new(region: 'eu-west-1')

    output_list = ets.presets_to_outputs(['GNM - 4mbit 1280x720 MP4 [mobile]','GNM - 1mbit 1024x576 MP4 [mobile]'],
                                         "/output/path/location/file",
                                         watermark: '/path/to/watermark.tif')
    ap output_list
    hash_list = output_list.map{|o| o.to_hash}

    expect(hash_list).to eq [{
      :preset_id => "1387374573575-dzvtfo",
          :key => "/output/path/location/file_3M_H264.mp4",
          :thumbnail_pattern => "",
          :input_key => "/path/to/watermark.tif"
    }, {
      :preset_id => "1387374661930-nnw3wn",
          :key => "/output/path/location/file_768k_H264.mp4",
          :thumbnail_pattern => "",
          :input_key => "/path/to/watermark.tif"
    }]
  end
end