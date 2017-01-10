require 'rspec'
require 'FinishedNotification'
require 'json'

describe 'FinishedNotification' do

  it 'should render instance variables as json' do
    f = FinishedNotification.new("routename",1,"route log here")
    jsonstring = f.to_json
    jsondata = JSON.parse(jsonstring)

    expect(jsondata['@routename']).to eq "routename"
    expect(jsondata['@exitcode']).to eq 1
    expect(jsondata['@log']).to eq "route log here"

  end

end