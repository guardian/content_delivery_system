require 'rspec'
require 'CDSResponder'
require 'fileutils'

describe 'CDSResponder class' do
  it 'should validate an ARN' do
    expect {
      r = CDSResponder.new("invalid-arn","fakeroute","inmeta", nil)
    }.to raise_error(ArgumentError)

    expect {
      r = CDSResponder.new("arn:aws:sqs:eu-west-1:too:many:s:in:arn","fakeroute","inmeta", nil)
    }.to raise_error(ArgumentError)

  end

  it 'should find a unique filename' do
    begin
    r = CDSResponder.new("arn:aws:sqs:eu-west-1:1234567:fake-queue-name", "fakeroute", "inmeta", nil)

    filename01 = r.GetUniqueFilename("/tmp")
    expect(filename01).to eq "/tmp/fakeroute.xml"

    FileUtils.touch(filename01)
    filename02 = r.GetUniqueFilename("/tmp")
    expect(filename02).to eq "/tmp/fakeroute-1.xml"

    FileUtils.touch(filename02)
    filename03 = r.GetUniqueFilename("/tmp")
    expect(filename03).to eq "/tmp/fakeroute-2.xml"

    FileUtils.touch(filename03)

    File.unlink(filename01)
    File.unlink(filename02)
    File.unlink(filename03)

    ensure
      r.kill
    end

  end


end