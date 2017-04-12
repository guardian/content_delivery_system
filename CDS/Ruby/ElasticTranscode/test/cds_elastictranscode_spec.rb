require 'rspec'
require './lib/CDSElasticTranscode.rb'

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

    puts result
  end
end