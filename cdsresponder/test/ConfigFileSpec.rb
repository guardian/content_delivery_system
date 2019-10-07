require 'rspec'
require 'ConfigFile'
require 'tempfile'

describe 'ConfigFile' do

  it 'should load a key-value file' do
    begin
      tempfile = Tempfile.new("ConfigFileTest")
      tempfile.write('configuration-table=configtable
routes-table=routestable
region=regionname
access-key=aws-access-key
secret-key=aws-secret-key
raven-dsn=https://kddasdasdasdakhdajhadhj@sentry.instance/11')
      tempfile.close
      cfg = ConfigFile.new(tempfile.path)

      expect(cfg.var["configuration-table"]).to eq "configtable"
      expect(cfg.var["routes-table"]).to eq "routestable"
      expect(cfg.region).to eq "regionname"
      expect(cfg.var["access-key"]).to eq "aws-access-key"
      expect(cfg.var["secret-key"]).to eq "aws-secret-key"
      expect(cfg.var["raven-dsn"]).to eq "https://kddasdasdasdakhdajhadhj@sentry.instance/11"

      expect{
        cfg.invalidkeyname
      }.to raise_error(KeyError)
    ensure
      tempfile.unlink
    end
  end

  it 'should raise if the file name does not exist' do
    expect {
      cfg = ConfigFile.new("/path/to/invalidfile")
    }.to raise_error(StandardError)
  end
end